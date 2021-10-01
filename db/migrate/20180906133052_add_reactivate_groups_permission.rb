class AddReactivateGroupsPermission < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Permission.count > 0
        Permission.create_default_permissions
      end
    end
  end

  def down
    # do nothing
  end
end
