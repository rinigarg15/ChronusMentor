class CreateTableMobileDevices< ActiveRecord::Migration[4.2]
  def change
    create_table :mobile_devices do |t|
      t.references :member
      t.text :device_token
      t.string SOURCE_AUDIT_KEY.to_sym, :limit => UTF8MB4_VARCHAR_LIMIT
    end
    add_index :mobile_devices, :member_id
  end
end
