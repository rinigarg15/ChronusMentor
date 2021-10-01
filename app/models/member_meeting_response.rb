# == Schema Information
#
# Table name: member_meeting_responses
#
#  id                      :integer          not null, primary key
#  meeting_occurrence_time :datetime
#  member_meeting_id       :integer
#  attending               :integer          default(2)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  rsvp_change_source      :integer
#

class MemberMeetingResponse < ActiveRecord::Base
  
  has_paper_trail only: [:rsvp_change_source], on: [:update], class_name: 'ChronusVersion'
  belongs_to :member_meeting
  after_update :post_status_update
  after_create :post_status_update

  validates :attending, inclusion: {in: MemberMeeting::ATTENDING.all}, allow_nil: true

  scope :accepted, -> { where(:attending => MemberMeeting::ATTENDING::YES)}
  scope :rejected, -> { where(:attending => MemberMeeting::ATTENDING::NO)}
  attr_accessor :skip_rsvp_change_email, :perform_sync_to_calendar, :skip_mail_for_calendar_sync

  def meeting
    self.member_meeting.meeting
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

  def send_rsvp_mail(meeting, member_meeting, rsvp_from_app)
    if meeting.can_be_synced?
      send_rsvp_mail_for_all_users(meeting, member_meeting, rsvp_from_app)
    elsif !member_meeting.is_owner?
      send_rsvp_mail_for_owner(meeting, member_meeting)
    end
  end

  def send_rsvp_mail_for_all_users(meeting, member_meeting, rsvp_from_app)
    meeting.member_meetings.where.not(id: member_meeting.id).each do |guest_member_meeting|
      ChronusMailer.meeting_rsvp_notification(guest_member_meeting.user, member_meeting, self.meeting_occurrence_time).deliver_now
    end

    ChronusMailer.meeting_rsvp_notification_to_self(member_meeting.user, member_meeting, self.meeting_occurrence_time).deliver_now if rsvp_from_app
  end

  def send_rsvp_mail_for_owner(meeting, member_meeting)
    ChronusMailer.meeting_rsvp_notification(meeting.owner.user_in_program(meeting.program), member_meeting, self.meeting_occurrence_time).deliver_now if meeting.owner_and_owner_user_present?
  end

  protected

  def post_status_update
    meeting = member_meeting.meeting
    rsvp_from_app = self.perform_sync_to_calendar
    if can_send_rsvp_notification_email?(meeting)
      self.delay(queue: DjQueues::HIGH_PRIORITY).send_rsvp_mail(meeting, member_meeting, rsvp_from_app)
    end

    if can_update_calendar_event_rsvp?(meeting, rsvp_from_app)
      Meeting.delay(queue: DjQueues::HIGH_PRIORITY).update_calendar_event_rsvp(meeting.id, current_occurrence_time: self.meeting_occurrence_time)
    end
  end

  def can_send_rsvp_notification_email?(meeting)
    meeting.active? && !meeting.archived?(self.meeting_occurrence_time) && self.saved_change_to_attending? && meeting.group_id? && !self.skip_rsvp_change_email && !self.skip_mail_for_calendar_sync
  end

  def can_update_calendar_event_rsvp?(meeting, rsvp_from_app)
    meeting.can_be_synced? && self.saved_change_to_attending? && rsvp_from_app
  end
end