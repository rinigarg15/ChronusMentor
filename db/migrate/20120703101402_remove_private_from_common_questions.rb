class RemovePrivateFromCommonQuestions< ActiveRecord::Migration[4.2]
  def up
    remove_column :profile_answers, :member_id
    remove_column :common_questions, :private
    remove_column :common_questions, :filterable
    remove_column :common_questions, :matchable
  end

  def down
    add_column :profile_answers, :member_id, :integer
    add_column :common_questions, :private, :boolean, :default => false
    add_column :common_questions, :filterable, :boolean, :default => true
    add_column :common_questions, :matchable, :tinyint, :default => false, :null => false
  end
end
