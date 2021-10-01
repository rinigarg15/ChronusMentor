# == Schema Information
#
# Table name: calendar_settings
#
#  id                                           :integer          not null, primary key
#  slot_time_in_minutes                         :integer
#  program_id                                   :integer          not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  max_pending_meeting_requests_for_mentee                :integer
#  max_meetings_for_mentee             :integer
#  allow_create_meeting_for_mentor              :boolean          default(FALSE)
#  advance_booking_time                         :integer          default(24)
#  allow_mentor_to_configure_availability_slots :boolean
#  allow_mentor_to_describe_meeting_preference  :boolean
#  feedback_survey_delay_not_time_bound         :integer          default(15)
#  max_pending_meeting_requests_for_mentee      :integer          default(5)
#  max_meetings_for_mentee                      :integer
#

class CalendarSetting < ActiveRecord::Base

  ALLOWED_SLOT_TIME = [0, 30, 60]
  DEFAULT_FEEDBACK_DELAY_TIME_BOUND = 1
  DEFAULT_FEEDBACK_DELAY_NOT_TIME_BOUND = 15

  ALLOWED_SLOT_TIME_AS_OPTION = [[ ->{"common_text.minute".translate(count: 30)}, 30], [ ->{"common_text.minute".translate(count: 60)}, 60], [ ->{"display_string.Unlimited".translate}, 0]]
  
  belongs_to :program
  validates :program, :slot_time_in_minutes, :advance_booking_time, :presence => true
  validates :slot_time_in_minutes, :inclusion => ALLOWED_SLOT_TIME
  validates :max_meetings_for_mentee, :allow_blank => true, :numericality => { :greater_than_or_equal_to => 0 }
  #Advance booking time must be with in 0 to infinite
  validates_inclusion_of :advance_booking_time, :within => 0..1.0/0
  validate :meeting_preference_or_slots_should_be_allowed

  MASS_UPDATE_ATTRIBUTES = {
   :program_update_connection_tab => [:feedback_survey_delay_not_time_bound],
   :program_update_matching_tab => [:feedback_survey_delay_not_time_bound, :slot_time_in_minutes, :max_pending_meeting_requests_for_mentee, :allow_create_meeting_for_mentor, :advance_booking_time, :max_meetings_for_mentee]
  }

  def self.create_default_calendar_setting
    Program.all.each do |program|
      unless (!program.calendar_enabled? || program.calendar_setting.present?)
        program.create_calendar_setting
      end
    end
  end

  def allow_mentor_to_set_all_availability?
    allow_mentor_to_describe_meeting_preference? && allow_mentor_to_configure_availability_slots?
  end

  def meeting_preference_or_slots_should_be_allowed
    unless allow_mentor_to_describe_meeting_preference? || allow_mentor_to_configure_availability_slots?
      mentor_term = program ? program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME).term : 'mentors'
      meeting_term = program ? program.term_for(CustomizedTerm::TermType::MEETING_TERM).term : 'meeting'
      errors[:base] << 'activerecord.custom_errors.calendar_setting.meeting_preference_or_slots_should_be_allowed'.translate(mentors: mentor_term, meetings: meeting_term)
    end
  end

end
