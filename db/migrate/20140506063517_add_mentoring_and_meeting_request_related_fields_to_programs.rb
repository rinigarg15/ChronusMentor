class AddMentoringAndMeetingRequestRelatedFieldsToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :needs_meeting_request_reminder, :boolean, default: false
    add_column :programs, :meeting_request_reminder_duration, :integer, default: 3
    add_column :programs, :needs_mentoring_request_reminder, :boolean, default: false
    add_column :programs, :mentoring_request_reminder_duration, :integer, default: 3
    remove_column :users, :needs_meeting_request_reminder
  end
end
