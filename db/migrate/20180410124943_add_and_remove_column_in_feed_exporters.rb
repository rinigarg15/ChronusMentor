class AddAndRemoveColumnInFeedExporters < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :feed_exporters do |t|
        t.add_column :sftp_account_name, "varchar(191)"
        t.remove_column :mime_type
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :feed_exporters do |t|
        t.add_column :mime_type, "int(11) DEFAULT '0'"
        t.remove_column :sftp_account_name
      end
    end
  end
end
