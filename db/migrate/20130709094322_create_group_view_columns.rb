class CreateGroupViewColumns< ActiveRecord::Migration[4.2]
  def change
    create_table :group_view_columns do |t|
      t.belongs_to :group_view
      t.belongs_to :profile_question
      t.text :column_key
      t.integer :position
      t.integer :connection_question_id
      t.integer :ref_obj_type
      t.integer :for_role, :default => 0
      t.timestamps null: false
    end

    add_index :group_view_columns, :group_view_id
    add_index :group_view_columns, :profile_question_id
    add_index :group_view_columns, :connection_question_id
  end
end
