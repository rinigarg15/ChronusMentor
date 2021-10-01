class AddResourcePublicationIdToRoleResources< ActiveRecord::Migration[4.2]
  def change
    add_column :role_resources, :resource_publication_id, :integer, null: false 
    add_index :role_resources, :resource_publication_id
  end
end
