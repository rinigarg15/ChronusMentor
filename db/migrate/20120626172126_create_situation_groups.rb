class CreateSituationGroups< ActiveRecord::Migration[4.2]
  def up
    create_table :situation_groups do |t|
      t.belongs_to :situation, :null => false      
      t.belongs_to :group, :null => false
      t.timestamps null: false
    end
    add_index :situation_groups, [:group_id, :situation_id]    
  end

  def down
    drop_table :situation_groups
  end
end
