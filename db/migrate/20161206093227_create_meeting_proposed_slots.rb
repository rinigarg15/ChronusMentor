class CreateMeetingProposedSlots< ActiveRecord::Migration[4.2]
  def change
    create_table :meeting_proposed_slots do |t|
      t.belongs_to :meeting_request, :null => false
      t.datetime   :start_time
      t.datetime   :end_time
      t.text       :location
      t.integer    :state, :default => 0
      t.integer    :proposer_id
      t.timestamps null: false
    end
    add_index :meeting_proposed_slots, :meeting_request_id
  end
end