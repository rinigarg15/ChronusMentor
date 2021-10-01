class AddRefObjToProfileAnswers< ActiveRecord::Migration[4.2]
  def change
    add_column :profile_answers, :ref_obj_id, :integer, :null => false
    add_column :profile_answers, :ref_obj_type, :string, limit: UTF8MB4_VARCHAR_LIMIT, :null => false
  end
end
