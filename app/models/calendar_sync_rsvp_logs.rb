class CalendarSyncRsvpLogs < ActiveRecord::Base

  serialize :rsvp_details

  validates :event_id, :notification_id, presence: true

  def self.create_rsvp_sync_log(calendar_events)
    notification_id = CalendarSyncRsvpLogs.last.present? ? CalendarSyncRsvpLogs.last.notification_id + 1 : 1
    calendar_events.each do |event|
      rsvp_hash = {}
      if event.attendees.present?
        event.attendees.each do |attendee|
          rsvp_hash[attendee.email] = attendee.response_status
        end
      end
      CalendarSyncRsvpLogs.create!(notification_id: notification_id, event_id: event.id, recurring_event_id: event.recurring_event_id, rsvp_details: rsvp_hash)
    end
  end
end