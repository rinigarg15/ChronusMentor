class AddProjectRequestRelatedFieldsToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :needs_project_request_reminder, :boolean, default: false
    add_column :programs, :project_request_reminder_duration, :integer, default: 3
  end
end