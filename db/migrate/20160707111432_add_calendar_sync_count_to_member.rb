class AddCalendarSyncCountToMember< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :calendar_sync_count, :integer, :default => 0
  end
end
