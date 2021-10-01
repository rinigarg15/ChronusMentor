# == Schema Information
#
# Table name: announcements
#
#  id                      :integer          not null, primary key
#  title                   :string(255)
#  body                    :text(4294967295)
#  program_id              :integer
#  created_at              :datetime
#  updated_at              :datetime
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#  user_id                 :integer          not null
#  expiration_date         :datetime
#  status                  :integer          default(0)
#  email_notification      :integer

class Announcement < ActiveRecord::Base
  sanitize_html_attributes :body
  sanitize_attributes_content :body

  UPCOMING_COUNT = 2
  EXPIRATION_WARNING = 1
  module Status
    PUBLISHED = 0
    DRAFTED = 1
  end
  VIEWABLE_CUTOFF_DATE = "2018-01-07 00:00:00 UTC"

  acts_as_role_based(:role_association => 'recipient_role', :validate_if => :published?)

  belongs_to_program
  belongs_to :admin, :class_name => 'User', :foreign_key => 'user_id'
  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :push_notifications, :as => :ref_obj, :dependent => :destroy
  has_many :viewed_objects, :as => :ref_obj, :dependent => :destroy
  has_attached_file :attachment, ANNOUNCEMENT_STORAGE_OPTIONS

  has_many  :pending_notifications,
            :as => :ref_obj,
            :dependent => :destroy

  has_many :job_logs, as: :loggable_object

  MASS_UPDATE_ATTRIBUTES = {
   :create => [:title, :body, :attachment, :expiration_date, :status, :survey_id, :email_notification],
   :send_test_emails => [:title, :body, :notification_list_for_test_email],
   :update => [:title, :body, :attachment, :expiration_date, :status, :email_notification, :notification_list_for_test_email]
  }

  # attr_protected :program, :admin
  attr_accessor :notification_list_for_test_email, :wants_test_email, :block_mail

  validates_presence_of :title, :if => :published?
  validates_presence_of :program, :admin
  validates_permission_of :admin, :manage_announcements, :on => :create, :message => Proc.new{ "activerecord.custom_errors.announcement.no_privileges".translate }
  validates_inclusion_of :status, :in => [Status::PUBLISHED, Status::DRAFTED]
  validates :email_notification, inclusion: { in: UserConstants::DigestV2Setting::ProgramUpdates.for_announcement }, :allow_nil => true
  validates_attachment_content_type :attachment, :content_type => DEFAULT_ALLOWED_FILE_UPLOAD_TYPES, :message => Proc.new { "flash_message.message.file_attachment_invalid".translate }
  validates_attachment_size :attachment, less_than: AttachmentSize::ADMIN_ATTACHMENT_SIZE, :message => Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::ADMIN_ATTACHMENT_SIZE/ONE_MEGABYTE) }
  validates_format_of :attachment_file_name, :without => DISALLOWED_FILE_EXTENSIONS, :message => Proc.new { "flash_message.general_file_attachment.file_attachment_name_invalid".translate }

  translates :title, :body
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  # Fetch announcements that are targetted towards the given user
  #
  # No condition if the user has privilege to manage any announcement.
  # Check role otherwise.
  scope :for_user, Proc.new{|user|
      unless user.can_manage_announcements?
        joins(:recipient_roles).where(["roles.id IS NULL OR roles.name IN (?)", user.role_names]).distinct
      end
    }

  scope :not_expired, -> { where("expiration_date is NULL OR expiration_date > ?", 1.day.ago) }

  scope :ordered, -> { order("announcements.updated_at DESC, announcements.id DESC") }

  scope :published, -> { where("announcements.status = ?", Status::PUBLISHED)}

  scope :drafted, -> { where("announcements.status = ?", Status::DRAFTED)}

  def expired?
    self.expiration_date.present? && self.expiration_date < 1.day.ago
  end

  def published?
    self.status == Status::PUBLISHED
  end

  def drafted?
    self.status == Status::DRAFTED
  end

  def recipient_roles_str
    self.formatted_recipient_role_names(no_capitalize: false, pluralize: true)
  end

  # Returns the list of users whom to send the announcement notification to.
  def notification_list
    role_names = [RoleConstants::ADMIN_NAME]+self.recipient_role_names
    program.send("#{role_names.join('_or_')}_users")
           .includes(:roles, :member => :member_language,  :program => :organization)
  end

  def notify_immediately?
    self.email_notification == UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
  end

  def notify_in_digest?
    self.email_notification == UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
  end

  def notify?
    return false if self.block_mail

    self.notify_immediately? || self.notify_in_digest?
  end

  def version_number
    versions.size + 1
  end

  def send_test_emails
    # Sanitize the body before sending email. Note that this is needed since
    # before_save sanitization callback would not have run at this point.
    self.sanitize_attribute(:body)

    if self.wants_test_email && self.notification_list_for_test_email.present?
      emails_to_notify = self.notification_list_for_test_email.split(',').map(&:strip)
      users = self.program.all_users.joins(:member).where(members: {email: emails_to_notify})
      emails_to_notify -= users.collect(&:email)

      mail_disabled = program.email_template_disabled_for_activity?(AnnouncementNotification)
      program.mailer_template_enable_or_disable(AnnouncementNotification, true) if mail_disabled
      users.each do |user|
        ChronusMailer.announcement_notification(user, self, {:is_test_mail => true}).deliver_now
      end

      emails_to_notify.each do |email|
        ChronusMailer.announcement_notification(nil, self, {:is_test_mail => true, :non_system_email => email}).deliver_now
      end
      program.mailer_template_enable_or_disable(AnnouncementNotification, false) if mail_disabled
    end
  end

  # Notifies the users about this announcement where +notif_type+ is the type
  # of notification under RecentActivityConstants::Type
  def self.notify_users(announcement_id, notif_type, version, send_now)
    announcement = Announcement.find_by(id: announcement_id)
    return unless announcement.present?
    role_users = announcement.notification_list
    # Notify users who opted for immediate mails first
    partition_users = User.partition_on_notification_setting(role_users)
    partition_users.each do |user_list|
      JobLog.compute_with_historical_data(user_list, announcement, notif_type, version, {:parallel_processing => true, :batch_processing => true}) do |user|
        user.send_email(announcement, notif_type, initiator: announcement.admin, send_now: send_now)
      end
    end
  end

  def mark_announcement_visibility_for_user(user_id, working_on_behalf)
    return if working_on_behalf || self.updated_at < Announcement::VIEWABLE_CUTOFF_DATE.to_datetime
    viewed_object = self.viewed_objects.find_by(user_id: user_id)
    return if viewed_object
    ViewedObject.create!(ref_obj: self, user_id: user_id)
  end
end
