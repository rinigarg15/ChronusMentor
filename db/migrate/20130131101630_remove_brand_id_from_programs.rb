class RemoveBrandIdFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :brand_id
    drop_table :brands
  end

  def down
    create_table :brands do |t|
      t.string   "label",          :null => false
      t.string   "url",            :null => false
      t.string   "delivery_email", :null => false
      t.string   "reply_to_email"
      t.string   "feedback_email", :null => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "favicon"
    end
    add_column :programs, :brand_id, :integer
  end
end
