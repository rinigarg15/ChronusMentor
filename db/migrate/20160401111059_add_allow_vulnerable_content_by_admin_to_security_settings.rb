class AddAllowVulnerableContentByAdminToSecuritySettings< ActiveRecord::Migration[4.2]
  def change
    add_column :security_settings, :allow_vulnerable_content_by_admin, :boolean, default: true
  end
end
