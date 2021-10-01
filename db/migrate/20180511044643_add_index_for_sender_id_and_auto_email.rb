class AddIndexForSenderIdAndAutoEmail < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :messages do |t|
        t.add_index [:sender_id, :auto_email]
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :messages do |t|
        t.remove_index [:sender_id, :auto_email]
      end
    end
  end
end
