class ChangeChrRakeTasksNameDataType< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :chr_rake_tasks do |m|
        m.change_column(:name, "text")
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :chr_rake_tasks do |m|
        m.change_column(:name, "VARCHAR(255)")
      end
    end
  end
end
