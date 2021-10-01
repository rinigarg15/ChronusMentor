module SalesDemo
  class OrganizationResourcePopulator < BasePopulator
    REQUIRED_FIELDS = Resource.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :resources)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        Resource.new.tap do |resource|
          assign_data(resource, ref_object)
          resource.program_id = master_populator.referer_hash[:organization][ref_object.program_id]
          resource.content = self.master_populator.handle_ck_editor_import(ref_object.content)
          resource.save_without_timestamping!
          create_default_resource_publications(resource)
          referer[ref_object.id] = resource.id
        end
      end
      master_populator.referer_hash[:resource] = referer
    end

    def create_default_resource_publications(resource)
      return unless resource.default?
      resource.organization.reload.programs.each do |program|
        program.resource_publications.create!(resource_id: resource.id)
      end
    end
  end
end