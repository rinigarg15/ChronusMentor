class CreateProgramEvents< ActiveRecord::Migration[4.2]
 def change
    create_table :program_events do |t|
      t.string :title
      t.text :description
      t.string :location
      t.datetime :start_time
      t.datetime :end_time
      t.integer :status, :default => 0
      t.belongs_to :program
      t.belongs_to :user
      t.timestamps null: false
    end
    add_index :program_events, :program_id
    if Feature.count > 0
      Feature.create_default_features
    end  
  end
end
