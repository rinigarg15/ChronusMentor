class AddIndexesOnProfileAnswers< ActiveRecord::Migration[4.2]
  def up
    add_index :profile_answers, :ref_obj_type
    add_index :profile_answers, :ref_obj_id
    add_index :profile_answers, [:ref_obj_type, :profile_question_id]
  end

  def down
    remove_index :profile_answers, :ref_obj_type
    remove_index :profile_answers, :ref_obj_id
    remove_index :profile_answers, [:ref_obj_type, :profile_question_id]
  end
end
