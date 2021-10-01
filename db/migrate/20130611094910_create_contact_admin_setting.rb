class CreateContactAdminSetting< ActiveRecord::Migration[4.2]
  def change
    create_table :contact_admin_settings do |t|
      t.string :label_name
      t.text :content
      t.text :contact_url
      t.belongs_to :program, :null => false
      t.timestamps null: false
    end
    add_index :contact_admin_settings, :program_id
  end
end
