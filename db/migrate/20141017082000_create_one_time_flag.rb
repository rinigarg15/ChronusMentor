class CreateOneTimeFlag< ActiveRecord::Migration[4.2]
  def change
    create_table :one_time_flags do |t|
      t.belongs_to :user, :null => false
      t.text :message_tag
      t.timestamps null: false
    end
    add_index :one_time_flags, :user_id
  end
end
