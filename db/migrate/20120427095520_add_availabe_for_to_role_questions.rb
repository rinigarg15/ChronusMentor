class AddAvailabeForToRoleQuestions< ActiveRecord::Migration[4.2]
  def change
    add_column :role_questions, :available_for, :integer, :default => RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
  end
end
