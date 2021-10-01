class AddTimestampsToMobileDevices< ActiveRecord::Migration[4.2]
  def up
    change_table :mobile_devices do |t|
      t.timestamps null: false
    end
  end

  def down
    remove_column :mobile_devices, :created_at
    remove_column :mobile_devices, :updated_at
  end
end
