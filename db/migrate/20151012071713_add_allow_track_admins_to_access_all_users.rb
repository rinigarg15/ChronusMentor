class AddAllowTrackAdminsToAccessAllUsers< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :allow_track_admins_to_access_all_users, :boolean, :default => false
  end

  def down
    remove_column :programs, :allow_track_admins_to_access_all_users
  end
end
