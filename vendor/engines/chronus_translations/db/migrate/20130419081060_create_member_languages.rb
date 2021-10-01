class CreateMemberLanguages < ActiveRecord::Migration[4.2]

  def change
    create_table :member_languages do |t|
      t.belongs_to :member, :null => false
      t.belongs_to :language, :null => false
      
      t.timestamps null: false
    end
    add_index :member_languages, :member_id
    add_index :member_languages, :language_id
  end
end
