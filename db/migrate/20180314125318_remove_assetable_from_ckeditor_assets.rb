class RemoveAssetableFromCkeditorAssets < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table "ckeditor_assets" do |t|
        t.remove_column :assetable_id
        t.remove_column :assetable_type
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table "ckeditor_assets" do |t|
        t.add_column :assetable_id, "int(11)"
        t.add_column :assetable_type, "varchar(30)"

        t.remove_index :type
        t.add_index [:assetable_type, :assetable_id], "fk_assetable"
        t.add_index [:assetable_type, :type, :assetable_id], "idx_assetable_type"
      end
    end
  end
end