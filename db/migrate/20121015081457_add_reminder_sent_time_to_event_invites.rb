class AddReminderSentTimeToEventInvites< ActiveRecord::Migration[4.2]
  def change
  	add_column :event_invites, :reminder_sent_time, :datetime
  end
end
