class CreateUserActivities< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :user_activities do |t|
        t.string :activity
        t.datetime :happened_at

        t.integer :member_id
        t.integer :user_id
        t.integer :organization_id
        t.integer :program_id

        t.string :roles
        t.string :current_connection_status
        t.string :past_connection_status
        t.datetime :join_date

        t.integer :mentor_request_style
        t.string :program_url
        t.string :account_name

        t.string :browser_name
        t.string :platform_name
        t.string :device_name

        t.string :context_place
        t.string :context_object
        t.string :source_audit_key, limit: UTF8MB4_VARCHAR_LIMIT
      end

      Lhm.change_table :user_activities do |t|
        t.add_index :activity
        t.add_index :happened_at
        t.add_index :member_id
        t.add_index :organization_id
        t.add_index :user_id
        t.add_index :program_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :user_activities
    end
  end
end
