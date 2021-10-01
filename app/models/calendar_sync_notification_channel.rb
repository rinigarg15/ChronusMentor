class CalendarSyncNotificationChannel < ActiveRecord::Base

  belongs_to :scheduling_account

  validates :channel_id, :resource_id, :expiration_time, presence: true
  validates_length_of :channel_id, :maximum => 64
end