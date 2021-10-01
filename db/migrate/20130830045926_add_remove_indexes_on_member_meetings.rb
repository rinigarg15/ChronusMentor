class AddRemoveIndexesOnMemberMeetings< ActiveRecord::Migration[4.2]
  def up
    # The index key - index_member_meetings_on_member_id_and_meeting_id is 
    # duplicated for two columns in the member_meetings table.
    # So, removing and adding unique keys for the columns again
    remove_index :member_meetings, [:member_id, :meeting_id]
    remove_index :member_meetings, :attending
    add_index :member_meetings, :meeting_id
    add_index :member_meetings, :member_id
  end

  def down
    remove_index :member_meetings, :member_id
    remove_index :member_meetings, :meeting_id
    add_index :member_meetings, :attending
    add_index :member_meetings, [:member_id, :meeting_id]
  end
end
