class AddResourcesNameToOrganization< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :resources_name, :string, :default => "Resource"
  end
end
