class AddDefaultToResources< ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :default, :boolean, :default => false, :null => false
  end
end
