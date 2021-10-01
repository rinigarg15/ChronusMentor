class AddRoleNameToSurveys< ActiveRecord::Migration[4.2]
  def up
    add_column :surveys, :role_name, :string, limit: UTF8MB4_VARCHAR_LIMIT
    add_index :surveys, :role_name
    Program.find_each do |program|
      Program.create_default_meeting_feedback_surveys(program.id, true)
    end
  end

  def down
    remove_column :surveys, :role_name
    remove_index :surveys, :role_name
  end
end
