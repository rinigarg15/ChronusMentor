class RemoveGlobalFromUsers< ActiveRecord::Migration[4.2]
  def up  	
    remove_column :users, :global    
  end

  def down
    add_column :users, :global, :boolean    
  end
end
