class CreateAdminViewUserCaches < ActiveRecord::Migration[4.2]
  TEXT_BYTES = 1_073_741_823
  def self.up
    ChronusMigrate.ddl_migration do
      create_table :admin_view_user_caches do |t|
        t.references :admin_view, index: true
        t.text       :user_ids, limit: TEXT_BYTES
        t.datetime   :last_cached_at
        t.timestamps null: false
      end
    end
  end

  def self.down
    ChronusMigrate.ddl_migration do
      drop_table :admin_view_user_caches
    end
  end
end