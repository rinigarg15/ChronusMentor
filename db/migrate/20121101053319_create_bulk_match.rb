class CreateBulkMatch< ActiveRecord::Migration[4.2]
  def change
    create_table :bulk_matches do |t|
      t.integer :mentor_view_id
      t.integer :mentee_view_id
      t.belongs_to :program
      t.timestamps null: false
    end
    add_index :bulk_matches, :program_id
  end
end