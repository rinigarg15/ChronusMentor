class AddParentIdToMeetings< ActiveRecord::Migration[4.2]
  def change
    add_column :meetings, :parent_id, :integer
  end
end
