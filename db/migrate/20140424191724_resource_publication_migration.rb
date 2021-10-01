class ResourcePublicationMigration< ActiveRecord::Migration[4.2]
  def up
    resource_hash = Resource.includes(:translations).index_by(&:id)
    resource_publications = {}
    RoleResource.includes(role: :program).find_each do |role_resource|
      say "Migrating role_resource - #{role_resource.id}"
      program = role_resource.role.program
      resource = resource_hash[role_resource.resource_id]
      resource_publications[program.id] ||= {}
      ActiveRecord::Base.transaction do
        begin
          resource_publications[program.id][resource.id] ||= create_resource_publication(program, resource)
          role_resource.resource_publication = resource_publications[program.id][resource.id]
          role_resource.save!
        rescue => exception
          say "Failed for Program# - #{program.id} and Resource# - #{resource.id}. Trace: #{exception.message}"
          raise exception
        end  
      end
    end
  end

  def down
    RoleResource.update_all(resource_publication_id: nil)
    ResourcePublication.destroy_all
  end

  private

  def create_resource_publication(program, resource)
    program.resource_publications.create!(
      resource: resource,
      position: resource.position
    )
  end 
end
