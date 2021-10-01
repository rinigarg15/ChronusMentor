class AddColumnRejectionTypeToAbstractRequest< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :mentor_requests do |r|
        r.add_column :rejection_type, "int(11)"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :mentor_requests do |r|
        r.remove_column :rejection_type
      end
    end
  end
end
