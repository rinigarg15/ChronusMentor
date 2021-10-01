class AddApiKeyMailboxIdToContactAdminSetting< ActiveRecord::Migration[4.2]
  def up
    add_column :contact_admin_settings, :external_help_desk_email, :string
    add_column :contact_admin_settings, :api_key, :string
    add_column :contact_admin_settings, :mailbox_id, :string
  end

  def down
    remove_column :contact_admin_settings, :external_help_desk_email, :string
    remove_column :contact_admin_settings, :api_key, :string
    remove_column :contact_admin_settings, :mailbox_id, :string
  end
end