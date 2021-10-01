# == Schema Information
#
# Table name: member_meetings
#
#  id                         :integer          not null, primary key
#  member_id                  :integer          not null
#  meeting_id                 :integer          not null
#  attending                  :integer          default(2)
#  created_at                 :datetime
#  updated_at                 :datetime
#  reminder_time              :datetime
#  reminder_sent              :boolean          default(FALSE)
#  feedback_request_sent      :boolean          default(FALSE)
#  feedback_request_sent_time :datetime
#  api_token                  :string(255)
#  rsvp_change_source         :integer

class MemberMeeting < ActiveRecord::Base
  has_paper_trail only: [:rsvp_change_source], on: [:update], class_name: 'ChronusVersion'

  DEFAULT_MEETING_REMINDER_TIME = 2.hours

  module ATTENDING
    NO = 0
    YES = 1
    NO_RESPONSE = 2

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module RSVP_SOURCE
    MEETING_LISTING = 1
    MEETING_AREA = 2
    GROUP_SIDE_PANE = 3
    FLASH_MENTORING_CALENDAR = 4
    HOME_PAGE_WIDGET = 5

    GA_NAME = {
      MEETING_LISTING => "Meeting Listing",
      MEETING_AREA => "Meeting Area",
      GROUP_SIDE_PANE => "Group Side Pane Widget",
      FLASH_MENTORING_CALENDAR => "Flash Mentoring Calendar",
      HOME_PAGE_WIDGET => "Home Page Widget"
    }
  end

  module RSVP_CHANGE_SOURCE
    CALENDAR = 1
    APP = 2
    EMAIL = 3
    APP_AUTOMATIC = 4
  end

  CALENDAR_EVENT_TO_MEETING_RSVP_MAP = {
    "accepted" => ATTENDING::YES,
    "declined" => ATTENDING::NO,
    "needsAction" => ATTENDING::NO_RESPONSE
  }

  CALENDAR_EVENT_TO_MEETING_RSVP_MAP_ICS = {
    Meeting::CalendarEventPartStatValues::ACCEPTED => ATTENDING::YES,
    Meeting::CalendarEventPartStatValues::DECLINED => ATTENDING::NO,
    Meeting::CalendarEventPartStatValues::NEEDS_ACTION => ATTENDING::NO_RESPONSE
  }

  MEETING_RSVP_TO_ICS_PARTSTAT_MAP = {
    ATTENDING::NO_RESPONSE => Meeting::CalendarEventPartStatValues::NEEDS_ACTION,
    ATTENDING::YES => Meeting::CalendarEventPartStatValues::ACCEPTED,
    ATTENDING::NO => Meeting::CalendarEventPartStatValues::DECLINED
  }

  MENTEE_RESPONSE_MAP = {
    ATTENDING::NO => AbstractRequest::Status::WITHDRAWN,
    ATTENDING::NO_RESPONSE => AbstractRequest::Status::NOT_ANSWERED
  }

  MENTOR_RESPONSE_MAP = MENTEE_RESPONSE_MAP.merge({
    ATTENDING::NO => AbstractRequest::Status::REJECTED,
    ATTENDING::YES => AbstractRequest::Status::ACCEPTED
  })


  belongs_to :member
  belongs_to :meeting
  before_validation :set_api_token, :on => :create
  validates_presence_of :member, :meeting
  validates :attending, inclusion: {in: MemberMeeting::ATTENDING.all}, allow_nil: true

  has_many :survey_answers, :foreign_key => 'member_meeting_id', :dependent => :destroy
  has_many :member_meeting_responses, :dependent => :destroy
  has_many :checkins, :as => :checkin_ref_obj, class_name:  GroupCheckin.name, foreign_key: "checkin_ref_obj_id", dependent: :destroy
  has_many :private_meeting_notes,
           :class_name => "PrivateMeetingNote",
           :foreign_key => 'ref_obj_id',
           :dependent => :destroy
  has_many :push_notifications, :as => :ref_obj
  has_many :campaign_jobs,  :as => :abstract_object, :class_name => "CampaignManagement::SurveyCampaignMessageJob"
  has_one :campaign_status, :as => :abstract_object, :class_name => "CampaignManagement::SurveyCampaignStatus"

  scope :with_time, -> { joins(:meeting).where("meetings.calendar_time_available = ?", true) }
  scope :active, -> { joins(:meeting).where("meetings.active = ?", true) }
  scope :for_mentor_role, -> { joins(:meeting).where("member_meetings.member_id != meetings.mentee_id") }
  scope :for_mentee_role, -> { joins(:meeting).where("member_meetings.member_id = meetings.mentee_id") }
  attr_accessor :skip_rsvp_change_email, :perform_sync_to_calendar, :skip_mail_for_calendar_sync

  def self.send_meeting_reminders
    BlockExecutor.iterate_fail_safe(Meeting.get_meetings_for_reminder(Time.now)) do |rm|
      meeting = rm[:meeting]
      current_occurrence_time = rm[:current_occurrence_time]

      BlockExecutor.iterate_fail_safe(meeting.member_meetings) do |mm|
        user = mm.member.user_in_program(meeting.program)

        if mm.can_send_reminder?(current_occurrence_time) && user.present?
          mm.update_attribute(:reminder_time, current_occurrence_time)
          Push::Base.queued_notify(PushNotification::Type::MEETING_REMINDER, mm, user_id: user.id, current_occurrence_time: current_occurrence_time)
          ChronusMailer.meeting_reminder(user, mm, current_occurrence_time).deliver_now
        end
      end
    end
  end

  def accepted?
    attending == MemberMeeting::ATTENDING::YES
  end

  def rejected?
    attending == MemberMeeting::ATTENDING::NO
  end

  def not_responded?
    attending == MemberMeeting::ATTENDING::NO_RESPONSE
  end

  def accepted_or_not_responded?
    [MemberMeeting::ATTENDING::YES, MemberMeeting::ATTENDING::NO_RESPONSE].include?(attending)
  end

  def is_owner?
    member == meeting.owner
  end

  def get_response_object(current_occurrence_time = nil)
    member_meeting_response = self.member_meeting_responses.find do |meeting_response| 
      meeting_response.meeting_occurrence_time == current_occurrence_time
    end
    member_meeting_response || self
  end

  def handle_rsvp_from_meeting_and_calendar_event(event_rsvp)
    meeting_rsvp = self.get_response_object.attending
    event_rsvp = MemberMeeting::CALENDAR_EVENT_TO_MEETING_RSVP_MAP_ICS[event_rsvp]
    if event_rsvp && meeting_rsvp != event_rsvp && event_rsvp != MemberMeeting::ATTENDING::NO_RESPONSE        
      self.member.mark_attending!(self.meeting, {perform_sync_to_calendar: false, attending: event_rsvp, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR})
    end
  end

  def get_meeting_occurrence_rsvp(current_occurrence_time)
    get_response_object(current_occurrence_time).attending
  end

  def get_feedback_answers(current_occurrence_time)
    self.survey_answers.where(meeting_occurrence_time: current_occurrence_time)
  end

  def can_send_reminder?(current_occurrence_time)
    (self.reminder_time.nil? || (self.reminder_time < current_occurrence_time)) && self.get_response_object(current_occurrence_time).accepted_or_not_responded? && self.member.active?
  end

  def get_meeting
    Meeting.unscoped do
      self.meeting
    end
  end

  def other_members
    self.meeting.member_meetings.where.not(id: self.id).map(&:member)
  end

  def due_date_for_campaigns
    meeting.end_time
  end

  def user
    member.user_in_program(meeting.program)
  end

  def self.users(member_meeting_ids)
    MemberMeeting.where(id: member_meeting_ids).joins("LEFT JOIN meetings ON (member_meetings.meeting_id = meetings.id)").joins("LEFT JOIN users ON (member_meetings.member_id = users.member_id AND meetings.program_id = users.program_id)").pluck("DISTINCT(users.id)")
  end

  def can_send_campaign_email?
    user && self.get_feedback_answers(meeting.first_occurrence).empty? && meeting.end_time < Time.now.utc
  end

  def self.get_members_and_meetings_count(member_meeting_ids)
    members_and_meetings_array =  MemberMeeting.where(:id => member_meeting_ids).pluck(:meeting_id, :member_id)
    meetings_count, members_count = members_and_meetings_array.map(&:first).uniq.count, members_and_meetings_array.map(&:second).uniq.count
    return members_count, meetings_count
  end

  def set_api_token
    self.api_token = secure_digest(Time.now, (1..10).map{ rand.to_s })
  end

  def secure_digest(*args)
    Digest::MD5.hexdigest(args.flatten.join('--'))
  end

  def handle_reply_via_email(email_params)
    email_type = email_params[:obj_type]
    meeting = self.get_meeting
    meeting_request = meeting.meeting_request
    organization = meeting.program.organization
    sender = self.member
    receivers = [email_params[:original_sender_member]]
    return false unless MemberMeeting.can_user_reply_to_email?(sender, receivers[0], meeting, {reminder_email: email_type == ReplyViaEmail::MEETING_REMINDER_NOTIFICATION})
    case email_type
    when ReplyViaEmail::MEETING_REQUEST_ACCEPTED_CALENDAR, ReplyViaEmail::MEETING_REQUEST_ACCEPTED_NON_CALENDAR
      create_scrap = meeting.active?
    when ReplyViaEmail::MEETING_RSVP_NOTIFICATION_OWNER, ReplyViaEmail::MEETING_UPDATE_NOTIFICATION
      create_scrap = meeting.active? && meeting.group.nil?
    when ReplyViaEmail::MEETING_CREATED_NOTIFICATION
      create_scrap = false
    when ReplyViaEmail::MEETING_REMINDER_NOTIFICATION
      create_scrap = meeting.active? && meeting.group.nil?
      receivers = meeting.members.select{|m|m.user_in_program(meeting.program).active?} - [sender]
      return false unless receivers.size > 0
    end
    if create_scrap
      create_message_or_scrap_for_reply_to_meeting(Scrap.to_s, sender, receivers, email_params)
    else
      create_message_or_scrap_for_reply_to_meeting(Message.to_s, sender, receivers, email_params)
    end
  end

  def create_message_or_scrap_for_reply_to_meeting(type, sender, receivers, email_params)
    msg = email_params[:content]
    if(type == Message.to_s)
      organization = self.meeting.program.organization
      message_or_scrap = organization.messages.new
    else
      message_or_scrap = self.meeting.scraps.new
      message_or_scrap.program = self.meeting.program
    end
    message_or_scrap.sender = sender
    message_or_scrap.receivers = receivers
    message_or_scrap.subject = email_params[:subject]
    message_or_scrap.content = msg
    message_or_scrap.posted_via_email = true
    message_or_scrap.save!
    return true
  end

  def self.can_user_reply_to_email?(sender, receiver, meeting, options)
    sender_user = meeting.get_user(sender)
    return sender && sender_user && !sender_user.suspended? if options[:reminder_email]
    receiver_user = meeting.get_user(receiver)
    sender && sender_user && !sender_user.suspended? && receiver && receiver_user && !receiver_user.suspended?
  end

  def self.es_reindex(member_meeting)
    DelayedEsDocument.do_delta_indexing(Meeting, Array(member_meeting), :meeting_id)
  end
end
