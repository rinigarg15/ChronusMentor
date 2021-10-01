class AddIndexForSourceAuditKeyColumn< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :members do |m|
        m.add_index :source_audit_key
      end
      Lhm.change_table :ckeditor_assets do |m|
        m.add_index :source_audit_key
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :members do |m|
        m.remove_index :source_audit_key
      end
      Lhm.change_table :ckeditor_assets do |m|
        m.remove_index :source_audit_key
      end
    end
  end
end
