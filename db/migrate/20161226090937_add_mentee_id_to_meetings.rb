class AddMenteeIdToMeetings< ActiveRecord::Migration[4.2]
  def change
    add_column :meetings, :mentee_id, :integer
    add_index :meetings, :mentee_id
  end
end
