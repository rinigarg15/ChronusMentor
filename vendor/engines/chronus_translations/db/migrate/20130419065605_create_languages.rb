class CreateLanguages < ActiveRecord::Migration[4.2]

  def change
    create_table :languages do |t|
      t.string :title, :null => false
      t.string :display_title, :null => false
      t.string :language_name, :null => false
      t.boolean :enabled, :null => false, :default => false

      t.timestamps null: false
    end

  end
end
