class AddRememberMeToSecuritySettings< ActiveRecord::Migration[4.2]
  def change
  	add_column :security_settings, :can_show_remember_me, :boolean, default: true
  end
end
