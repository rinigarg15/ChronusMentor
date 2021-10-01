class CreateFacilitateUsers< ActiveRecord::Migration[4.2]
  def up
    create_table :facilitate_users do |t|
      t.text :subject
      t.text :message
      t.belongs_to :program
      t.belongs_to :admin_view
      t.boolean :enabled, default: true
      t.string :send_type
      t.integer :send_frequency
      t.timestamps null: false
    end
    add_index :facilitate_users, :program_id
    add_index :facilitate_users, :admin_view_id
    # Dummy table creation to make sure that fixture generation don't have any issues
    # FacilitateUser.create_translation_table! subject: :text, message: :text
    create_table :facilitate_user_translations do |t|
      t.timestamps null: false
    end
  end

  def down
    drop_table :facilitate_users
    # FacilitateUser.drop_translation_table!
    drop_table :facilitate_user_translations
  end
end
