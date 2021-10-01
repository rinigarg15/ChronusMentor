class CreateSchedulingAccounts< ActiveRecord::Migration[4.2]
  def change
    ChronusMigrate.ddl_migration do
      create_table :scheduling_accounts do |t|
        t.string :email, null: false
        t.integer :status
        t.timestamps null: false
      end
    end
  end
end