class CreateChrRakeTasks< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :chr_rake_tasks do |t|
        t.string :name
        t.integer :status, :default => ChrRakeTasks::Status::PENDING
        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :chr_rake_tasks
    end
  end
end