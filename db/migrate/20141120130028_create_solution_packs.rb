class CreateSolutionPacks< ActiveRecord::Migration[4.2]
  def change
    create_table :solution_packs do |t|
      t.string :description
      t.references :user
      t.integer :program_id
      t.string :attachment_file_name
      t.string :attachment_content_type
      t.integer :attachment_file_size
      t.datetime :attachment_updated_at
      t.string :created_by

      t.timestamps null: false
    end

    add_index :solution_packs, :program_id
  end
end