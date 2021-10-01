class RemoveLastNotifiedTimeFromMember< ActiveRecord::Migration[4.2]
  def up
    remove_column :members, :last_notified_time
  end

  def down
    add_column :members, :last_notified_time, :datetime
  end
end
