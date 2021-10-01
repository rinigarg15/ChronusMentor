class AddLinkedinKeysToOrganization< ActiveRecord::Migration[4.2]
  def up
    add_column :security_settings, :linkedin_token, :string
    add_column :security_settings, :linkedin_secret, :string
  end

  def down
    remove_column :security_settings, :linkedin_token
    remove_column :security_settings, :linkedin_secret
  end
end
