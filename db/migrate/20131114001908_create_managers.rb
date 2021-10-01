class CreateManagers< ActiveRecord::Migration[4.2]
  def change
    create_table :managers do |t|
      t.string :first_name
      t.string :last_name
      t.string :email, limit: UTF8MB4_VARCHAR_LIMIT
      t.integer :profile_answer_id
      t.timestamps null: false
    end
    add_index :managers, :profile_answer_id
  end
end
