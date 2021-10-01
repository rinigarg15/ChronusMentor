class RemoveExternalHelpDeskFieldsFromContactAdminSettings < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table "contact_admin_settings" do |t|
        t.remove_column :external_help_desk_email
        t.remove_column :api_key
        t.remove_column :mailbox_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table "contact_admin_settings" do |t|
        t.add_column :external_help_desk_email, "VARCHAR(255)"
        t.add_column :api_key, "VARCHAR(255)"
        t.add_column :mailbox_id, "VARCHAR(255)"
      end
    end
  end
end