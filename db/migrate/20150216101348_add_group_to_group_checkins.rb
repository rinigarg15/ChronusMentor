class AddGroupToGroupCheckins< ActiveRecord::Migration[4.2]
  def up
    add_column :group_checkins, :group_id, :integer
    add_index :group_checkins, :group_id
  end

  def down
    remove_column :group_checkins, :group_id
  end
end
