class MoveSecurityRelatedToSecuritySettings< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      add_column :security_settings, :login_expiry_period, :integer, :default => 120
      add_column :security_settings, :maximum_login_attempts, :integer, :default => Organization::DISABLE_MAXIMUM_LOGIN_ATTEMPTS

      Organization.active.includes(:security_setting).each do |org|
        security_setting = org.security_setting
        security_setting.login_expiry_period = org.login_expiry_period
        security_setting.maximum_login_attempts = org.maximum_login_attempts
        security_setting.save!
        puts "#{org.name}'s columns migrated successfully..."
      end

      remove_column :programs, :login_expiry_period
      remove_column :programs, :maximum_login_attempts
    end
  end

  def down
    add_column :programs, :login_expiry_period, :integer, :default => 120
    add_column :programs, :maximum_login_attempts, :integer, :default => Organization::DISABLE_MAXIMUM_LOGIN_ATTEMPTS
    remove_column :security_settings, :login_expiry_period
    remove_column :security_settings, :maximum_login_attempts  
  end
end
