class AddMobileAuthTokenToMobileDevices< ActiveRecord::Migration[4.2]
  def up
    # moving mobile_auth_token from members table to mobile_devices table.
    remove_column :members, :mobile_auth_token

    add_column :mobile_devices, :mobile_auth_token, :text
    add_column :mobile_devices, :badge_count, :integer, :default => 0

    # existing records should be deleted as that don't have mobile_auth_token for authentication.
    MobileDevice.destroy_all
  end

  def down
    remove_column :mobile_devices, :mobile_auth_token
    remove_column :mobile_devices, :badge_count
  end
end
