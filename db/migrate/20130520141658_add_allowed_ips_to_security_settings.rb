class AddAllowedIpsToSecuritySettings< ActiveRecord::Migration[4.2]
  def change
  	add_column :security_settings, :allowed_ips, :text
  end
end
