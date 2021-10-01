class ChangeDefaultValueOfPrivateInRoleQuestions< ActiveRecord::Migration[4.2]
  def up
    change_column :role_questions, :private, :integer, :default => 1
  end

  def down
    change_column :role_questions, :private, :integer, :default => 31
  end
end
