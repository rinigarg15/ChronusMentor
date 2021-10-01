class CreateSecuritySettingForOrganization< ActiveRecord::Migration[4.2]
  def up
    create_table :security_settings do |t|
      t.boolean    :can_contain_login_name, :default => true
      t.integer    :password_expiration_frequency, :default => Organization::DISABLE_PASSWORD_AUTO_EXPIRY
      t.string     :email_domain
      t.float      :auto_reactivate_account, :default => 24
      t.boolean    :reactivation_email_enabled, :default => true
      t.belongs_to :program, :null => false
      t.timestamps null: false
    end
    add_index :security_settings, :program_id   

    ActiveRecord::Base.transaction do
      Organization.active.each do |org|
        puts "Populating default security setting for #{org.name}...."
        org.create_default_security_setting!
      end
    end
  end

  def down
    drop_table :security_settings
    remove_index :security_settings, [:program_id]
  end
end
