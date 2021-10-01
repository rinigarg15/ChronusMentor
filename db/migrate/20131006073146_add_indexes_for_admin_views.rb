class AddIndexesForAdminViews< ActiveRecord::Migration[4.2]
  def up
    add_index :admin_views, :program_id
  end

  def down
    remove_index :admin_views, :program_id
  end
end
