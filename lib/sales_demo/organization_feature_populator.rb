module SalesDemo
  class OrganizationFeaturePopulator
    include PopulatorUtils
    REQUIRED_FIELDS = OrganizationFeature.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    attr_accessor :reference, :master_populator

    def initialize(master_populator)
      self.reference = convert_to_objects(master_populator.parse_file(:organization_features))
      self.master_populator = master_populator
    end

    def copy_data
      self.reference.each do |ref_object|
        feature = Feature.find_by(id: ref_object.feature_id)
        if feature.present?
          # Assuming only one organization is being populated
          organization ||= Organization.find(master_populator.referer_hash[:organization][ref_object.organization_id])
          organization.enable_feature(feature.name, ref_object.enabled)
        end
      end
    end
  end
end