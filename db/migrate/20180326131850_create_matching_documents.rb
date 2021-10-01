class CreateMatchingDocuments < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :matching_documents do |t|
        t.integer :program_id
        t.integer :record_id
        t.boolean :mentor
        t.json :data_fields
        t.timestamps null: false
      end

      Lhm.change_table :matching_documents do |t|
        t.add_index [:program_id], "index_on_program_id"
        t.add_index [:program_id, :mentor, :record_id], "index_on_program_id_and_is_mentor_and_record_id"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :matching_documents
    end
  end
end
