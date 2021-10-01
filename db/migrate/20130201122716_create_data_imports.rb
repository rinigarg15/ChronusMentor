class CreateDataImports< ActiveRecord::Migration[4.2]
  def change
    create_table :data_imports do |t|
      t.integer :organization_id
      t.integer :status
      t.string :failure_message
      t.integer :created_count
      t.integer :updated_count
      t.integer :suspended_count

      t.timestamps null: false
    end
  end
end
