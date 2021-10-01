class AddLastNotifiedTimeToMembers< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :last_notified_time, :datetime
  end
end
