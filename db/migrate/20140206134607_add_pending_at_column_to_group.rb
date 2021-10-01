class AddPendingAtColumnToGroup< ActiveRecord::Migration[4.2]
  def up
    add_column :groups, :pending_at, :datetime
  end

  def down
    remove_column :groups, :pending_at, :datetime
  end
end
