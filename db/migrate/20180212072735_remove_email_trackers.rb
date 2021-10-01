class RemoveEmailTrackers < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      drop_table :email_trackers
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      create_table :email_trackers do |t|
        t.string :class_name, null: false
        t.integer :content_id
        t.integer :user_id
        t.integer :program_id
        t.datetime :opened_at
        t.string SOURCE_AUDIT_KEY, limit: UTF8MB4_VARCHAR_LIMIT
        t.string :type, null: false
        t.timestamps null: false
      end
    end
  end
end