class AddReminderSentTimeToMentorRequest< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_requests, :reminder_sent_time, :datetime, :default => nil
  end
end
