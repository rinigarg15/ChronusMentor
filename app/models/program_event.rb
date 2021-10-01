# == Schema Information
#
# Table name: program_events
#
#  id                    :integer          not null, primary key
#  title                 :string(255)
#  description           :text(16777215)
#  location              :string(255)
#  start_time            :datetime
#  end_time              :datetime
#  status                :integer          default(0)
#  program_id            :integer
#  user_id               :integer
#  created_at            :datetime
#  updated_at            :datetime
#  email_notification    :boolean          default(FALSE)
#  time_zone             :string(255)
#  admin_view_id         :integer
#  admin_view_title      :string(255)
#  admin_view_fetched_at :datetime
#

class ProgramEvent < ActiveRecord::Base
  include CalendarUtils
  sanitize_html_attributes :description

  cattr_accessor :encryption_engine

  TITLE_LENGTH = 80

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:title, :description, :location, :start_time, :end_time, :date, :email_notification, :status, :time_zone, :admin_view_id],
    :update => [:title, :description, :location, :start_time, :end_time, :date, :email_notification, :status, :time_zone, :admin_view_id],
    :send_test_emails => [:title, :description, :location, :start_time, :end_time, :date, :email_notification, :time_zone, :notification_list_for_test_email]
  }
  attr_accessor :block_mail, :date, :notification_list_for_test_email, :precomputed_user_ids
  module Status
    DRAFT     = 0
    PUBLISHED = 1

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module CalendarEventPartStatValues
    NEEDS_ACTION = "NEEDS-ACTION"
    ACCEPTED = "ACCEPTED"
    DECLINED = "DECLINED"
    TENTATIVE = "TENTATIVE"
  end

  StatusByTabMap = {
    ProgramEventConstants::ResponseTabs::ATTENDING => EventInvite::Status::YES,
    ProgramEventConstants::ResponseTabs::NOT_ATTENDING => EventInvite::Status::NO,
    ProgramEventConstants::ResponseTabs::MAYBE_ATTENDING => EventInvite::Status::MAYBE
  }

  StatusMap = {
    EventInvite::Status::YES => "attending",
    EventInvite::Status::NO => "not_attending",
    EventInvite::Status::MAYBE => "may_be_attending"
  }

  ACTIVITIES_PER_PAGE = 20
  SIDE_PANE_USER_LIMIT = 2
  SLOT_TIME_IN_MINUTES = 15
  SLOTS_PER_DAY = 96

  sanitize_attributes_content :description, sanitize_scriptaccess: [:description]
  before_destroy :handle_cancelled_event_scenario

  # TODO: remove acts_as_role_based after AP-2665 is deployed
  acts_as_role_based(:skip_validation => true)

  belongs_to :user
  belongs_to :program
  belongs_to :admin_view

  has_many :event_invites, dependent: :destroy
  has_many :recent_activities, :as => :ref_obj, dependent: :destroy
  has_many :job_logs, as: :loggable_object
  has_many :program_event_users, dependent: :destroy
  has_many :users, through: :program_event_users
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, :as => :ref_obj

  before_validation :set_admin_view_title

  validates :user, :program, :title, :start_time, presence: true
  validates :admin_view_title, :admin_view, presence: true,  on: :create
  validates :time_zone, inclusion: TimezoneConstants::VALID_TIMEZONE_IDENTIFIERS, allow_nil: true, allow_blank: true
  validates :status, inclusion: { in: Status.all }

  translates :title, :description
  has_paper_trail on: [:update], class_name: 'ChronusVersion'

  scope :for_user, Proc.new{|user|
    if user.is_admin?
      where("program_id = ?", user.program_id)
    else
      where("program_event_users.user_id = ?", user.id).joins(:program_event_users).distinct
    end
  }
  scope :upcoming, -> { where("(end_time IS NULL AND start_time >= ?) OR (end_time IS NOT NULL AND end_time >= ?)", Time.now, Time.now) }
  scope :past, -> { where("(end_time IS NULL AND start_time < ?) OR (end_time IS NOT NULL AND end_time < ?)", Time.now, Time.now) }
  scope :drafted, -> { where( :status => Status::DRAFT )}
  scope :published, -> { where( :status => Status::PUBLISHED )}

  scope :get_program_events_for_reminder, Proc.new{|cron_time, interval_time, time_now| where(
    "program_events.start_time >= ? and program_events.start_time < ? and program_events.status = ?",
    (time_now + cron_time - interval_time).utc.to_s(:db), (time_now + cron_time + interval_time).utc.to_s(:db), Status::PUBLISHED).order("start_time ASC")}

  def draft?
    self.status == Status::DRAFT
  end

  def published?
    self.status == Status::PUBLISHED
  end

  def archived?
    self.end_time.present? ? self.end_time < Time.now : self.start_time < Time.now
  end

  def published_upcoming?
    self.published? && !self.archived?
  end

  def version_number
    versions.size + 1
  end

  def self.get_event_start_and_end_time(program_event)
    start_time = DateTime.localize((program_event.start_time).utc, format: :ics_full_time)
    end_time = program_event.end_time.present? ? DateTime.localize((program_event.end_time).utc, format: :ics_full_time) : program_event.end_time
    return [start_time, end_time]
  end

  def get_description_for_calendar_event
    program = self.program
    organization = program.organization
    program_event_link = Rails.application.routes.url_helpers.program_event_url(self.id, subdomain: organization.subdomain, host: organization.domain, root: program.root)
    "#{'feature.program_event.header.event_url'.translate}:\n#{program_event_link}\n\n".html_safe
  end

  def get_calendar_event_uid
    CalendarUtils.get_calendar_event_uid(self)
  end

  def can_be_synced?
    APP_CONFIG[:calendar_api_enabled] && self.program.calendar_sync_enabled? && self.published_upcoming?
  end

  def self.ics_organizer(program_event)
    encrypted_id = encryptor.encrypt(program_event.id)
    if program_event.can_be_synced?
      {name: APP_CONFIG[:scheduling_assistant_display_name], email: "#{APP_CONFIG[:reply_to_program_event_calendar_notification]}+#{encrypted_id}@#{MAILGUN_DOMAIN}"}
    else
      { name: program_event.user.try(:name) || "feature.meetings.content.removed_user".translate, email: program_event.user.try(:email) || "feature.meetings.content.removed_user".translate }
    end
  end

  def start_time_of_the_day
    if self.start_time
      if self.time_zone.present?
        DateTime.localize(self.start_time.in_time_zone(self.time_zone), format: :short_time_small)
      else
        DateTime.localize(self.start_time, format: :short_time_small)
      end
    end
  end

  def end_time_of_the_day
    if self.end_time
      if self.time_zone.present?
        DateTime.localize(self.end_time.in_time_zone(self.time_zone), format: :short_time_small)
      else
        DateTime.localize(self.end_time, format: :short_time_small)
      end
    end
  end

  def date
    if self.start_time
      if self.time_zone.present?
        DateTime.localize(self.start_time.in_time_zone(self.time_zone), format: :full_display_no_time)
      else
        DateTime.localize(self.start_time, format: :full_display_no_time)
      end
    end
  end

  def self.notification_list(users_ids = [])
    users_scope = User.where(id: users_ids)
    users_scope.includes(member: :member_language, program: :organization)
  end

  def self.notify_users(program_event, notif_type, version, opts = {})
    self.notify_users_on_priority(ProgramEvent.notification_list(opts[:users_ids]), program_event, notif_type, version, {}, program_event, program_event.user, :send_now => opts[:send_now])
  end

  #As this is being called as part of delayed job, the event object might have
  #already been deleted from the database and so we pass arguments instead of object itself
  def self.notify_users_for_deleted_event(notif_type, job_log_opts = {}, opts = {})
    program = Program.find(opts[:program_id])
    users_to_be_notified = notification_list(opts[:users_ids])
    unless users_to_be_notified.empty?
      owner = program.users.find(opts[:owner_id])
      options = {send_now: opts[:send_now], deletion: true, title: opts[:title], owner: owner.name, start_time: opts[:start_time], location: opts[:location], created_at: opts[:created_at], program_event_id: opts[:program_event_id], program_id: opts[:program_id]}
      self.notify_users_on_priority(users_to_be_notified, nil, notif_type, nil, job_log_opts, self, owner, options)
    end
  end

  def self.notify_new_users(program_event, notif_type, version, opts = {})
    users_to_be_notified = notification_list(opts[:users_ids])
    unless users_to_be_notified.empty?
      self.notify_users_on_priority(users_to_be_notified, program_event, notif_type, version, {}, program_event, program_event.user, :send_now => opts[:send_now])
    end
  end

  def send_test_emails
    mail_to_send = (self.new_record? || self.draft?) ? :new_program_event_notification : :program_event_update_notification
    users, non_member_emails = self.get_users_and_non_member_mails
    users.each do |user|
      ChronusMailer.send(mail_to_send, user, self, {:force_send => true, :test_mail => true}).deliver_now
    end
    non_member_emails.each do |email|
      ChronusMailer.send(mail_to_send, nil, self, {:force_send => true, :test_mail => true, :email => email}).deliver_now
    end
  end

  def get_users_and_non_member_mails
    if self.notification_list_for_test_email.present?
      emails_to_notify = self.notification_list_for_test_email.split(',').map(&:strip)
      users = self.program.all_users.joins(:member).where(members: { email: emails_to_notify })
      emails_to_notify -= users.collect(&:email)
      return users, emails_to_notify
    else
      return [], []
    end
  end

  def self.send_program_event_reminders
    time_now = Time.now
    program_events_for_reminder = ProgramEvent.get_program_events_for_reminder(CronConstants::PROGRAM_EVENT_REMINDERS, CronConstants::PROGRAM_EVENT_REMINDERS_INTERVAL, time_now)

    BlockExecutor.iterate_fail_safe(program_events_for_reminder.upcoming) do |event|
      BlockExecutor.iterate_fail_safe(event.event_invites.needs_reminder.includes(:user)) do |invite|
        user = invite.user

        if user.active?
          invite.reminder_sent_time = time_now
          invite.save!
          Push::Base.queued_notify(PushNotification::Type::PROGRAM_EVENT_REMINDER, event, user_id: user.id)
          ChronusMailer.program_event_reminder_notification(user, event).deliver_now
        end
      end
    end
  end

  def clear_user_rsvp(user)
    self.event_invites.for_user(user).destroy_all
    self.recent_activities.by_member(user.member).of_type([RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_ACCEPT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_REJECT, RecentActivityConstants::Type::PROGRAM_EVENT_INVITE_MAYBE]).destroy_all
  end

  def generate_attendees_csv(file_name)
    header = [
      "feature.program.csv.first_name".translate,
      "feature.program.csv.last_name".translate,
      "feature.program.csv.email".translate,
      "display_string.Role".translate,
      "feature.program_event.label.is_attending".translate
    ]
    tmp_file_name = "/tmp/" + ChronusS3Utils::S3Helper.embed_timestamp(file_name)
    responded_users = self.event_invites.select([:user_id,:status]).group_by(&:user_id)
    role_mapping = RoleConstants.program_roles_mapping(self.program)
    CSV.open(tmp_file_name, 'wb') do |row|
      row << header
      User.connection.execute(self.users.joins(:member).joins(:roles).select("users.id, members.first_name as u_first_name, members.last_name as u_last_name, members.email as u_email, roles.name as role_names").to_sql).group_by(&:first).each do |_id, users|
        user = users.first
        invite = responded_users[user[0]].try(:first)
        row << [user[1], user[2], user[3], users.map{|usr| role_mapping[usr[4]]}.join(AdminViewColumn::ROLES_SEPARATOR), EventInvite::Status.title(invite.try(:status))]
      end
    end
    tmp_file_name
  end

  def users_by_status(tab)
    if tab == ProgramEventConstants::ResponseTabs::NOT_RESPONDED
      responded_users = self.event_invites.pluck(:user_id)
      responded_users = [0] unless responded_users.present?
      self.users.where("users.id NOT IN (?)", responded_users)
    elsif tab == ProgramEventConstants::ResponseTabs::INVITED
      self.users
    else
      self.event_invites.where(:status => StatusByTabMap[tab]).joins(:user)
    end
  end

  def set_users_from_admin_view!(options = {})
    self.paper_trail.record_update(true) if options[:increment_version]
    user_ids_to_set = get_user_ids_to_set(admin_view)

    if has_users?
      current_user_ids = program_event_users.pluck(:user_id)
      user_ids_to_remove = current_user_ids - user_ids_to_set
      if self.published_upcoming? && !options[:status_changed]
        call_notify_users_for_deleted_event(user_ids_to_remove)
      end
      if user_ids_to_remove.any?
        program_event_users.where(user_id: user_ids_to_remove).delete_all
        event_invites.where(user_id: user_ids_to_remove).delete_all
        recent_activities.where(member_id: self.program.users.where(id: user_ids_to_remove).pluck(:member_id)).destroy_all
      end
      user_ids_to_set -= current_user_ids
    end

    if options[:send_mails_for_newly_added] && self.published_upcoming? && self.email_notification == true
      ProgramEvent.delay(queue: DjQueues::HIGH_PRIORITY).notify_new_users(self, RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, version_number, users_ids: user_ids_to_set)
    end

    if user_ids_to_set.any?
      user_ids_to_set.in_groups_of(10000, false) do |user_ids_in_batch|
        program_event_user_objects = user_ids_in_batch.collect do |user_id|
          ProgramEventUser.new(user_id: user_id, program_event_id: self.id)
        end
        ProgramEventUser.import program_event_user_objects
      end
      self.update_column(:admin_view_fetched_at, DateTime.now)
    end
  end

  def get_user_ids_to_set(_admin_view)
    # precomputed_user_ids is only used in tests
    # to address ES Index not being available during fixture generation
    self.precomputed_user_ids || self.admin_view.generate_view("", "", false).to_a
  end

  def has_users?
    ProgramEventUser.exists?(program_event_id: self.id)
  end

  def current_admin_view_changed?
    added_count, removed_count = self.get_current_admin_view_changes
    return (added_count > 0) || (removed_count > 0)
  end

  def get_current_admin_view_changes
    return [0, 0] if self.admin_view_id_changed? || self.admin_view.blank?

    @program_event_admin_view_changes ||= {}
    unless @program_event_admin_view_changes.has_key?(self.id)
      current_user_ids = self.program_event_users.pluck(:user_id)
      admin_view_user_ids = self.get_user_ids_to_set(admin_view)
      added_user_ids = admin_view_user_ids - current_user_ids
      removed_user_ids = current_user_ids - admin_view_user_ids
      @program_event_admin_view_changes[self.id] = [added_user_ids.size, removed_user_ids.size]
    end
    return @program_event_admin_view_changes[self.id]
  end

  def self.calendar_rsvp_program_event(to,body)
    ProgramEvent.update_rsvp_with_calendar(CalendarUtils.get_email_address(to), body)
  end

  def self.update_rsvp_with_calendar(organizer_email, calendar_content)
    return if calendar_content.blank?
    calendar = Icalendar::Calendar.parse(calendar_content).first
    calendar_event = calendar.events.first
    program_event = self.get_program_event_by_calendar_event(organizer_email)
    program_event.update_rsvp!(calendar_event) if program_event.present?
  end

  def self.get_program_event_by_calendar_event(organizer_email)
    encrypted_program_event_id = CalendarUtils.match_organizer_email(organizer_email, APP_CONFIG[:reply_to_program_event_calendar_notification])[:klass_id]
    program_event_id = encryptor.decrypt(encrypted_program_event_id)
    ProgramEvent.find_by(id: program_event_id)
  end

  def update_rsvp!(calendar_event)
    sync_rsvp_with_calendar_event(calendar_event)
  end

  def sync_rsvp_with_calendar_event(calendar_event)
    return unless self.can_be_synced?
    user = rsvp_updated_user(calendar_event)
    return if user.nil?
    event_invite = self.event_invites.find_by(user_id: user.id) || self.event_invites.new(user_id: user.id)
    event_invite.handle_rsvp_from_program_event_and_calendar_event(calendar_event.attendee.first.ical_params["partstat"][0])
  end

  def rsvp_updated_user(calendar_event)
    attendee = calendar_event.attendee.first
    self.users.find{|m| m.email.downcase == attendee.to.try(:downcase)}
  end

  # Append Recent Activity
  def append_to_recent_activity(act_type)
    ra = RecentActivity.create!(
      :member => user.member,
      :ref_obj => self,
      :action_type => act_type,
      :target => RecentActivityConstants::Target::ALL)
    ra.programs = [program]
    ra.save!
  end

  def handle_new_published_event
    append_to_recent_activity(RecentActivityConstants::Type::PROGRAM_EVENT_CREATION)
    if email_notification == true
      ProgramEvent.notify_users(self, RecentActivityConstants::Type::PROGRAM_EVENT_CREATION, version_number, send_now: true, users_ids: self.user_ids)
    end
  end

  def has_current_user_as_attendee?(current_user)
    program_event_users.where(user_id: current_user.id).exists?
  end

  # Connected users should come first then sorting by lates RSVP
  def users_for_listing(current_user)
    ids_string = (current_user.students + current_user.mentors).map(&:id).join(",")
    selects = ['users.id', 'users.member_id', 'users.created_at', 'users.program_id']
    selects << "IF(field(users.id,#{ids_string}) = 0, 0, 1) AS connected_users_rating" if ids_string.present?

    self.users.select(selects).includes([{:member => :profile_picture}, :roles]).
         joins("LEFT JOIN event_invites ON event_invites.program_event_id = program_event_users.program_event_id AND event_invites.user_id = users.id").
         order(ids_string.present? ? "connected_users_rating desc" : "").
         order("event_invites.updated_at desc").order("users.id asc")
  end

  def get_titles_for_all_locales
    self.translations.inject({}) {|titles, event| titles[event.locale] = event.title; titles}
  end

  def get_attending_size
    self.event_invites.attending.count
  end

  private

  def set_admin_view_title
    self.admin_view_title = admin_view.title if admin_view_id_changed? && admin_view.present?
  end

  def handle_cancelled_event_scenario
    if self.published_upcoming?
      users_ids = program_event_users.pluck(:user_id)
      call_notify_users_for_deleted_event(users_ids)
    end
  end

  def call_notify_users_for_deleted_event(users_ids)
    ProgramEvent.delay.notify_users_for_deleted_event( RecentActivityConstants::Type::PROGRAM_EVENT_DELETE,
      {klass_name: self.class.name, klass_id: self.id},
      {send_now: true, title: self.get_titles_for_all_locales, owner_id: self.user_id, program_id: self.program_id, users_ids: users_ids, location: self.location, start_time: self.start_time, created_at: self.created_at, program_event_id: self.id})
  end

  def self.get_ics_calendar_attachment(options = {})
    if options[:notif_type] == RecentActivityConstants::Type::PROGRAM_EVENT_DELETE
      CalendarIcsGenerator.generate_ics_calendar_for_deletion(options[:email_options])
    else
      CalendarIcsGenerator.generate_ics_calendar(options[:ann], user: options[:user])
    end
  end

  def self.notify_users_on_priority(users_relation, ann, notif_type, version, job_log_opts, object, object_initiator, email_options)
    partition_users = User.partition_on_notification_setting(users_relation)
    partition_users.each do |user_list|
      JobLog.compute_with_historical_data(user_list, ann, notif_type, version, job_log_opts.merge!({:parallel_processing => true, :batch_processing => true})) do |user|

        ics_calendar_attachment = get_ics_calendar_attachment(ann: ann, notif_type: notif_type, user: user, email_options: email_options)

        Push::Base.queued_notify(PushNotification::Type::PROGRAM_EVENT_CREATED, ann, {user_id: user.id}) if notif_type == RecentActivityConstants::Type::PROGRAM_EVENT_CREATION
        user.send_email(object, notif_type, email_options.dup.merge(initiator: object_initiator, ics_calendar_attachment: ics_calendar_attachment))
      end
    end
  end

  def self.encryptor
    self.encryption_engine ||= EncryptionEngine::DesEde3Cbc.new(CalendarUtils::ENCRYPTION_KEY)
  end
end
