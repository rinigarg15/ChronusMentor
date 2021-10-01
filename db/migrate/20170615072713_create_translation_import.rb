class CreateTranslationImport< ActiveRecord::Migration[4.2]
  def change
    ChronusMigrate.ddl_migration do
      create_table :translation_imports do |t|
        t.integer :program_id
        t.text :info
        t.string :local_csv_file_path
        t.string :attachment_file_name
        t.string :attachment_content_type
        t.integer :attachment_file_size
        t.datetime :attachment_updated_at
        t.timestamps null: false
      end
    end
  end
end
