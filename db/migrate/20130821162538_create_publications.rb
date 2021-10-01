class CreatePublications< ActiveRecord::Migration[4.2]
  def change
    create_table :publications do |t|
      t.string :title
      t.string :publisher
      t.date :date
      t.string :url
      t.text :authors
      t.text :description
      t.integer :profile_answer_id
      t.timestamps null: false
    end
    add_index :publications, :profile_answer_id
  end
end
