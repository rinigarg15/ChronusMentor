class AddIndexForSourceAuditKeyColumns< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table AbstractMessage.table_name do |t|
        t.add_index :source_audit_key
      end

      Lhm.change_table CampaignManagement::CampaignEmail.table_name do |t|
        t.add_index :source_audit_key
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table AbstractMessage.table_name do |t|
        t.remove_index :source_audit_key
      end

      Lhm.change_table CampaignManagement::CampaignEmail.table_name do |t|
        t.remove_index :source_audit_key
      end
    end
  end
end
