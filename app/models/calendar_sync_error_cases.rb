class CalendarSyncErrorCases < ActiveRecord::Base

  serialize :details

  module ScenarioType
  	RSVP_SYNC = "sync"
  	EVENT_CREATE = "event_create"
  	EVENT_DELETE = "event_delete"
  	EVENT_UPDATE = "event_update"
  	FOLLOWING_SYNC = "following_sync"
    RRULE_CREATION = "rrule_creation"
    FETCH_RECURRENT_ID = "fetch_recurrent_id"

  	def self.all
  	  [RSVP_SYNC, EVENT_CREATE, EVENT_DELETE, EVENT_UPDATE, FOLLOWING_SYNC, RRULE_CREATION, FETCH_RECURRENT_ID]
  	end
  end

  # Scenario wise "Details" column hash keys
  # RSVP_SYNC - sync_notification_time, error_message
  # EVENT_CREATE - full options passed to create method along with error message
  # EVENT_DELETE - event_id, error_message
  # EVENT_UPDATE - full options passed to update method along with event_id and error message
  # FOLLOWING_SYNC - meeting_id, member_id
  # RRULE_CREATION - meeting_id, error_message

  validates :details, presence: true
  validates_inclusion_of :scenario, :in => ScenarioType.all


  def self.create_error_case(scenario_type, options)
  	CalendarSyncErrorCases.create!(scenario: scenario_type, details: options)
  end
end