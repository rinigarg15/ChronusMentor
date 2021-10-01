class CreateFlags< ActiveRecord::Migration[4.2]
  def change
    create_table :flags do |t|
      t.string :content_type
      t.integer :content_id
      t.text :reason
      t.belongs_to :user
      t.integer :resolver_id
      t.datetime :resolved_at
      t.integer :status
      t.belongs_to :program

      t.timestamps null: false
    end
  end
end
