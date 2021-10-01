# == Schema Information
#
# Table name: mentor_requests
#
#  id                 :integer          not null, primary key
#  program_id         :integer
#  created_at         :datetime
#  updated_at         :datetime
#  status             :integer          default(0)
#  sender_id          :integer
#  receiver_id        :integer
#  message            :text(65535)
#  response_text      :text(65535)
#  group_id           :integer
#  show_in_profile    :boolean          default(TRUE)
#  type               :string(255)      default("MentorRequest")
#  delta              :boolean          default(FALSE)
#  closed_by_id       :integer
#  closed_at          :datetime
#  reminder_sent_time :datetime
#  sender_role_id     :integer
#  accepted_at        :datetime
#  acceptance_message :text(65535)
#

class MeetingRequest < AbstractRequest
  include MeetingRequestElasticsearchQueries
  include MeetingRequestElasticsearchSettings

  has_one :meeting, dependent: :nullify
  belongs_to_student_with_validations :student, :foreign_key => 'sender_id'
  belongs_to_mentor_with_validations :mentor, :foreign_key => 'receiver_id'
  belongs_to :closed_by, foreign_key: "closed_by_id", class_name: "User"
  has_many :member_meetings, through: :meeting
  has_many :meeting_proposed_slots, dependent: :destroy
  scope :latest_first, -> { order("id desc") }
  scope :to_or_by_user, ->(member) { member.nil? ? where(nil) : where(["(mentor_requests.sender_id = ?) OR (mentor_requests.receiver_id = ?) ", member.id, member.id]) } #TestRefactoring
  scope :by_ids, ->(meeting_request_ids) { where({:id => meeting_request_ids}) }

  # attr_protected :response_text
  attr_accessor :skip_observer, :skip_email_notification, :proposed_slots_details_to_create

  def self.to_be_closed
    self.closable('meeting_request_auto_expiration_days')
  end

  def update_status!(user, status, options = {})
    options.reverse_merge!(skip_meeting_update: false)
    member = options[:member] || user.member
    program = options[:program] || user.program
    is_mentor = self.mentor == user
    response_hash = is_mentor ? MemberMeeting::MENTOR_RESPONSE_MAP.invert : MemberMeeting::MENTEE_RESPONSE_MAP.invert
    member_meeting = self.member_meetings.find_by!(member_id: member)
    member_meeting.skip_rsvp_change_email = true
    member_meeting.update_attributes!(attending: response_hash[status]) unless options[:skip_meeting_update]
    self.status = status
    self.response_text = options[:response_text]
    self.rejection_type = options[:rejection_type].to_i if options[:rejection_type].present?
    self.acceptance_message = options[:acceptance_message] if self.status == AbstractRequest::Status::ACCEPTED
    self.save!
  end

  def get_meeting_proposed_slots
    is_proposed_slots_present = self.meeting_proposed_slots.size > 0
    meeting_slots = is_proposed_slots_present ? self.meeting_proposed_slots : [self.get_meeting]
    return meeting_slots, is_proposed_slots_present
  end

  # This is needed because meeting's default_scope adds the scope to basically everything
  # So be careful when you use default_scope :)
  def get_meeting
    Meeting.unscoped do
      self.meeting
    end
  end

  def create_meeting_proposed_slots
    (proposed_slots_details_to_create || []).each do |proposed_slot_detail|
      meeting_proposed_slots.create!(proposed_slot_detail.to_h.merge(proposer_id: student.id))
    end
  end

  def receiver_updated_time?
    meeting_proposed_slots.find { |slot| slot.start_time == meeting.start_time && slot.proposer_id == mentor.id }.present?
  end

  class << self
    def send_meeting_request_reminders
      current_time = DateTime.now.utc
      programs = Program.active.includes(:enabled_db_features, organization: [:enabled_db_features, :disabled_db_features])

      BlockExecutor.iterate_fail_safe(programs) do |program|
        next unless program.calendar_enabled? && program.needs_meeting_request_reminder?

        start_time = (current_time - program.meeting_request_reminder_duration.days).at_beginning_of_day
        end_time = (current_time - program.meeting_request_reminder_duration.days + 1.day).at_beginning_of_day
        meeting_requests = program.meeting_requests.active.where(reminder_sent_time: nil).where(created_at: start_time..end_time).includes(:mentor)

        BlockExecutor.iterate_fail_safe(meeting_requests) do |meeting_request|
          meeting = meeting_request.get_meeting

          if meeting.nil? || !meeting.calendar_time_available? || (meeting.start_time > current_time)
            meeting_request.update_attributes!(reminder_sent_time: current_time)
            Push::Base.queued_notify(PushNotification::Type::MEETING_REQUEST_REMINDER, meeting_request)
            ChronusMailer.meeting_request_reminder_notification(meeting_request.mentor, meeting_request).deliver_now
          end
        end
      end
    end

    def send_close_request_mail(meeting_requests, mail_to_sender, mail_to_recipient)
      meeting_requests.each do |meeting_request|
        meeting_request.student.send_email(meeting_request, RecentActivityConstants::Type::MEETING_REQUEST_CLOSED_SENDER) if mail_to_sender
        meeting_request.mentor.send_email(meeting_request, RecentActivityConstants::Type::MEETING_REQUEST_CLOSED_RECIPIENT) if mail_to_recipient
      end
    end

    def send_meeting_request_sent_notification(meeting_request_id)
      meeting_request = MeetingRequest.find_by(id: meeting_request_id)
      return if meeting_request.nil?

      meeting = meeting_request.get_meeting
      return if meeting.archived? || !meeting.calendar_time_available?

      user = meeting_request.student
      ics_calendar_attachment = meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user)
      ChronusMailer.meeting_request_sent_notification(user, meeting_request, ics_calendar_attachment).deliver_now
    end

    def send_meeting_request_created_notification(meeting_request_id)
      meeting_request = MeetingRequest.find_by(id: meeting_request_id)
      return if meeting_request.nil?

      meeting = meeting_request.get_meeting
      return if meeting.archived?

      if meeting.calendar_time_available?
        user = meeting_request.mentor
        ics_calendar_attachment = meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user)
        ChronusMailer.meeting_request_created_notification(user, meeting_request, ics_calendar_attachment, sender: meeting_request.student).deliver_now
      else
        ChronusMailer.meeting_request_created_notification_non_calendar(meeting_request.mentor, meeting_request, sender: meeting_request.student).deliver_now
      end
    end

    def send_meeting_request_status_changed_notification(meeting_request_id)
      meeting_request = MeetingRequest.find_by(id: meeting_request_id)
      return if meeting_request.nil? || meeting_request.active? || meeting_request.closed?

      meeting = meeting_request.get_meeting
      return if meeting.archived?

      sender, receiver = get_recipients(meeting_request)
      method_string = "meeting_request_status_#{AbstractRequest::Status::STATE_TO_STRING[meeting_request.status]}_notification"

      if meeting.calendar_time_available?
        ics_calendar_attachment = meeting.generate_ics_calendar(false, get_ics_type(meeting_request), user: receiver)
        ChronusMailer.send(method_string, receiver, meeting_request, ics_calendar_attachment, sender: sender).deliver_now
      else
        ChronusMailer.send("#{method_string}_non_calendar", receiver, meeting_request, sender: sender).deliver_now
      end
    end

    def send_meeting_request_status_accepted_notification_to_self(meeting_request_id)
      meeting_request = MeetingRequest.accepted.find_by(id: meeting_request_id)
      return if meeting_request.nil?

      meeting = meeting_request.get_meeting
      return if meeting.archived? || !meeting.calendar_time_available?

      sender, receiver = get_recipients(meeting_request)
      ics_calendar_attachment = meeting.generate_ics_calendar(false, get_ics_type(meeting_request), user: sender)
      ChronusMailer.meeting_request_status_accepted_notification_to_self(sender, receiver, meeting_request, ics_calendar_attachment).deliver_now
    end

    def get_meeting_requests(scope, options = {})
      start_time = end_time = nil
      params = options[:params]
      list_scope = params.try(:[], :list)
      arel = scope.meeting_requests
      arel = arel.send_only(list_scope, AbstractRequest::Filter.states) if list_scope
      if (expiry_date = params.try(:[], :search_filters).try(:[], :expiry_date)).present?
        start_time, end_time = CommonFilterService.initialize_date_range_filter_params(expiry_date)
        arel = arel.where(created_at: ((start_time.beginning_of_day)..(end_time.end_of_day)))
      end
      {meeting_requests: arel, start_time: start_time, end_time: end_time}
    end

    def notify_expired_meeting_requests
      BlockExecutor.iterate_fail_safe(self.to_be_closed.includes(:program)) do |meeting_request|
        meeting_request.close_request!
        ChronusMailer.meeting_request_expired_notification_to_sender(meeting_request.student, meeting_request).deliver_now
      end
    end
  end

  def close_request!
    self.close!('feature.meeting_request.auto_expire_message'.translate(mentor: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term_downcase, expiration_days: program.meeting_request_auto_expiration_days))
  end

  private

  def self.get_recipients(meeting_request)
    student = meeting_request.student
    mentor = meeting_request.mentor
    meeting_request.withdrawn? ? [student, mentor] : [mentor, student]
  end

  def self.get_ics_type(meeting_request)
    meeting_request.withdrawn? ? Meeting::IcsCalendarScenario::CANCEL_EVENT : Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT
  end
end
