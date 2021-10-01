class AddSanitizationVersionToSecuritySetting< ActiveRecord::Migration[4.2]
  def up
    change_table :security_settings do |t|
      t.string :sanitization_version, :default => "v2"
    end
    SecuritySetting.update_all ["sanitization_version = ?", "v1"]
  end
 
  def down
    remove_column :security_settings, :sanitization_version
  end
end