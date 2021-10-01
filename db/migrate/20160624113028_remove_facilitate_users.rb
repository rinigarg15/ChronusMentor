class RemoveFacilitateUsers< ActiveRecord::Migration[4.2]
  def up
    drop_table :facilitate_users
    drop_table :facilitate_user_translations
    Feature.where(name: "facilitate_users").each do |feature|
      feature.destroy
    end
  end

  def down
    create_table :facilitate_users do |t|
      t.text :subject
      t.text :message
      t.integer :program_id
      t.integer :admin_view_id
      t.boolean :enabled, default: true
      t.string :send_type
      t.integer :send_frequency
      t.timestamps null: false
    end
    add_index :facilitate_users, :program_id
    add_index :facilitate_users, :admin_view_id
    create_table :facilitate_user_translations do |t|
      t.text :subject
      t.text :message
      t.integer :facilitate_user_id
      t.string :locale
      t.timestamps null: false
    end
    add_index :facilitate_user_translations, :locale
    add_index :facilitate_user_translations, :facilitate_user_id
  end
end
