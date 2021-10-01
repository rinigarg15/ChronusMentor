class ChangeColumnOrganizationLanguageEnabledFromBoolenToInteger < ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table OrganizationLanguage.table_name do |t|
        t.change_column :enabled, "int(11) DEFAULT 0"
      end
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      OrganizationLanguage.unscoped.where(enabled: 1).update_all(enabled: OrganizationLanguage::EnabledFor::ALL)
      OrganizationLanguage.unscoped.where(enabled: 0).update_all(enabled: OrganizationLanguage::EnabledFor::ADMIN)
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table OrganizationLanguage.table_name do |t|
        t.change_column :enabled, "tinyint(1) DEFAULT 0"
      end
    end
  end
end
