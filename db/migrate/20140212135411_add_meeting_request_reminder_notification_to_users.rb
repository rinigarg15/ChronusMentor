class AddMeetingRequestReminderNotificationToUsers< ActiveRecord::Migration[4.2]
  def change
    add_column :users, :needs_meeting_request_reminder, :boolean, :default => true
  end
end