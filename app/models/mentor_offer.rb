# == Schema Information
#
# Table name: mentor_offers
#
#  id           :integer          not null, primary key
#  program_id   :integer
#  mentor_id    :integer
#  student_id   :integer
#  group_id     :integer
#  message      :text(16777215)
#  response     :text(16777215)
#  status       :integer
#  created_at   :datetime
#  updated_at   :datetime
#  delta        :boolean          default(FALSE)
#  closed_by_id :integer
#  closed_at    :datetime
#

class MentorOffer < ActiveRecord::Base
  include MentorOfferElasticsearchQueries
  include MentorOfferElasticsearchSettings

  CSV_PROCESSES = 4
  CSV_REPORT_SLICE_SIZE = 2500

  class Status
    PENDING = 0
    ACCEPTED = 1
    REJECTED = 2
    WITHDRAWN = 3
    CLOSED = 4


    STATE_TO_STRING = {
      PENDING => "pending",
      ACCEPTED => "accepted",
      REJECTED => "rejected",
      WITHDRAWN => "withdrawn",
      CLOSED => "closed"
    }

    STRING_TO_STATE = {
      "pending" => PENDING,
      "accepted" => ACCEPTED,
      "rejected" => REJECTED,
      "withdrawn" => WITHDRAWN,
      "closed" => CLOSED
    }

    def self.all
      [PENDING, ACCEPTED, REJECTED, WITHDRAWN, CLOSED]
    end
  end

  # Associations
  belongs_to_program
  belongs_to_student_with_validations :student, :foreign_key => 'student_id'
  belongs_to_mentor_with_validations :mentor, :foreign_key => 'mentor_id', touch: true
  belongs_to :group
  belongs_to :closed_by, foreign_key: "closed_by_id", class_name: "User"

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy
  has_many :pending_notifications, as: :ref_obj, dependent: :destroy
  has_many :push_notifications, :as => :ref_obj

  # Validations
  validates_presence_of :program, :status
  validates_inclusion_of :status, :in => Status.all
  validates_permission_of :mentor, :offer_mentoring, :on => :create
  validates :closed_at, presence: true, :if => Proc.new {|offer| offer.closed?}

  validate :check_rejection_has_reason
  validate :check_mentor_can_mentor
  validate :check_program_allows_mentoring_offers
  validate :check_connection_limit_for_mentee, :on => :create

  scope :accepted, -> { where( status: Status::ACCEPTED )}
  scope :rejected, -> { where( status: Status::REJECTED )}
  scope :pending, -> { where( status: Status::PENDING )}
  scope :closed, -> { where( status: Status::CLOSED )}
  scope :withdrawn, -> { where( status: Status::WITHDRAWN )}
  scope :involving, Proc.new {|member_ids|
    where('mentor_id IN (?) AND student_id IN (?)', member_ids, member_ids)
  }
  scope :from_mentor, Proc.new {|mentor| where("mentor_id = ?", mentor.id)}

  attr_accessor :skip_observer

  def accepted?
    self.status == Status::ACCEPTED
  end

  def pending?
    self.status == Status::PENDING
  end

  def rejected?
    self.status == Status::REJECTED
  end

  def withdrawn?
    self.status == Status::WITHDRAWN
  end

  def closed?
    self.status == Status::CLOSED
  end

  # Make the offer accepted and create a group if needed
  def mark_accepted!(group = nil)
    return unless self.pending?
    # Note that we are not handling the error case in group creation assuming
    # it wont ideally happen since the mentor offer itself takes care of
    # all necessary validations
    if self.program.allow_one_to_many_mentoring? && (group && group.mentors.include?(self.mentor))
      student_objs = group.students + [self.student]
      group.actor = self.student
      group.offered_to = self.student
      group.update_members(group.mentors, student_objs, self.student)
      self.status = Status::ACCEPTED
      self.save!
      MentorRequestObserver.without_callback(:after_update) do
        self.program.mentor_requests.involving(group.reload.member_ids).active.each do |mentor_request|
          mentor_request.status = AbstractRequest::Status::WITHDRAWN
          mentor_request.save!
        end
      end
    else
      group = Group.involving(self.student, self.mentor).first
      self.group = group || self.program.groups.create!(:students => [self.student],:mentors  => [self.mentor])

      self.status = Status::ACCEPTED
      self.save!
    end
  end

  def self.send_close_offer_mail(mentor_offer_ids, mail_to_sender, mail_to_recipient)
    mentor_offers = MentorOffer.where(id: mentor_offer_ids)
    mentor_offers.each do |mentor_offer|
      begin
        mentor_offer.mentor.send_email(mentor_offer, RecentActivityConstants::Type::MENTOR_OFFER_CLOSED_SENDER) if mail_to_sender
        mentor_offer.student.send_email(mentor_offer, RecentActivityConstants::Type::MENTOR_OFFER_CLOSED_RECIPIENT) if mail_to_recipient
      rescue => e
        Airbrake.notify("Sending Close Mentor Offer mail failed : #{mentor_offer.inspect}: #{e.message}")
      end
    end
  end

  def self.send_mails(mentor_offers, receiver, mail_type, options = {})
    template = RecentActivityConstants::EmailTemplate[mail_type]
    ChronusMailer.send(template, receiver, mentor_offers, options).deliver_now
  end

  def self.auto_withdraw(group)
   pending_offers = group.program.mentor_offers.involving(group.member_ids).pending
   pending_offers.each do |mentor_offer|
      mentor_offer.status = MentorOffer::Status::WITHDRAWN
      mentor_offer.skip_observer = true 
      mentor_offer.save!
    end
  end

  # Returns an Array of headers suitable to be used as the header for exporting
  # to csv format.
  def self.header_for_exporting
    # Default fields.
    header = [
      'feature.mentor_offer.label.Sender'.translate,
      'feature.mentor_offer.label.Recipient'.translate,
      'feature.mentor_offer.label.offer'.translate,
      'feature.mentor_offer.label.Sent'.translate
    ]
  end

  # Returns an Array of data for exporting the <i>mentor_offers</i>.
  #
  # ==== Params
  # * <tt>mentor_offers</tt>: the MentorOffers to export
  #
  def self.data_for_exporting(mentor_offers)
    data_array = []
    mentor_offers.each do |moffer|
      sent = DateTime.localize(moffer.created_at, format: :short)
      data_array << [moffer.mentor.name, moffer.student.name, moffer.message.to_s.strip, sent]
    end
    data_array
  end

  def self.export_file_name(program, filter, format)
    "#{'manage_strings.program.Administration.Connection.Mentor_Offers'.translate(:Mentoring => program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term)}-#{filter}-#{DateTime.localize(Time.current, format: :csv_timestamp)}.#{format}"
  end

  def self.export_to_stream(stream, admin, offer_ids)
    slice_size = [1 + offer_ids.size / CSV_PROCESSES, CSV_REPORT_SLICE_SIZE].min
    program = admin.program
    headers = MentorOffer.header_for_exporting
    stream << CSV::Row.new(headers, headers).to_s

    parallel_processor.each(offer_ids.each_slice(slice_size), in_processes: CSV_PROCESSES) do |ids|
      # Reconnect DB for each fork (once per each)
      @reconnected ||= MentorOffer.connection.reconnect!
      mentor_offers = program.mentor_offers.where(id: ids).select([:student_id, :mentor_id, :message, :created_at])

      MentorOffer.data_for_exporting(mentor_offers).each do |row_data|
        stream << CSV::Row.new(headers, row_data).to_s
      end
    end
  end

  def self.send_group_mentoring_offer_notification_to_new_mentee(mentor_offer_id)
    mentor_offer = MentorOffer.find_by(id: mentor_offer_id)
    return if mentor_offer.blank?

    ChronusMailer.group_mentoring_offer_notification_to_new_mentee(mentor_offer.student, mentor_offer, mentor_offer.mentor, sender: mentor_offer.mentor).deliver_now
  end

  def self.send_mentor_offer_accepted_notification_to_mentor(mentor_offer_id)
    mentor_offer = MentorOffer.accepted.find_by(id: mentor_offer_id)
    return if mentor_offer.blank?

    ChronusMailer.mentor_offer_accepted_notification_to_mentor(mentor_offer.mentor, mentor_offer, sender: mentor_offer.student).deliver_now
  end

  def self.send_mentor_offer_rejected_notification_to_mentor(mentor_offer_id)
    mentor_offer = MentorOffer.rejected.find_by(id: mentor_offer_id)
    return if mentor_offer.blank?

    ChronusMailer.mentor_offer_rejected_notification_to_mentor(mentor_offer.mentor, mentor_offer, sender: mentor_offer.student).deliver_now
  end

  def self.send_mentor_offer_withdrawn_notification(mentor_offer_id)
    mentor_offer = MentorOffer.withdrawn.find_by(id: mentor_offer_id)
    return if mentor_offer.blank?

    ChronusMailer.mentor_offer_withdrawn(mentor_offer.student, mentor_offer, sender: mentor_offer.mentor).deliver_now
  end

  def can_be_accepted_based_on_mentors_limits?
    self.mentor.is_mentor? && (self.mentor.max_connections_limit - self.mentor.students(:active_or_drafted).size) > 0
  end

  def self.es_reindex(mentor_offer)
    DelayedEsDocument.do_delta_indexing(User, Array(mentor_offer), :mentor_id)
  end

  def close!(reason)
    return unless self.pending?
    self.response = reason
    self.status = MentorOffer::Status::CLOSED
    self.closed_at = Time.now
    self.save!
  end
  private

  def check_mentor_is_mentor
    errors.add(:mentor, "feature.mentor_offer.error.not_mentor".translate(mentor: RoleConstants::MENTOR_NAME)) if self.mentor && !self.mentor.is_mentor?
  end

  def check_rejection_has_reason
    errors.add(:base, "feature.mentor_offer.error.provide_rejection_reason".translate) if self.status == Status::REJECTED and self.response.blank?
  end

  def check_mentor_can_mentor
    return unless self.new_record?
    errors.add(:mentor, "feature.mentor_offer.error.reached_connection_limit_v1".translate(mentoring_conection: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)) if self.program && self.mentor && !self.mentor.can_mentor?
  end

  def check_connection_limit_for_mentee
    errors.add(:student, "feature.mentor_offer.error.reached_connection_limit_v1".translate(mentoring_conection: self.program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).pluralized_term_downcase)) if self.program && self.student && self.student.connection_limit_as_mentee_reached?
  end

  def check_program_allows_mentoring_offers
    return unless self.new_record?
    errors.add(:program, "feature.mentor_offer.error.mentoring_offer_not_allowed_v1".translate(:mentoring => self.program.term_for(CustomizedTerm::TermType::MENTORING_TERM).term_downcase)) if self.program && !(self.program.mentor_offer_needs_acceptance? && self.program.mentor_offer_enabled?)
  end

  def self.parallel_processor
    Parallel
  end

end
