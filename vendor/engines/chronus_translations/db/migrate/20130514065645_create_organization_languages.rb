class CreateOrganizationLanguages < ActiveRecord::Migration[4.2]

  def change
    create_table :organization_languages do |t|
      t.boolean :enabled, :default => false, :null => false
      t.belongs_to :language, :null => false
      t.belongs_to :organization, :null => false
      t.boolean :default, :null => false, :default => false
      t.timestamps null: false
    end
    add_index :organization_languages, :language_id
    add_index :organization_languages, :organization_id
  end
end
