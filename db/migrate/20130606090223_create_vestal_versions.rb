class CreateVestalVersions< ActiveRecord::Migration[4.2]
  def self.up
    create_table :versions do |t|
      t.belongs_to :versioned, :polymorphic => { limit: UTF8MB4_VARCHAR_LIMIT }
      t.belongs_to :user, :polymorphic => { limit: UTF8MB4_VARCHAR_LIMIT }
      t.string  :user_name, limit: UTF8MB4_VARCHAR_LIMIT
      t.text    :modifications
      t.integer :number
      t.integer :reverted_from
      t.string  :version_tag, limit: UTF8MB4_VARCHAR_LIMIT

      t.timestamps null: false
    end

    change_table :versions do |t|
      t.index [:versioned_id, :versioned_type]
      t.index [:user_id, :user_type]
      t.index :user_name
      t.index :number
      t.index :version_tag
      t.index :created_at
    end
  end

  def self.down
    drop_table :versions
  end
end
