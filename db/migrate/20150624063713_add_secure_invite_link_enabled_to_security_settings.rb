class AddSecureInviteLinkEnabledToSecuritySettings< ActiveRecord::Migration[4.2]
  def change
  	add_column :security_settings, :secure_invite_link_enabled, :boolean, default: true
  end
end