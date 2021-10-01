class AddAllowCreateMeetingForMentorToCalendar< ActiveRecord::Migration[4.2]
  def change
    add_column :calendar_settings, :allow_create_meeting_for_mentor, :boolean, :default => false
  end
end
