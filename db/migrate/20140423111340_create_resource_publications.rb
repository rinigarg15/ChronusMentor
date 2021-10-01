class CreateResourcePublications< ActiveRecord::Migration[4.2]
  def change
    create_table :resource_publications do |t|
      t.belongs_to :program
      t.belongs_to :resource
      t.integer :position
      t.timestamps null: false
    end

    add_index :resource_publications, :program_id
    add_index :resource_publications, :resource_id
  end
end

