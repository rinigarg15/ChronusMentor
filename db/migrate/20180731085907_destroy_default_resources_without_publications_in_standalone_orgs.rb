class DestroyDefaultResourcesWithoutPublicationsInStandaloneOrgs < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      resource_ids = Organization.where(programs_count: 1).includes(:translations, resources: [:translations, :resource_publications]).map do |organization|
        organization.resources.reject{ |resource| resource.resource_publications.any? }.collect(&:id)
      end.flatten
      DelayedEsDocument.skip_es_delta_indexing{ Resource.where(id: resource_ids).destroy_all }
      DelayedEsDocument.delayed_bulk_delete_es_documents(Resource, resource_ids)
    end
  end

  def down
    #do Nothing
  end
end
