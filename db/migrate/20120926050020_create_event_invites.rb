class CreateEventInvites< ActiveRecord::Migration[4.2]
  def change
  	create_table :event_invites do |t|
      t.integer :status
      t.boolean :reminder
      t.belongs_to :program_event
      t.belongs_to :user
      t.timestamps null: false
    end
    add_index :event_invites, :user_id
    add_index :event_invites, :program_event_id
  end
end
