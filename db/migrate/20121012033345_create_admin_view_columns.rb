class CreateAdminViewColumns< ActiveRecord::Migration[4.2]
  def change
    create_table :admin_view_columns do |t|
      t.belongs_to :admin_view
      t.belongs_to :profile_question
      t.text :column_key
      t.integer :position
      t.timestamps null: false
    end

    add_index :admin_view_columns, :admin_view_id
    add_index :admin_view_columns, :profile_question_id
  end
end
