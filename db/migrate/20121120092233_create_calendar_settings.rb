class CreateCalendarSettings< ActiveRecord::Migration[4.2]
  def change
    create_table :calendar_settings do |t|
      t.integer :slot_time_in_minutes
      t.belongs_to :program, :null => false
      t.timestamps null: false
    end
    
    add_index :calendar_settings, :program_id
    
  end
end
