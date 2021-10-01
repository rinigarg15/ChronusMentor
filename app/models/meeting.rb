require 'icalendar/tzinfo'
# == Schema Information
#
# Table name: meetings
#
#  id                      :integer          not null, primary key
#  group_id                :integer
#  description             :text(65535)
#  topic                   :string(255)
#  start_time              :datetime
#  end_time                :datetime
#  location                :text(65535)
#  owner_id                :integer          not null
#  created_at              :datetime
#  updated_at              :datetime
#  program_id              :integer          not null
#  delta                   :boolean          default(FALSE)
#  ics_sequence            :integer          default(0)
#  meeting_request_id      :integer
#  calendar_time_available :boolean          default(TRUE)
#  active                  :boolean          default(TRUE)
#  schedule                :text(65535)
#  parent_id               :integer
#  recurrent               :boolean          default(FALSE)
#  state                   :string(255)
#  mentee_id               :integer
#  state_marked_at         :datetime
#

class Meeting < ActiveRecord::Base
  include IceCube
  include MeetingElasticsearchQueries
  include MeetingElasticsearchSettings
  include CalendarUtils

  has_paper_trail only: [:start_time], on: [:update], class_name: 'ChronusVersion'
  
  SLOTS_PER_DAY = 48
  SLOT_TIME_IN_MINUTES = 30
  CAN_CREATE_MEETINGS_AFTER = 0
  CHECKIN_START_WINDOW = 1.day
  DESCRIPTION_TRUNCATION_LENGTH_IN_MAILS = 125

  UPCOMING_MEETINGS_WIDGET_END_DAYS = 30
  MEETINGS_COUNT_IN_UPCOMING_MEETINGS_WIDGET = 3

  FLASH_WIDGET_MEETING_END_TIME = 2.weeks
  MIN_ATTENDEES_PRESENT_IN_FLASH_WIDGET_MEETS = 1
  MIN_ATTENDEES_FOR_SELECT_ALL = 4

  UPCOMING_PER_PAGE = 10
  ARCHIVED_PER_PAGE = 10
  MAXIMUM_INDIVIDUAL_OCCURRENCES_TO_SYNC = 3
  MAXIMUM_NUMBER_OF_SYNC_EMAILS = 5
  CALENDAR_SYNC_NECESSARY_EMAILS = [MeetingCancellationNotificationToSelf, MeetingRequestStatusAcceptedNotification, MeetingCancellationNotification, MeetingEditNotificationToSelf, MeetingCreationNotificationToOwner, MeetingRsvpSyncNotificationFailureMail, MeetingCreationNotification, MeetingRequestStatusAcceptedNotificationToSelf, MeetingRsvpNotificationToSelf, MeetingRsvpNotification, MeetingEditNotification]

  START_RSVP_SYNC_METHOD_REGEX = /start_rsvp_sync_\d+/

  module QuickConnect
    DEFAULT_NOT_CONNECTED_FOR = 10
    QUICK_CONNECT_ITEMS = 3
    MATCH_SCORE_THRESHOLD = 50
  end

  module MentorSuggest
    MENTOR_COUNT = 6
  end

  module Interval
    WEEK = 7
    MONTH = 30
    QUARTER = 90
  end

  module IcsCalendarScenario
    CREATE_UPDATE_EVENT = 0
    PUBLISH_EVENT = 1
    CANCEL_EVENT = 2
  end

  module AnalyticsParams
    REQUEST_MEETING_BUTTON = "request_meeting_button"
    QUICK_MEETING_POPUP = "quick_meeting_popup"
    QUICK_MEETING = "quick_meeting"
    MENTORING_CALENDAR_LINK_POPUP = "mentoring_calendar_link_popup"
    MENTORING_CALENDAR_LINK = "mentoring_calendar_link"
    QUICK_CONNECT_REQUEST_MEETING = "quick_connect_request_meeting"
  end

  module Repeats
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3

    def self.all
      [DAILY, WEEKLY, MONTHLY]
    end

    def self.options_for_select
      [
        ["feature.mentoring_slot.repeats.Daily".translate, DAILY],
        ["feature.mentoring_slot.repeats.Weekly".translate, WEEKLY],
        ["feature.mentoring_slot.repeats.Monthly".translate, MONTHLY]
      ]
    end
  end

  module EditOption
    CURRENT = "1"
    FOLLOWING = "2"
    ALL = "3"
  end

  module State
    COMPLETED = "0"
    CANCELLED = "1"
  end

  module Tabs
    DETAILS = 0
    MESSAGES = 1
    NOTES = 2
  end

  module ReportTabs
    SCHEDULED = "0"
    OVERDUE = "1"
    COMPLETED = "2"
    CANCELLED = "3"
    UPCOMING = "4"
    PAST = "5"
  end

  module CalendarEventPartStatValues
    NEEDS_ACTION = "NEEDS-ACTION"
    ACCEPTED = "ACCEPTED"
    DECLINED = "DECLINED"
  end

  belongs_to :program
  belongs_to :group
  belongs_to :owner, :class_name => "Member"
  belongs_to :meeting_request
  belongs_to :mentee, class_name: "Member"

  has_many :member_meetings, :dependent => :destroy, :inverse_of => :meeting
  has_many :survey_answers, :through => :member_meetings
  has_many :members, :through => :member_meetings
  has_many :member_meeting_responses, :through => :member_meetings
  has_many :attendees, :through => :member_meetings, :source => :member

  has_many :recent_activities, :as => :ref_obj, :dependent => :destroy

  has_many :scraps, :as => :ref_obj, :dependent => :nullify

  has_many :private_meeting_notes,
           :through => :member_meetings
  has_many :push_notifications, :as => :ref_obj

  validates :end_time, :start_time, :program, presence: true
  validate :check_start_time_should_be_lesser, if: Proc.new { |meeting| meeting.start_time? && meeting.end_time? }
  validates :topic, presence: true
  validates_presence_of :mentee_id, unless: Proc.new { |meeting| meeting.group_meeting? }
  validate :mentee_should_be_part_of_meeting, unless: Proc.new { |meeting| meeting.group_meeting? }

  default_scope -> { where(active: true) }

  scope :of_group, Proc.new {|group| where({:group_id => group.id})}
  scope :of_program, Proc.new {|program| where(:program_id => program.id)}
  scope :in_programs, Proc.new {|program_ids| where(program_id: program_ids)}
  scope :between_time, Proc.new{|st,en| where(["start_time < ? and end_time > ?", en.utc.to_s(:db), st.utc.to_s(:db)])}
  scope :with_endtime_in, Proc.new{|start_window, end_window| where({:end_time => start_window.utc..end_window.utc})}
  scope :with_starttime_in, Proc.new{|start_window, end_window| where({:start_time => start_window.utc..end_window.utc})}
  scope :past, Proc.new{where("end_time < ?", Time.now.utc)}
  scope :upcoming, Proc.new{where("end_time > ?", Time.now.utc)}
  scope :with_endtime_less_than, Proc.new{|end_window| where(["end_time < ?", end_window])}
  scope :involving, Proc.new{ |mentor_id, mentee_id|
    select("meetings.*").joins(:member_meetings).where({:member_meetings => {:member_id => [mentor_id, mentee_id]}}).group("meetings.id").having("count(meetings.id) > 1")
  }
  scope :slot_availability_meetings, -> { where(calendar_time_available: true)}
  scope :general_availability_meetings, -> { where(calendar_time_available: false)}
  scope :group_meetings, -> { where("meetings.group_id IS NOT NULL")}
  scope :non_group_meetings, -> { where(group_id: nil)}
  scope :accepted_meetings, -> { joins("LEFT JOIN mentor_requests ON mentor_requests.id = meetings.meeting_request_id").where("mentor_requests.status = ? or meeting_request_id IS NULL", AbstractRequest::Status::ACCEPTED) }
  scope :accepted_or_pending_meetings, -> { joins("LEFT JOIN mentor_requests ON mentor_requests.id = meetings.meeting_request_id").where("mentor_requests.status = ? or (mentor_requests.status = ? and meetings.calendar_time_available = ?) or meeting_request_id IS NULL", AbstractRequest::Status::ACCEPTED, AbstractRequest::Status::NOT_ANSWERED, true) }
  scope :completed, ->{ where(state: Meeting::State::COMPLETED) }
  scope :cancelled, ->{ where(state: Meeting::State::CANCELLED) }
  scope :mentee_created_meeting, -> { where("meetings.owner_id = meetings.mentee_id") }

  attr_accessor :date, :skip_email_notification, :start_time_of_day, :end_time_of_day, :requesting_mentor, :requesting_student, :mentor_created_meeting, :in_current_view, :milestone_id, :schedule_rule, :repeats_end_date, :repeats_by_month_date, :repeats_on_week, :repeat_every, :edit_option, :current_occurrence_time, :duration, :no_occurrence_error, :create_ra, :skip_observer, :proposed_slots_details_to_create, :skip_rsvp_change_email, :updated_by_member, :skip_create_calendar_event

  cattr_accessor :encryption_engine

  serialize :schedule, IceCube::Schedule

  MASS_UPDATE_ATTRIBUTES = {
    :create => [:start_time_of_day, :location, :topic, :group_id, :description, :end_time_of_day, :date, :schedule_rule, :repeats_end_date, :repeats_by_month_date, :repeats_on_week, :recurrent, :repeat_every],
    :update => [:start_time_of_day, :location, :topic, :group_id, :description, :end_time_of_day, :date, :schedule_rule, :repeats_end_date, :repeats_by_month_date, :repeats_on_week, :recurrent, :repeat_every]
  }

  class << self

    def get_millisecond(time)
      (time.to_f * 1000).to_i
    end

    def es_reindex(meeting)
      group_ids = Array(meeting).collect(&:group_id).uniq
      reindex_group(group_ids)
    end

    def reindex_group(group_ids)
      DelayedEsDocument.delayed_bulk_update_es_documents(Group, group_ids)
    end

    def update_rsvp_with_calendar(organizer_email, calendar_content)
      return if calendar_content.blank?
      calendar = Icalendar::Calendar.parse(calendar_content).first
      event = calendar.events.first
      meeting = self.get_meeting_by_event(organizer_email)
      meeting.update_rsvp!(event) if meeting.present?
    end

    def get_meeting_by_event(organizer_email)
      encrypted_meeting_id = CalendarUtils.match_organizer_email(organizer_email, APP_CONFIG[:reply_to_calendar_notification])[:klass_id]
      meeting_id = encryptor.decrypt(encrypted_meeting_id)
      Meeting.find_by(id: meeting_id)
    end

    def false_destroy_without_email!(meeting_id)
      meeting = Meeting.where(id: meeting_id).first
      return if meeting.nil?
      meeting.skip_email_notification = true
      meeting.false_destroy!
    end

    def generate_ics_calendar_events(ics_events_array, ics_action, is_owner = false, options = {})
      ics_cal_feed = options[:ics_cal_feed]
      cal = RiCal.Calendar do |calobj|
        if ics_action == IcsCalendarScenario::CREATE_UPDATE_EVENT
          calobj.icalendar_method = (is_owner && !options[:calendar_sync_enabled]) ? "PUBLISH" : "REQUEST"
        elsif ics_action == IcsCalendarScenario::PUBLISH_EVENT
          calobj.icalendar_method = "PUBLISH"
        else
          calobj.icalendar_method = "CANCEL"
        end
        ics_events_array.each do |ics_event|
          meeting = Meeting.unscoped.find_by(id: ics_event[:meeting_id])
          meeting_time_zone = meeting.meeting_time_zone
          calobj.event do |event|
            event.dtstart = meeting.recurrent? ? DateTime.parse(DateTime.localize(ics_event[:start_time].to_time.in_time_zone(meeting_time_zone), format: :ics_full_time)).set_tzid(meeting_time_zone) : DateTime.parse(DateTime.localize(ics_event[:start_time].to_time.utc, format: :ics_full_time))
            event.dtend = meeting.recurrent? ? DateTime.parse(DateTime.localize(ics_event[:end_time].to_time.in_time_zone(meeting_time_zone), format: :ics_full_time)).set_tzid(meeting_time_zone) : DateTime.parse(DateTime.localize(ics_event[:end_time].to_time.utc, format: :ics_full_time))
            options = {'CUTYPE' => 'INDIVIDUAL','ROLE' => 'REQ-PARTICIPANT'}
            attendee_property = []
            ics_event[:guest_details].each do |guest|
              attendee_property << RiCal::PropertyValue::CalAddress.new(nil, :value => "mailto:"+guest[:email], :params => options.merge('CN' => guest[:name], 'PARTSTAT' => guest[:part_stat] || CalendarEventPartStatValues::NEEDS_ACTION))
            end
            event.attendee_property = attendee_property
            event.dtstamp = DateTime.parse(DateTime.localize(Time.now.utc, format: :ics_full_time))
            options = {'CN' => ics_event[:organizer][:name]}
            event.organizer_property = RiCal::PropertyValue::CalAddress.new(nil, :value => "mailto:"+ics_event[:organizer][:email], :params => options)
            event.uid = ics_event[:uid]
            event.created = DateTime.parse(DateTime.localize(Time.now.utc, format: :ics_full_time))
            event.description = ics_event[:description].present? ? ics_event[:description] : "feature.meetings.content.meeting_scheduled_in_program_v1".translate(:program => Program.name, :Meeting => Meeting.name)
            event.last_modified = DateTime.parse(DateTime.localize(Time.now.utc, format: :ics_full_time))
            event.location = ics_event[:location] if ics_event[:location].present?
            event.sequence = ics_event[:sequence]
            event.status = (ics_action == IcsCalendarScenario::CREATE_UPDATE_EVENT || ics_action == IcsCalendarScenario::PUBLISH_EVENT) ? "CONFIRMED" : "CANCELLED"
            event.summary = ics_event[:topic]
            event.transp = "OPAQUE"
            event.rrule = ics_event[:recurrence] if ics_event[:recurrence].present?
            event.exdates = ics_event[:exdates].split(",") if ics_event[:exdates].present?
            event.recurrence_id = DateTime.parse(DateTime.localize(ics_event[:recurrence_id].to_time.utc, format: :ics_full_time)) if ics_event[:recurrence_id].present?
          end
          calobj.chronus_ics_timezone_component = meeting.get_vtimezone_component unless ics_cal_feed
        end
      end
      return cal
    end

    def get_ics_event(meetings, options = {})
      meetings_array = []
      meetings_data = [meetings].flatten
      meetings_data.each do |meeting|
        start_time, end_time = Meeting.get_event_start_and_end_time(meeting, options)
        rrule, exdates = meeting.fetch_rrule(options)
        event_options = {
          :meeting_id => meeting.id,
          :start_time => start_time,
          :end_time => end_time,
          :guest_details => meeting.ics_guests_details(options[:user], options[:deleted_meeting], options),
          :topic => meeting.topic,
          :description => meeting.get_meeting_description_for_calendar_event(options[:user]),
          :location => meeting.location,
          :sequence => meeting.ics_sequence,
          :uid => meeting.get_calendar_event_uid,
          :organizer => ics_organizer(meeting, options[:deleted_meeting]),
          :recurrence => rrule,
          :exdates => exdates
        }
        event_options.merge!({recurrence_id: start_time}) if options[:current_occurrence_time].present?
        meetings_array << event_options
      end
      return meetings_array
    end

    def get_event_start_and_end_time(meeting, options = {})
      start_time = (options[:current_occurrence_time] || meeting.occurrences.first.start_time).utc
      return [DateTime.localize(start_time, format: :ics_full_time), DateTime.localize(start_time + meeting.schedule.duration, format: :ics_full_time)]
    end

    def fetch_start_end_time_for_the_month(view_date)
      per_start_time = view_date.in_time_zone.beginning_of_month.beginning_of_day
      per_end_time = view_date.in_time_zone.end_of_month.end_of_day
      return per_start_time, per_end_time
    end

    def ics_organizer(meeting, deleted_meeting = false)
      encrypted_id = encryptor.encrypt(meeting.id)
      if meeting.can_be_synced?(deleted_meeting)
        {name: APP_CONFIG[:scheduling_assistant_display_name], email: "#{APP_CONFIG[:reply_to_calendar_notification]}+#{encrypted_id}@#{MAILGUN_DOMAIN}"}
      else
        { :name => meeting.owner.try(:name) || "feature.meetings.content.removed_user".translate, :email => meeting.owner.try(:email) || "feature.meetings.content.removed_user".translate }
      end
    end

    def construct_display_mentoring_report_objects(mentoring_session_reports_array)
      reports_array = []
      mentoring_session_reports_array.each{|report_obj|
        reports_array << DisplayMentoringSessionReport.new(report_obj)
      }
      reports_array
    end

    # Returns [upcoming, archived] meetings
    # Else merged list of [upcoming, archived] if option[:get_merged_list] is true
    # If options[:get_occurrences_between_time] is true then return recurrent meetings which occurs between options[:start_time] and options[:end_time]
    # If options[:with_endtime_in] is true then return recurrent meetings which ends between options[:start_time] and options[:end_time]
    def recurrent_meetings(meetings, options = {})
      time_now = Time.now.to_i
      meetings_array = []
      meetings.each do |meeting|
        duration = meeting.schedule.duration
        meeting.occurrences.each do |occurrence|
          start_time = occurrence.start_time.in_time_zone(Time.zone)
          accepted_time = meeting.meeting_request.try(:accepted_at) if options[:with_accepted_at_in]
          meetings_array << {current_occurrence_time: start_time, meeting: meeting} if valid_occurrence?(options, occurrence, start_time, time_now, accepted_time)
        end
      end
      return meetings_array if options[:get_merged_list]
      return meetings_array.sort_by{|m| (m[:current_occurrence_time]+ m[:meeting].schedule.duration).to_i} if options[:get_only_upcoming_meetings]
      return meetings_array.sort_by{|m| (m[:current_occurrence_time]+ m[:meeting].schedule.duration).to_i}.reverse! if options[:get_only_past_meetings]

      meetings_array = meetings_array.sort_by{|m| (m[:current_occurrence_time]+ m[:meeting].schedule.duration).to_i}
      past_meets = meetings_array.reverse
      upcoming_meets = []
      meetings_array.each_with_index do |m, index|
        if (m[:current_occurrence_time]+ m[:meeting].schedule.duration).to_i > time_now
          if index > 0
            past_meets = meetings_array[0..(index-1)].reverse
          else
            past_meets = []
          end
          upcoming_meets = meetings_array[index..(meetings_array.size)]
          break
        end
      end
      return upcoming_meets, past_meets
    end

    def upcoming_recurrent_meetings(meetings)
      recurrent_meetings(meetings, {get_only_upcoming_meetings: true})
    end

    def past_recurrent_meetings(meetings)
      recurrent_meetings(meetings, {get_only_past_meetings: true})
    end

    def paginated_meetings(meetings_to_be_held, archived_meetings, meeting_params, wob_member)
      if meeting_params[:meeting_id].present?
        meeting = wob_member.meetings.find(meeting_params[:meeting_id])
        current_occurrence_time = meeting_params[:current_occurrence_time] || meeting.occurrences.first.start_time
        archived_index = archived_meetings.index({current_occurrence_time: current_occurrence_time.to_time, meeting: meeting})
        upcoming_index = meetings_to_be_held.index({current_occurrence_time: current_occurrence_time.to_time, meeting: meeting})
        archived_page = archived_index.present? ? (archived_index / Meeting::ARCHIVED_PER_PAGE).to_i + 1 : 1
        upcoming_page = upcoming_index.present? ? (upcoming_index / Meeting::UPCOMING_PER_PAGE).to_i + 1 : 1
      end
      meetings_to_be_held = meetings_to_be_held.paginate(:page => meeting_params[:upcoming_page] || upcoming_page, :per_page => Meeting::UPCOMING_PER_PAGE) if meetings_to_be_held.present?
      archived_meetings = archived_meetings.paginate(:page => meeting_params[:archived_page] || archived_page, :per_page => Meeting::ARCHIVED_PER_PAGE) if archived_meetings.present?
      [meetings_to_be_held, archived_meetings]
    end

    def get_meetings_to_render_in_home_page_widget(wob_member, program)
      start_time = Time.now.in_time_zone(wob_member.get_valid_time_zone)
      end_time = start_time.end_of_day + FLASH_WIDGET_MEETING_END_TIME
      meetings = Meeting.get_meetings_for_view(nil, nil, wob_member, program).with_starttime_in(start_time, end_time)
      meetings = Meeting.upcoming_recurrent_meetings(meetings)
      Meeting.has_attendance_more_than(meetings, MIN_ATTENDEES_PRESENT_IN_FLASH_WIDGET_MEETS)
    end

    def parse_occurrence_time(occurrence_time)
      Time.zone.parse(occurrence_time) if occurrence_time
    end

    def get_meetings_for_view(group, is_admin_view, member, program, options = {})
      include_options = [{:member_meetings => [:member_meeting_responses, :member]}, :owner]

      if options[:from_my_availability].present?
        return program.get_accessible_meetings_list(member.meetings).accepted_meetings.includes(include_options)
      elsif group.present?
        return is_admin_view ? group.meetings.slot_availability_meetings.includes(include_options) : member.meetings.of_group(group).slot_availability_meetings.includes(include_options)
      else
        return member.meetings.of_program(program).accepted_meetings.includes(include_options)
      end
    end

    def has_attendance_more_than(recurring_meetings, count)
      valid_recurring_meetings = []
      recurring_meetings.each do |r_meeting|
        meeting = r_meeting[:meeting]
        attendees_count = 0
        meeting.member_meetings.each do |mm|
          attendees_count += 1 if mm.get_response_object(r_meeting[:current_occurrence_time]).accepted_or_not_responded?
        end
        valid_recurring_meetings << r_meeting if attendees_count > count
      end
      valid_recurring_meetings
    end

    # Returns the sum of hours of *meetings* passed as the argument
    # Params:
    # *meetings_occurrences*: A collection of meeting_occurrences
    def hours(meetings_occurrences)
      meetings_occurrences.inject(0) {|sum, meet| sum + meet[:meeting].duration_in_hours_for_one_occurrences }
    end

    def get_valid_start_times(configured_slot_time)
      return (beginning_of_calendar = Time.new.beginning_of_day) && ((0..(SLOTS_PER_DAY - (configured_slot_time/SLOT_TIME_IN_MINUTES))).collect{|i| DateTime.localize(beginning_of_calendar + (i*SLOT_TIME_IN_MINUTES).minutes, format: :short_time_small)})
    end

    def get_valid_end_times(configured_slot_time)
      return valid_start_time_boundaries[(configured_slot_time/SLOT_TIME_IN_MINUTES)..-1] + [DateTime.localize(Time.new.beginning_of_day + (SLOTS_PER_DAY * SLOT_TIME_IN_MINUTES).minutes, format: :short_time_small)]
    end

    def valid_start_time_boundaries(options = {})
      slot_time = options[:slot_time] || SLOT_TIME_IN_MINUTES
      slots_per_day = options[:slots_per_day] || SLOTS_PER_DAY
      (beginning_of_calendar = Time.new.beginning_of_day) && ((0..(slots_per_day - 1)).collect{|i| DateTime.localize(beginning_of_calendar + (i*slot_time).minutes, format: :short_time_small)})
    end

    def valid_end_time_boundaries(options = {})
      slot_time = options[:slot_time] || SLOT_TIME_IN_MINUTES
      slots_per_day = options[:slots_per_day] || SLOTS_PER_DAY
      valid_start_time_boundaries(slot_time: slot_time, slots_per_day: slots_per_day)[1..-1] + [DateTime.localize(Time.new.beginning_of_day + (slots_per_day * slot_time).minutes, format: :short_time_small)]
    end

    def get_meetings_creation_message(flash, message)
      return (flash + "<br/>" + message).html_safe if flash.present?
      return message
    end

    def get_meetings_for_reminder(time_now)
      end_time = time_now + MemberMeeting::DEFAULT_MEETING_REMINDER_TIME
      return Meeting.recurrent_meetings(Meeting.slot_availability_meetings.between_time(time_now, end_time), {with_starttime_in: true, start_time: time_now, end_time: end_time, get_merged_list: true})
    end

    def get_meetings_for_upcoming_widget(program, member1, member2)
      meetings = program.meetings.accepted_meetings.involving(member1.id, member2.id).between_time(Time.now, Time.now + UPCOMING_MEETINGS_WIDGET_END_DAYS.days)
      meetings = Meeting.upcoming_recurrent_meetings(meetings).first(MEETINGS_COUNT_IN_UPCOMING_MEETINGS_WIDGET)
      return meetings
    end

    def perform_rsvp_sync_from_calendar_to_app(events, scheduling_account_email)
      recurring_events = events.select{|event|event.recurring_event_id.present?}
      non_recurring_events = events - recurring_events
      perform_sync_for_non_recurring_events(non_recurring_events, scheduling_account_email)
      perform_sync_for_recurring_events(recurring_events, scheduling_account_email)
    end

    def perform_sync_for_non_recurring_events(non_recurring_events, scheduling_account_email)
      non_recurring_events.each do |event|
        Meeting.sync_rsvp_with_calendar_event(event, scheduling_account_email)
      end
    end

    def perform_sync_for_recurring_events(recurring_events, scheduling_account_email)
      event_ids = recurring_events.collect{|event| Meeting.get_recurring_event_id(event)}.uniq
      meeting_eagerload_options = [{:member_meetings => [:member_meeting_responses, :member]}]
      recurring_meetings = Meeting.where(calendar_event_id: event_ids, scheduling_email: scheduling_account_email).includes(meeting_eagerload_options)
      recurring_events.group_by{|event| Meeting.get_recurring_event_id(event)}.each do |event_id, event_occurrences|
        meeting = recurring_meetings.find{|meeting| meeting.calendar_event_id == event_id}
        next unless meeting.present? && meeting.can_be_synced?
        occurrence_time_response_hash = meeting.build_meeting_occurrence_response_hash(event_occurrences)
        meeting.handle_sync_for_recurring_event(occurrence_time_response_hash)
      end
    end

    
    def get_recurring_event_id(event)
      begin
        event.recurring_event_id.present? ? event.recurring_event_id.gsub(/_R+\d{8}T\d{6}/, "") : event.recurring_event_id
      rescue => e
        CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::FETCH_RECURRENT_ID, {event_id: event.id, error_message: e.message})
        Airbrake.notify("Could not fetch recurrent_id from calendar event with id #{event.id} Exception: #{e.message}")
      end
    end

    def sync_rsvp_with_calendar_event(event, scheduling_account_email)
      meeting = Meeting.find_by(calendar_event_id: event.id, scheduling_email: scheduling_account_email)
      return unless meeting.present? && meeting.can_be_synced?
      member_member_meeting_hash = meeting.member_meetings.group_by(&:member)
      members = member_member_meeting_hash.keys

      event.attendees.each do |attendee|
        member = members.find{|m| m.email == attendee.email}
        member_meeting = member_member_meeting_hash[member].first if member.present?

        if member_meeting.present?
          handle_rsvp_from_meeting_and_calendar_event(member_meeting, attendee.response_status)
        end
      end
    end

    def get_recurring_event_start_time(event)
      Meeting.parse_occurrence_time(event.id.split("_").last) if event.recurring_event_id.present?
    end

    def remove_calendar_event(meeting_id)
      meeting = Meeting.unscoped.find(meeting_id)
      return unless meeting.calendar_event_id.present?
      Calendar::GoogleApi.new(meeting.get_scheduling_email).remove_calendar_event(meeting.calendar_event_id)
      meeting.update_attribute(:calendar_event_id, nil)
    end

    def update_calendar_event_rsvp(meeting_id, options = {})
      meeting = Meeting.find_by(id: meeting_id)
      return unless meeting.present? && meeting.calendar_event_id.present?
      event_options = {attendees: meeting.get_attendees_for_calendar_event(current_occurrence_time: options[:current_occurrence_time]), description: meeting.get_meeting_description_for_calendar_event, time_zone: meeting.meeting_time_zone}
      event_id = meeting.get_calendar_event_id(options)
      Calendar::GoogleApi.new(meeting.get_scheduling_email).update_calendar_event(event_options, event_id)
    end

    def handle_update_calendar_event(meeting_id)
      meeting = Meeting.find_by(id: meeting_id)
      return unless meeting.present?

      if meeting.calendar_event_id.present?
        options = meeting.get_calendar_event_options(false)
        Calendar::GoogleApi.new(meeting.get_scheduling_email).update_calendar_event(options, meeting.calendar_event_id)
      end
    end

    def send_update_email_for_recurring_meeting_deletion(meeting_id, wob_member_id)
      meeting = Meeting.find_by(id: meeting_id)
      member_responses_hash = {}
      meeting.member_meetings.each { |member_meeting| member_responses_hash[member_meeting.member_id] = member_meeting.attending }
      meeting.send_update_email(member_responses_hash: member_responses_hash, updated_by_member_id: wob_member_id)
    end

    def start_rsvp_sync(notification_time, notification_channel)
      Calendar::GoogleApi.new(notification_channel.scheduling_account.email).perform_rsvp_sync(notification_time, notification_channel)
    end

    # Implements start_rsvp_sync_#{notification_channel_id} for multiple notification channels
    def method_missing(method_name, *args)
      if method_name.to_s =~ START_RSVP_SYNC_METHOD_REGEX
        notification_channel_id = method_name.to_s.split("_").last.to_i
        
        notification_channel = CalendarSyncNotificationChannel.find_by(id: notification_channel_id)
        notification_time = args[0]

        Meeting.start_rsvp_sync(notification_time, notification_channel)
      end
    end

    # checks if there is a delayed job already running to perform rsvp sync.
    def is_rsvp_sync_currently_running?(notification_channel_id)
      Delayed::Job.where("failed_at is null and queue = ? and handler like ?", DjQueues::HIGH_PRIORITY, "%start_rsvp_sync_#{notification_channel_id}%").present?
    end

    def send_update_emails_and_update_calendar_event(meeting_id, updated_meeting_id, options = {})
      meeting = Meeting.find_by(id: meeting_id)
      updated_meeting = Meeting.find_by(id: updated_meeting_id)

      return unless meeting.present? && updated_meeting.present?

      Meeting.handle_update_calendar_event(updated_meeting.id) if updated_meeting.can_be_synced?
      updated_meeting.send_update_email(member_responses_hash: options[:member_responses_hash], updated_by_member_id: options[:updated_by_member_id], send_push_notifications: true)

      if meeting.id != updated_meeting.id && meeting.can_be_synced?
        Meeting.handle_update_calendar_event(meeting.id)
        meeting.send_update_email(member_responses_hash: options[:member_responses_hash], updated_by_member_id: options[:updated_by_member_id])
      end
    end

    def send_rsvp_sync_notification_failure_mail(meeting_id, rsvp_change_user)
      meeting = Meeting.find_by(id: meeting_id)

      return unless meeting.present?

      meeting.get_coparticipants(rsvp_change_user).each do |user|
        ChronusMailer.meeting_rsvp_sync_notification_failure_mail(user, meeting).deliver_now
      end
    end

    def get_meeting_messages_hash(member, meetings)
      meeting_ids = get_non_group_meeting_ids_from_collection(meetings)
      all_messages = get_unread_or_read_messages_hash(member, meeting_ids)
      unread_messages = get_unread_messages_hash(member, meeting_ids)
      return {all: all_messages, unread: unread_messages}
    end

    
    def get_unread_or_read_messages_hash(member, meeting_ids)
      Scrap.where(ref_obj_id: meeting_ids, ref_obj_type: "Meeting").joins(:message_receivers).where("sender_id = ? OR (member_id = ? AND status != ?)", member.id, member.id, AbstractMessageReceiver::Status::DELETED).group("ref_obj_id").distinct.count(:root_id)
    end

    def get_unread_messages_hash(member, meeting_ids)
      Scrap.where(ref_obj_id: meeting_ids, ref_obj_type: "Meeting").joins(:message_receivers).where("member_id = ? AND status = ?", member.id, AbstractMessageReceiver::Status::UNREAD).group("ref_obj_id").distinct.count(:root_id)
    end

    def get_meeting_notes_hash(meetings)
      meeting_ids = meetings.collect{|meeting|meeting[:meeting].id}
      Meeting.where(id: meeting_ids).joins(:private_meeting_notes).group(:id).count
    end

    def get_non_group_meeting_ids_from_collection(meetings)
      meetings.select{|meeting|!meeting[:meeting].group_meeting?}.collect{|meeting|meeting[:meeting].id}
    end

    private

    def handle_rsvp_from_meeting_and_calendar_event(member_meeting, event_rsvp, options = {})
      meeting_rsvp = member_meeting.get_response_object(options[:current_occurrence_time]).attending
      event_rsvp = MemberMeeting::CALENDAR_EVENT_TO_MEETING_RSVP_MAP[event_rsvp]
      if event_rsvp.present? && meeting_rsvp != event_rsvp && event_rsvp != MemberMeeting::ATTENDING::NO_RESPONSE        
        member_meeting.member.mark_attending!(member_meeting.meeting, {:perform_sync_to_calendar => false, :attending => event_rsvp, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR})
      end
    end

    def valid_occurrence?(options, occurrence, start_time, time_now, meeting_req_accepted_time)
      append_to_meeting = !(options[:get_occurrences_between_time] || options[:with_endtime_in] || options[:with_starttime_in] || options[:get_only_upcoming_meetings] || options[:get_only_past_meetings] || options[:with_in_time] || options[:with_accepted_at_in])
      append_to_meeting ||= (options[:get_occurrences_between_time] && (start_time >= options[:start_time] && start_time <= options[:end_time]))
      append_to_meeting ||= (options[:with_endtime_in] && (occurrence.end_time >= options[:start_time] && occurrence.end_time <= options[:end_time]))
      append_to_meeting ||= (options[:with_starttime_in] && (start_time >= options[:start_time] && start_time < options[:end_time]))
      append_to_meeting ||= options[:get_only_upcoming_meetings] && (occurrence.end_time.to_i > time_now)
      append_to_meeting ||= options[:get_only_past_meetings] && (occurrence.end_time.to_i <= time_now)
      append_to_meeting ||= (options[:with_in_time] && (start_time >= options[:start_time] && occurrence.end_time <= options[:end_time]))
      append_to_meeting ||= (options[:with_accepted_at_in] && meeting_req_accepted_time.present? && options[:start_time] <= meeting_req_accepted_time && meeting_req_accepted_time <= options[:end_time])
      append_to_meeting
    end

    def encryptor
      self.encryption_engine ||= EncryptionEngine::DesEde3Cbc.new(CalendarUtils::ENCRYPTION_KEY)
    end

    def get_recurring_event_start_time_ics(event)
      Meeting.parse_occurrence_time(event.dtstart)
    end
  end

  def update_rsvp!(event)
    if event.recurrence_id || event.rrule.present?
      update_recurring_rsvp(event)
    else
      sync_rsvp_with_calendar_event(event)
    end
  end

  def ics_guests_details(user, deleted_meeting = false, options = {})
    user = user.user_in_program(self.program) if user.is_a?(Member)
    if self.can_be_synced?(deleted_meeting)
      rsvp_by_member_id_hash = self.member_meetings.group_by(&:member_id)
      email_profile_question = self.program.organization.email_question
      email_role_questions = self.program.role_questions_for(user.role_names, user: user).where(:profile_question_id => email_profile_question.id)
      users = self.participant_users.select{|guest| email_role_questions.select{|q| q.visible_for?(user, guest)}.present?}
      users.collect{|guest| {:email => guest.email, :name => guest.name, :part_stat => MemberMeeting::MEETING_RSVP_TO_ICS_PARTSTAT_MAP[rsvp_by_member_id_hash[guest.member.id].first.get_response_object(options[:current_occurrence_time]).attending]} }
    else
      self.guests.collect{|guest| {:email => guest.email, :name => guest.name} }
    end
  end

  def not_cancelled
    self.member_meetings.where.not(attending: 0).count > 1
  end

  def can_be_edited_by_member?(member)
    return false  unless member
    user = member.user_in_program(self.program)
    self.active? && self.has_member?(member) && can_be_edited_by_group_member?(user)
  end

  def can_be_deleted_by_member?(member)
    self.owner == member && self.can_be_edited_by_member?(member)
  end

  def location_can_be_set_by_member?(member, current_occurrence_time)
    member_meeting = self.member_meetings.find_by(member_id: member.id)
    !self.recurrent? && member_meeting.present? && member_meeting.get_response_object(current_occurrence_time).accepted? && self.calendar_time_available? && self.can_be_edited_by_member?(member)
  end

  def has_member?(member)
    self.members.include?(member)
  end

  def participant_users
    self.program.users.includes(:member).where(:program_id => self.program.id, :member_id => self.members.pluck(:id))
  end

  def get_coparticipants(user)
    self.participant_users - [user]
  end

  def member_can_send_new_message?(member)
    self.state.nil? && self.has_member?(member) && (self.participant_users.active_or_pending.count > 1)
  end

  def is_valid_occurrence?(current_occurrence_time)
    if self.occurrences.present?
      current_occurrence_time = current_occurrence_time.to_i
      occurrences = self.occurrences.map{|o| o.start_time.to_i}
      return occurrences.include?(current_occurrence_time)
    else
      return false
    end
  end

  def owner_and_owner_user_present?
    owner_member = self.owner
    owner_user = owner_member.user_in_program(self.program) if owner_member.present?
    return owner_member.present? && owner_user.present?
  end

  def get_ics_file_url(user)
    file_path = "/tmp/" + S3Helper.embed_timestamp("#{SecureRandom.hex(3)}_#{TEMP_FILE_NAME}")
    File.write(file_path, generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user))
    S3Helper.transfer(file_path, MEETING_ICS_S3_PREFIX, APP_CONFIG[:chronus_mentor_common_bucket], {content_type: ICS_CONTENT_TYPE, url_expires: 7.days})
  end
  
  def complete!
    self.update_attributes!(:state => State::COMPLETED)
  end
  
  def cancel!
    self.update_attributes!(:state => State::CANCELLED)
  end

  def completed?
    self.state == State::COMPLETED
  end

  def cancelled?
    self.state == State::CANCELLED
  end

  def future_or_group_meeting?(current_occurrence_time)
    return self.group_meeting? || !self.archived?(current_occurrence_time)
  end

  def group_meeting?
    return self.group_id.present?
  end

  def can_display_owner?
    meeting_owner = self.owner
    owner_user = meeting_owner.user_in_program(self.program) if meeting_owner.present?
    return owner_user.present? && self.member_meetings.where(member_id: meeting_owner.id).present? && (!self.group_meeting? || self.group.members.where(id: owner_user.id).present?)
  end

  def can_send_create_email_notification?
    active? && !archived?(schedule.last) && group_id?
  end

  def can_send_update_email_notification?
    active? && (!archived?(schedule.last) || can_be_synced?)
  end

  # All except the owner
  def guests
    self.members - [self.owner]
  end

  def get_user(member)
    if member
      @users ||= {}
      @users[member.id] ||= member.users.find { |user| user.program_id == program_id }
    end
  end

  def owner_user
    @owner_user ||= get_user(owner) if owner
  end

  def guests_users
     self.guests.map{|x| get_user(x)}
  end

  def owned_by?(member)
    self.owner == member
  end

  def archived?(occurrence_time = nil)
    time = occurrence_time.try(:+, self.schedule.duration)
    if self.occurrences.present?
      time ||= (self.occurrences.last.to_time + self.schedule.duration)
    end
    return false if time.nil?
    time < Time.now
  end

  def future?
    !archived?
  end

  # Sets the attendees of the meeting
  # Params:
  # *ids*: An array of member ids.
  def attendee_ids=(ids)
    #FIXME Security hole the member find should be scoped under organization of the meeting owner
    self.members = Member.where(id: ids)
  end

  def start_time_of_the_day
    DateTime.localize(self.start_time, format: :short_time_small) if self.start_time
  end

  def end_time_of_the_day
    DateTime.localize(self.end_time, format: :short_time_small) if self.end_time
  end

  def date
    DateTime.localize(self.start_time, format: :full_display_no_time) if self.start_time
  end

  def duration_in_hours
    (self.schedule.duration * self.occurrences.count)/1.hour
  end

  def duration_in_hours_for_one_occurrences
    (self.schedule.duration)/1.hour
  end

  # This method below will be useful for meetings objects instantiated and not saved yet (i.e. save!)
  def schedulable?(program)
    start_time > (Time.now.utc + program.get_allowed_advance_slot_booking_time.hours)
  end

  def create_meeting_requests(skip_email_notification = false)
    # future_mentor_meeting needs to be modeled as mentor offer
    future_mentor_meeting = mentor_created_meeting && future?
    if !group_id? && !future_mentor_meeting
      MeetingObserver.without_callback(:after_update) do
        program.meeting_requests.create!(student: requesting_student, mentor: requesting_mentor, proposed_slots_details_to_create: proposed_slots_details_to_create,
          show_in_profile: false, meeting: self, status: (mentor_created_meeting ? AbstractRequest::Status::ACCEPTED : AbstractRequest::Status::NOT_ANSWERED), skip_email_notification: skip_email_notification)
      end
    end
  end

  def generate_ics_calendar(is_owner = false, event_type = Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, options = {})
    deleted_meeting = event_type == Meeting::IcsCalendarScenario::CANCEL_EVENT
    ics_event = Meeting.get_ics_event(self, options.merge({deleted_meeting: deleted_meeting}))
    calendar = Meeting.generate_ics_calendar_events(ics_event, event_type, is_owner, {calendar_sync_enabled: self.can_be_synced?(deleted_meeting)})
    calendar.export
  end

  def false_destroy!(skip_observer = false)
    self.update_attributes!(active: false, skip_observer: skip_observer)
  end

  def formatted_duration
    duration = self.schedule.duration
    if duration < 1.hour
      "feature.meetings.content.duration_in_minutes".translate(minutes: ((duration/1.minute).to_i.to_s))
    else
      no_of_hours = duration/1.hour
      no_of_hours = ((no_of_hours == no_of_hours.to_i) ? no_of_hours.to_i : no_of_hours)
      "feature.meetings.content.duration_in_hour_v1".translate(count: no_of_hours)
    end
  end

  def occurrences
    self.schedule.all_occurrences
  end

  def update_schedule
    duration = self.duration || (self.end_time - self.start_time)
    schedule = Schedule.new(self.start_time, :duration => duration)
    schedule.add_recurrence_rule self.build_rule.until(self.repeats_end_date.present? && self.recurrent ? self.repeats_end_date : self.start_time)
    self.schedule = schedule
  end

  def build_rule
    return IceCube::Rule.daily unless self.recurrent

    case self.schedule_rule.to_i
    when Repeats::DAILY
      IceCube::Rule.daily(self.repeat_every.to_i)
    when Repeats::WEEKLY
      rule = IceCube::Rule.weekly(self.repeat_every.to_i)
      if self.repeats_on_week
        self.repeats_on_week.each do |weekday|
          rule.day(Date::DAYNAMES[weekday.to_i].downcase.to_sym)
        end
      end
      rule
    when Repeats::MONTHLY
      if self.repeats_by_month_date == 'true'
        IceCube::Rule.monthly(self.repeat_every.to_i).day_of_month(self.start_time.day)
      else
        IceCube::Rule.monthly(self.repeat_every.to_i).day_of_week(Date::DAYNAMES[self.start_time.wday].downcase.to_sym => [self.start_time.get_week_of_month])
      end
    end
  end

  def update_last_occurence_time(new_until_time)
    schedule = self.schedule
    current_occurrence_time = schedule.previous_occurrence(Meeting.parse_occurrence_time(new_until_time))
    if current_occurrence_time.present?
      rule = schedule.recurrence_rules.first
      rule.until(current_occurrence_time)
      schedule.remove_recurrence_rule(schedule.recurrence_rules.first)
      schedule.add_recurrence_rule(rule)
      schedule.exception_times.each {|et| schedule.remove_exception_time(et) if et > schedule.last }
      self.schedule = schedule
      self.end_time = self.schedule.last.end_time
      self.save!
      return current_occurrence_time
    end
  end

  def add_exception_rule_at(exception_time)
    schedule = self.schedule
    exception_time = Meeting.parse_occurrence_time(exception_time)
    schedule.add_exception_time(exception_time)
    self.schedule = schedule
    self.end_time = self.schedule.last.end_time
    self.save!
    return exception_time
  end

  def update_meeting_time(start_time, duration, options = {})
    old_start_time = self.occurrences.first.start_time
    last_occurrence_time = self.occurrences.last.start_time
    return if ((start_time == old_start_time) && (duration == self.schedule.duration)) && !options[:calendar_time_available] #calendar_time available should be updated to true even the when meeting time is unchanged
    schedule = self.schedule
    schedule.start_time = start_time
    schedule.duration = duration
    self.start_time = start_time
    self.time_zone = options[:meeting_time_zone]
    start_time_delay = self.start_time - old_start_time
    if !(self.recurrent && (last_occurrence_time == last_occurrence_time.end_of_day))
      rule = schedule.recurrence_rules.first
      rule.until((last_occurrence_time + start_time_delay).end_of_day)
      schedule.remove_recurrence_rule(schedule.recurrence_rules.first)
      schedule.add_recurrence_rule(rule)
      schedule.exception_times.each {|et| schedule.remove_exception_time(et) if (schedule.last.blank? || et > schedule.last) }
    end
    if self.recurrent? && self.occurrences.blank?
      schedule.remove_recurrence_rule(schedule.recurrence_rules.first)
      schedule.add_recurrence_rule IceCube::Rule.daily.until(schedule.start_time)
      self.recurrent = false
    end
    self.schedule = schedule
    self.end_time = self.schedule.last.end_time
    self.location = options[:location] if options[:location]
    self.calendar_time_available = options[:calendar_time_available] if options[:calendar_time_available]
    self.skip_rsvp_change_email = options[:skip_rsvp_change_email]
    unless options[:fake_update]
      self.save!
      self.reset_responses(options[:updated_by_member], options[:all_attending])
      self.survey_answers.each { |object| object.increment!(:meeting_occurrence_time, start_time_delay) }
    end
  end

  def update_single_meeting(meeting_params, current_occurrence_time, wob_member)
    self.add_exception_rule_at(current_occurrence_time)
    meeting = self.program.meetings.new(meeting_params)
    meeting.skip_rsvp_change_email = self.skip_rsvp_change_email
    meeting.updated_by_member = self.updated_by_member
    meeting.owner = self.owner
    meeting.time_zone = wob_member.get_valid_time_zone
    meeting.create_ra = false
    meeting.skip_create_calendar_event = true
    meeting.save!
    meeting.append_to_recent_activity_stream(RecentActivityConstants::Type::MEETING_UPDATED)
    current_occurrence_time = Meeting.parse_occurrence_time(current_occurrence_time)
    self.member_meeting_responses.where(meeting_occurrence_time: current_occurrence_time).collect(&:destroy)
    return meeting
  end

  def update_following_meetings(meeting_params, current_occurrence_time, wob_member)
    schedule = self.schedule
    meeting = self.program.meetings.new(meeting_params)
    meeting.skip_rsvp_change_email = self.skip_rsvp_change_email
    meeting.updated_by_member = self.updated_by_member
    meeting.owner = self.owner
    start_time_delay = (meeting.start_time - meeting.start_time.to_datetime.beginning_of_day) - (schedule.start_time - schedule.start_time.to_datetime.beginning_of_day)
    rule = schedule.recurrence_rules.first
    rule.until(schedule.last.start_time + start_time_delay)
    schedule.remove_recurrence_rule(schedule.recurrence_rules.first)
    schedule.add_recurrence_rule(rule)
    schedule.exception_times.each {|et| schedule.remove_exception_time(et) if et > schedule.last }
    schedule.start_time = meeting.start_time
    schedule.duration = meeting.duration
    meeting.schedule = schedule
    meeting.end_time = meeting.schedule.last.end_time
    meeting.create_ra = false
    meeting.time_zone = wob_member.get_valid_time_zone
    meeting.skip_create_calendar_event = true
    meeting.save!
    meeting.append_to_recent_activity_stream(RecentActivityConstants::Type::MEETING_UPDATED)
    self.reload.update_last_occurence_time(current_occurrence_time)
    current_occurrence_time = Meeting.parse_occurrence_time(current_occurrence_time)
    self.member_meeting_responses.where("meeting_occurrence_time >= ?", current_occurrence_time).collect(&:destroy)
    return meeting
  end

  def append_to_recent_activity_stream(ra_action_type)
    return if self.group.blank? && self.guests.blank?
    ra_member = ra_action_type == RecentActivityConstants::Type::MEETING_UPDATED ? self.updated_by_member : self.owner
    additional_params = self.group.present? ? {:target => RecentActivityConstants::Target::ALL} :
      {:target => RecentActivityConstants::Target::USER, :for => self.guests.first}
    RecentActivity.create!(
      {:programs => [self.program],
        :ref_obj => self,
        :action_type => ra_action_type,
        :member => ra_member,
        :message => self.topic
      }.merge(additional_params)
    )
  end

  # Work only after record saved to the database
  def details_updated?(old_attributes)
    self.datetime_updated?(old_attributes) || (self.location.to_s != old_attributes["location"].to_s) || (self.topic != old_attributes["topic"]) || (self.description != old_attributes["description"])
  end

  def datetime_updated?(old_attributes)
    (self.start_time.utc.to_i != old_attributes["start_time"].utc.to_i) || (self.schedule.duration != old_attributes["schedule_duration"])
  end

  # Emails
  def send_create_email
    if can_send_create_email_notification?
      user = self.owner.user_in_program(self.program)
      ics_calendar_attachment = self.generate_ics_calendar(true, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user)
      ChronusMailer.meeting_creation_notification_to_owner(user, self, ics_calendar_attachment).deliver_now
      self.guests_users.each do |user|
        ics_calendar_attachment = self.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user)
        Push::Base.queued_notify(PushNotification::Type::MEETING_CREATED, self, user_id: user.id)
        ChronusMailer.meeting_creation_notification(user, self, ics_calendar_attachment, sender: self.owner).deliver_now
      end
    end
  end

  def send_update_email(options = {})
    if can_send_update_email_notification?
      sender = self.members.find(options.delete(:updated_by_member_id))
      receiving_users = self.program.users.where(member_id: self.members.where.not(id: sender.id).pluck(:id))
      current_occurrence_time = options.delete(:current_occurrence_time)
      options[:sender] = sender

      if self.can_be_synced?
        sender_user = sender.user_in_program(self.program)
        ics_calendar_attachment = self.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: sender_user)
        ChronusMailer.meeting_edit_notification_to_self(sender_user, self, ics_calendar_attachment, current_occurrence_time).deliver_now
      end
      
      receiving_users.each do |user|
        ics_calendar_attachment = self.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CREATE_UPDATE_EVENT, user: user)
        Push::Base.queued_notify(PushNotification::Type::MEETING_UPDATED, self, {user_id: user.id, updated_by_member_id: sender.id}) if options[:send_push_notifications]
        ChronusMailer.meeting_edit_notification(user, self, ics_calendar_attachment, current_occurrence_time, options).deliver_now
      end
    end
  end

  def self.send_destroy_email(meeting_id, current_occurrence_time = nil, following_occurrence_time = nil)
    meeting = Meeting.unscoped.find(meeting_id)

    if meeting.can_be_synced?(true)
      user = meeting.owner_user
      ics_calendar_attachment = meeting.generate_ics_calendar(true, Meeting::IcsCalendarScenario::CANCEL_EVENT, user: user)
      ChronusMailer.meeting_cancellation_notification_to_self(user, meeting, ics_calendar_attachment, current_occurrence_time, following_occurrence_time).deliver_now
    end

    meeting.guests_users.each do |user|
      ics_calendar_attachment = meeting.generate_ics_calendar(false, Meeting::IcsCalendarScenario::CANCEL_EVENT, user: user)
      ChronusMailer.meeting_cancellation_notification(user, meeting, ics_calendar_attachment, current_occurrence_time, following_occurrence_time, sender: meeting.owner).deliver_now
    end
  end

  def first_occurrence?(current_occurrence_time)
    current_occurrence_time = Meeting.parse_occurrence_time(current_occurrence_time)
    current_occurrence_time == self.occurrences.first.to_time
  end

  def occurrence_end_time(current_occurrence_time)
    current_occurrence_time + self.schedule.duration
  end

  def build_recurring_meeting(current_occurrence_time)
    return {current_occurrence_time: current_occurrence_time, :meeting => self}
  end

  def attendees_for_an_occurrence(current_occurrence_time)
    attending_members = []
    self.member_meetings.each do |member_meeting|
      attending_members << member_meeting.member if member_meeting.get_response_object(current_occurrence_time).accepted_or_not_responded?
    end
    attending_members
  end

  def any_attending?(occurrence_time, member_ids)
    member_ids.each do |member_id|
      member_meeting = self.member_meetings.find{|mm| mm.member_id == member_id}
      if member_meeting && member_meeting.get_response_object(occurrence_time).accepted_or_not_responded?
        return true
      end
    end
    return false
  end

  def reset_responses(updated_by_member, all_attending = false)
    self.member_meeting_responses.collect(&:destroy)

    skip_mail_for_calendar_sync = true if self.can_be_synced?
    
    if updated_by_member.present?
      updated_by_member.mark_attending!(self, {skip_rsvp_change_email: skip_rsvp_change_email, skip_mail_for_calendar_sync: skip_mail_for_calendar_sync, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC})
      self.member_meetings.where("member_id != ?", updated_by_member.id).update_all(attending: MemberMeeting::ATTENDING::NO_RESPONSE)
    elsif all_attending
      self.members.each{|member| member.mark_attending!(self, {skip_rsvp_change_email: skip_rsvp_change_email, skip_mail_for_calendar_sync: skip_mail_for_calendar_sync, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC})}
    end
  end

  def mark_meeting_members_attending
    self.members.each do |m|
      m.mark_attending!(self, { skip_rsvp_change_email: skip_rsvp_change_email, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC })
    end
  end

  def get_role_of_user(user)
    if group_id?
      group.memberships.find_by(user_id: user.id).role.name
    else
      (mentee_id == user.member_id) ? RoleConstants::STUDENT_NAME : RoleConstants::MENTOR_NAME
    end
  end

  def accepted?
    meeting_request.nil? || meeting_request.accepted?
  end

  def get_member_meeting_for_role(role_name)
    if role_name == RoleConstants::STUDENT_NAME
      member_meetings.find{|mm| mm.member_id == mentee_id}
    else
      member_meetings.find{|mm| mm.member_id != mentee_id}
    end
  end

  def get_member_for_role(role_name)
    if role_name == RoleConstants::STUDENT_NAME
      members.find{|mm| mm.id == mentee_id}
    else
      members.find{|mm| mm.id != mentee_id}
    end
  end

  def check_start_time_should_be_lesser
    if self.start_time >= self.end_time
      self.errors.add(:meeting, "activerecord.custom_errors.meeting.invalid_time".translate)
    end
  end

  def mentee_should_be_part_of_meeting
    return unless self.mentee_id.present?
    mentee_member = Member.find_by(id: self.mentee_id)
    mentee_user = mentee_member.user_in_program(self.program) if mentee_member.present?

    if mentee_user && mentee_member && !self.has_member?(mentee_member)
      self.errors.add(:meeting, "activerecord.custom_errors.meeting.mentee_should_be_part_of_meeting".translate(meeting: self.program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase, mentee: self.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).term))
    end
  end

  def first_occurrence
    occurrences.first.start_time
  end

  def get_reply_to_token(sender_id, receiver_id)
    member_meetings = self.member_meetings
    sender_token = member_meetings.find_by(member_id: sender_id).try(:api_token)
    receiver_token = member_meetings.find_by(member_id: receiver_id).try(:api_token)
    return sender_token.to_s + "-" + receiver_token.to_s
  end

  def build_meeting_occurrence_response_hash(event_occurrences)
    member_meeting_hash = self.member_meetings.group_by(&:member)
    occurrence_time_response_hash = initialize_occurrence_time_response_hash

    event_occurrences.each do |event_occurrence|
      occurrence_start_time = Meeting.get_recurring_event_start_time(event_occurrence)
      event_occurrence.attendees.each do |attendee|
        event_occurrence_rsvp = get_event_occurrence_rsvp(attendee)
        member = get_member_for_event_attendee(attendee.email, member_meeting_hash)
        next unless event_occurrence_rsvp.present? && member.present?
        member_meeting = member_meeting_hash[member].first
        meeting_occurrence_rsvp = member_meeting.get_meeting_occurrence_rsvp(occurrence_start_time)
        occurrence_time_response_hash[member.id][occurrence_start_time] = event_occurrence_rsvp if meeting_occurrence_rsvp != event_occurrence_rsvp
      end
    end
    occurrence_time_response_hash
  end

  def initialize_occurrence_time_response_hash
    occurrence_time_response_hash = {}
    self.attendees.each do |attendee|
      occurrence_time_response_hash[attendee.id] = {}
    end
    occurrence_time_response_hash
  end

  def get_member_for_event_attendee(attendee_email, member_meeting_hash)
    member_meeting_hash.keys.find{|m| m.email == attendee_email}
  end

  def get_event_occurrence_rsvp(attendee)
    MemberMeeting::CALENDAR_EVENT_TO_MEETING_RSVP_MAP[attendee.response_status]
  end

  def handle_sync_for_recurring_event(occurrence_time_response_hash)
    self.attendees.each do |attendee|
      attendee_occurrences_response_hash = occurrence_time_response_hash[attendee.id]
      occurences_to_sync_size = attendee_occurrences_response_hash.size
      next if occurences_to_sync_size == 0

      if occurences_to_sync_size < MAXIMUM_INDIVIDUAL_OCCURRENCES_TO_SYNC
        # when the number of occurrences are less than 3 we handle each occurrence individually
        attendee_occurrences_response_hash.each do |occurrence_time, response|
          attendee.mark_attending_for_an_occurrence!(self, response, occurrence_time, {perform_sync_to_calendar: false, rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR})
        end
      else
        handle_sync_for_all_occurrences(attendee, attendee_occurrences_response_hash)
      end
    end
  end

  def handle_sync_for_all_occurrences(attendee, attendee_occurrences_response_hash)

    # Algorithm :
    # 1. Initially we get the list of occurrences which needs to be synced in occurrence response hash.
    # 2. We need to check if the number of emails which needs to be sent if we handle the occurrences individually is less than sending an all occurrence update email + sending individual exception emails
    # 3. For that we update the hash with all occurrences times and the responses and iterate over all occurrences to figure out the minimum number of emails we need to send

    response_to_update = get_maximum_occurring_response(attendee_occurrences_response_hash)
    attendee_occurrences_response_original_hash = attendee_occurrences_response_hash.deep_dup

    member_meeting = self.member_meetings.find_by(member_id: attendee.id)
    get_meeting_occurrences_start_times.each do |occurrence_time|
      next if attendee_occurrences_response_hash[occurrence_time].present?
      attendee_occurrences_response_hash[occurrence_time] = member_meeting.get_meeting_occurrence_rsvp(occurrence_time)
    end

    occurrences_to_update, mark_all_occurrences = get_minimum_individual_occurrences_for_rsvp_update(attendee_occurrences_response_original_hash, attendee_occurrences_response_hash, response_to_update)

    skip_mail_for_calendar_sync = false
    if occurrences_to_update.size > MAXIMUM_NUMBER_OF_SYNC_EMAILS
      CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::FOLLOWING_SYNC, {meeting_id: self.id, member_id: attendee.id})
      skip_mail_for_calendar_sync = true
    end
    
    sync_rsvp_for_event_occurrences(occurrences_to_update, member_meeting, attendee, {mark_all_occurrences: mark_all_occurrences, response_to_update: response_to_update, skip_mail_for_calendar_sync: skip_mail_for_calendar_sync})
  end

  def sync_rsvp_for_event_occurrences(occurrences, member_meeting, attendee, options = {})
    if options[:mark_all_occurrences]
      member_meeting.member_meeting_responses.delete_all
      attendee.mark_attending!(self, {:perform_sync_to_calendar => false, :attending => options[:response_to_update], rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR, skip_mail_for_calendar_sync: options[:skip_mail_for_calendar_sync]})
    end
    occurrences.each do |occurrence_time, event_response|
      attendee.mark_attending_for_an_occurrence!(self, event_response, occurrence_time, {perform_sync_to_calendar: false, skip_mail_for_calendar_sync: options[:skip_mail_for_calendar_sync], rsvp_change_source: MemberMeeting::RSVP_CHANGE_SOURCE::CALENDAR})
    end
  end

  def get_meeting_occurrences_start_times
    self.occurrences.collect{|occurrence|Time.zone.parse(occurrence.to_s)}
  end

  def get_maximum_occurring_response(attendee_occurrences_response_hash)
    occurrences_responses = attendee_occurrences_response_hash.values
    occurrences_responses.max_by{|response| occurrences_responses.count(response)}
  end

  def get_minimum_individual_occurrences_for_rsvp_update(original_response_hash, updated_response_hash, response_to_update)
    #This returns the minimum individual occurrences in the app for which rsvp update needs to be done so that calendar and app occurrences rsvp's are in sync
    minimum_individual_occurrences_to_update = original_response_hash
    individual_occurrences = {}
    mark_all_occurrences = false
    updated_response_hash.each do |occurrence_time, event_response|
      individual_occurrences[occurrence_time] = event_response if event_response != response_to_update
    end

    if individual_occurrences.size < minimum_individual_occurrences_to_update.size
      mark_all_occurrences = true
      minimum_individual_occurrences_to_update = individual_occurrences
    end

    return [minimum_individual_occurrences_to_update, mark_all_occurrences]
  end

  def meeting_time_zone
    self.time_zone || TimezoneConstants::DEFAULT_TIMEZONE
  end

  def get_vtimezone_component
    start_time, _end_time = Meeting.get_event_start_and_end_time(self)
    tzid = self.meeting_time_zone
    tz = TZInfo::Timezone.get tzid
    timezone_component = tz.ical_timezone DateTime.parse(DateTime.localize((start_time.to_time - 10.years).utc, format: :ics_full_time))
    return timezone_component.to_ical
  end

  def get_calendar_event_options(is_create=true)
    uid = self.get_calendar_event_uid
    meeting_time_zone = self.meeting_time_zone
    event_options = {
      id: uid,
      start_time: DateTime.localize(self.first_occurrence.in_time_zone(meeting_time_zone), format: :full_date_full_time_cal_sync),
      end_time: DateTime.localize(self.occurrences.first.end_time.in_time_zone(meeting_time_zone), format: :full_date_full_time_cal_sync),
      attendees: self.get_attendees_for_calendar_event,
      topic: self.topic,
      description: self.get_meeting_description_for_calendar_event,
      location: self.location,
      guests_can_see_other_guests: self.guests_can_see_other_guests?,
      sequence: self.ics_sequence,
      scheduling_assistant_email: self.get_scheduling_email,
      time_zone: meeting_time_zone
    }
    event_options.merge!({recurrence: get_recurrence_list(self)}) if self.recurrent?
    return event_options
  end

  def fetch_rrule(options = {})
    if self.recurrent? && !options[:current_occurrence_time].present?
      begin
        ical_schedule = self.schedule.to_ical(true).split('RRULE:').last.split("\nDTEND").first
        rrule = ical_schedule.split("\n").first
        exdates = ical_schedule.split("\n")[1..-1].map{|exdate| exdate.split(":").last}.join(",")
      rescue => e
        CalendarSyncErrorCases.create_error_case(CalendarSyncErrorCases::ScenarioType::RRULE_CREATION, {meeting_id: self.id, error_message: e.message})
        Airbrake.notify("Meeting rrule creation failed for meeting with id #{self.id} Exception: #{e.message}")
      end
    end
    return rrule, exdates
  end

  def guests_can_see_other_guests?
    guests_can_see_other_guests = true
    email_profile_question = self.program.organization.email_question
    users = self.participant_users
    participant_users = self.participant_users
    participant_users.each do |user|
      email_role_questions = self.program.role_questions_for(user.role_names, user: user).where(:profile_question_id => email_profile_question.id)
      users = participant_users.select{|guest| email_role_questions.select{|q| q.visible_for?(user, guest)}.present?}
      if users.count != participant_users.count
        guests_can_see_other_guests = false
        break
      end
    end
    return guests_can_see_other_guests
  end

  def get_calendar_event_uid
    CalendarUtils.get_calendar_event_uid(self)
  end

  def get_calendar_event_id(options = {})
    event_id = self.calendar_event_id
    return event_id unless self.recurrent? && options[:current_occurrence_time].present?
    occurrence_time = DateTime.localize(options[:current_occurrence_time].utc, format: :ics_full_time)
    "#{event_id}_#{occurrence_time}Z"
  end

  def get_meeting_description_for_calendar_event(user = nil)
    details = "".html_safe
    details = "#{'feature.meetings.content.message_description'.translate}:\n#{self.description}\n\n" if self.description.present?
    details += "#{'feature.meetings.content.attendees'.translate}: " + get_attendees_for_meeting_description
    details += self.recurrent ? get_action_links_for_recurrent_meeting_description(user) : get_action_links_for_non_recurrent_meeting_description(user)
    return details
  end

  def get_scheduling_email
    self.scheduling_email
  end

  def set_scheduling_email
    self.update_column(:scheduling_email, SchedulingAccount.active.sample.try(:email))
  end

  def get_attendees_for_meeting_description
    attendee_rsvp_by_member_id = self.member_meetings.select("member_id, attending").group_by(&:member_id)

    attendee_names_string = ""
    self.attendees.each do |attendee|
      next if attendee_rsvp_by_member_id[attendee.id].first.rejected?
      attendee_names_string += "\n#{attendee.name(:name_only => true)}"
    end
    attendee_names_string
  end

  def get_action_links_for_recurrent_meeting_description(user = nil)
    return get_safe_string unless can_be_edited_by_member_for_ics?(user)

    program = self.program
    meetings_link = Rails.application.routes.url_helpers.meetings_url(subdomain: program.organization.subdomain, host: program.organization.domain, root: program.root, group_id: self.group.id, src: EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING_CALANDER)
    action_links = "\n\n#{'feature.meetings.content.view_reschedule_meetings'.translate(meetings: program.term_for(CustomizedTerm::TermType::MEETING_TERM).pluralized_term.term_downcase)}" + "\n#{meetings_link}"
    return action_links
  end

  def get_meeting_edit_and_update_link(occurrence_time, program)
    subdomain = program.organization.subdomain
    host = program.organization.domain
    root = program.root
    meeting_id = self.id
    meeting_link = Rails.application.routes.url_helpers.meeting_url(meeting_id, subdomain: subdomain, host: host, root: root, current_occurrence_time: occurrence_time)
    edit_meeting_link = Rails.application.routes.url_helpers.meeting_url(meeting_id, subdomain: subdomain, host: host, root: root, current_occurrence_time: occurrence_time, open_edit_popup: true)
    return {meeting_link: meeting_link, edit_meeting_link:edit_meeting_link}
  end

  def get_action_links_for_non_recurrent_meeting_description(user = nil)
    meeting_links_hash = get_meeting_edit_and_update_link(self.first_occurrence, self.program)
    action_links = can_be_edited_by_member_for_ics?(user) ? "\n\n#{'feature.meetings.content.reschedule_meeting'.translate(meeting: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase)}" + "\n#{meeting_links_hash[:edit_meeting_link]}" : get_safe_string
    action_links += "\n\n#{'feature.meetings.content.go_to_meeting_area'.translate(meeting: program.term_for(CustomizedTerm::TermType::MEETING_TERM).term_downcase)}" + "\n#{meeting_links_hash[:meeting_link]}"
    return action_links
  end

  def create_calendar_event
    event_options = self.get_calendar_event_options
    event = Calendar::GoogleApi.new(self.get_scheduling_email).insert_calendar_event(event_options)
    self.update_attribute(:calendar_event_id, event.id) if event.try(:id).present?
  end

  def get_attendees_for_calendar_event(options = {})
    calendar_attendees = []
    member_meetings = self.member_meetings.includes([:member, :member_meeting_responses])

    member_meetings.each do |member_meeting|
      response_object = options[:current_occurrence_time].present? ? member_meeting.get_response_object(options[:current_occurrence_time]) : member_meeting
      calendar_attendees << { email: member_meeting.member.email, response_status: MemberMeeting::CALENDAR_EVENT_TO_MEETING_RSVP_MAP.invert[response_object.attending], display_name: member_meeting.member.name}
    end

    calendar_attendees
  end

  def can_be_synced?(deleted_meeting = false)
    APP_CONFIG[:calendar_api_enabled] && self.synchronizable?(deleted_meeting)
  end

  def synchronizable?(deleted_meeting)
    (deleted_meeting || self.active?) && self.calendar_time_available? && self.program.calendar_sync_enabled?
  end

  private

  def can_be_edited_by_group_member?(user)
    group = self.group
    group.blank? || ((group.active? || group.expired?) && (group.has_member?(user) && (!self.program.allow_one_to_many_mentoring? || self.owner_id == user.member_id || group.has_mentor?(user) || user.is_owner_of?(group))))
  end

  def can_be_edited_by_member_for_ics?(user_or_member = nil)
    member = user_or_member && (user_or_member.is_a?(Member) ? user_or_member : user_or_member.member)
    can_be_edited_by_member?(member)
  end

  def update_recurring_rsvp(event)
    return unless self.can_be_synced?
    unless event.dtstart.in?(self.occurrences)
      Airbrake.notify("Event start doesn't match the occurrences")
      return
    end
    occurrences = get_occurrences(event)
    return if occurrences.blank?
    occurrence_time_response_hash = build_meeting_occurrence_response_hash_ics(event, occurrences)
    handle_sync_for_recurring_event(occurrence_time_response_hash)
  end

  def get_occurrences(event)
    occurrences = self.occurrences
    if event.recurrence_id
      [event.dtstart]
    elsif event.dtstart == occurrences.first
      occurrences
    else
      occurrences.select{|occurrence| occurrence >= event.dtstart}
    end
  end

  def sync_rsvp_with_calendar_event(event)
    return unless self.can_be_synced?
    member_member_meeting_hash = self.member_meetings.group_by(&:member)
    members = member_member_meeting_hash.keys

    event.attendee.each do |attendee|
      member = members.find{|m| m.email.downcase == attendee.to.try(:downcase)}
      next if member.nil?
      member_meeting = member_member_meeting_hash[member].first
      member_meeting.handle_rsvp_from_meeting_and_calendar_event(attendee.ical_params["partstat"][0])
    end
  end

  def build_meeting_occurrence_response_hash_ics(event_occurrence, occurrences)
    member_meeting_hash = self.member_meetings.group_by(&:member)
    occurrence_time_response_hash = initialize_occurrence_time_response_hash

    occurrences.each do |occurrence_start_time|
      event_occurrence.attendee.each do |attendee|
        event_occurrence_rsvp = get_event_occurrence_rsvp_ics(attendee)
        member = get_member_for_event_attendee(attendee.to, member_meeting_hash)
        next unless event_occurrence_rsvp.present? && member.present?
        member_meeting = member_meeting_hash[member].first
        meeting_occurrence_rsvp = member_meeting.get_meeting_occurrence_rsvp(occurrence_start_time)
        occurrence_time_response_hash[member.id][occurrence_start_time] = event_occurrence_rsvp if meeting_occurrence_rsvp != event_occurrence_rsvp
      end
    end
    occurrence_time_response_hash
  end

  def get_event_occurrence_rsvp_ics(attendee)
    MemberMeeting::CALENDAR_EVENT_TO_MEETING_RSVP_MAP_ICS[attendee.ical_params["partstat"][0]]
  end

  def get_recurrence_list(meeting)
    rrule, exdates = meeting.fetch_rrule
    recurrence_list = ["RRULE:#{rrule}"]
    recurrence_list << "EXDATE:#{exdates}" if exdates.present?
    recurrence_list
  end

end
