class RemoveUserContacts< ActiveRecord::Migration[4.2]
  def up
    drop_table :user_contacts
  end

  def down
    create_table :user_contacts do |t|
      t.integer  "user_id"
      t.string   "name"
      t.string   "email",      :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    add_index "user_contacts", ["user_id"], :name => "index_user_contacts_on_user_id"
  end
end
