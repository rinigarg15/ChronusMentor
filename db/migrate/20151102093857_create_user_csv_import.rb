class CreateUserCsvImport< ActiveRecord::Migration[4.2]
  def change
    create_table :user_csv_imports do |t|
      t.integer :member_id
      t.integer :program_id
      t.text :info
      t.string :local_csv_file_path
      t.string :attachment_file_name
      t.string :attachment_content_type
      t.integer :attachment_file_size
      t.datetime :attachment_updated_at
      t.boolean :imported, defaule: false
      t.timestamps null: false
    end
  end
end
