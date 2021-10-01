class AddScheduleToMeetings< ActiveRecord::Migration[4.2]
  def change
    add_column :meetings, :schedule, :text
  end
end
