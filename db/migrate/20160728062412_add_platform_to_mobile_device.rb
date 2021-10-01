class AddPlatformToMobileDevice< ActiveRecord::Migration[4.2]
  def change
    add_column :mobile_devices, :platform, :integer
  end
end
