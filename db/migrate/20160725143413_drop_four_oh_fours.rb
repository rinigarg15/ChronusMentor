class DropFourOhFours< ActiveRecord::Migration[4.2]
  def up
    drop_table :four_oh_fours
  end

  def down
    create_table "four_oh_fours", :force => true do |t|
      t.string   "host"
      t.string   "path"
      t.string   "referer"
      t.string   "ip"
      t.text     "user_agent"
      t.integer  "count",      :default => 0
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  end
end
