class AddIndexForProfileAnswers< ActiveRecord::Migration[4.2]
  def up
    add_index :profile_answers, [:ref_obj_type, :ref_obj_id]
    remove_index :profile_answers, [:member_id,:profile_question_id]
  end

  def down
    add_index :profile_answers, [:member_id,:profile_question_id]
    remove_index :profile_answers, [:ref_obj_type, :ref_obj_id]
  end
end
