class CreateUserSettings< ActiveRecord::Migration[4.2]
  def change
    create_table :user_settings do |t|
      t.belongs_to :user
      t.integer :max_capacity_hours
      t.integer :max_capacity_frequency

      t.timestamps null: false
    end
    add_index "user_settings", ["user_id"]
  end
end
