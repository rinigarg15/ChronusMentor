class AddMentorRequestIdCalendarTimeToMeetings< ActiveRecord::Migration[4.2]
  def change
    add_column :meetings, :meeting_request_id, :integer
    add_column :meetings, :calendar_time_available, :boolean, default: true
    
    add_index :meetings, :meeting_request_id
  end
end
