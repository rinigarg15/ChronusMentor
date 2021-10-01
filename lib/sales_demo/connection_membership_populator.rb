module SalesDemo
  class ConnectionMembershipPopulator
    include PopulatorUtils
    REQUIRED_FIELDS = Connection::Membership.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :last_status_update_at]

    ASSOCIATED_MODELS = {
      :connection_membership_state_changes => "SalesDemo::ConnectionMembershipStateChangePopulator"
    }

    attr_accessor :parent_object, :reference, :master_populator, :associated_model_reference

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
      self.associated_model_reference = connection_membership_associated_models
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        cm = Connection::Membership.new.tap do |connection_membership|
          assign_data(connection_membership, ref_object)
          connection_membership.user_id = master_populator.referer_hash[:user][ref_object.user_id]
          connection_membership.role_id = master_populator.solution_pack_referer_hash["Role"][ref_object.role_id.to_i]
          copy_associated_models(connection_membership, ref_object.id)
          connection_membership.created_for_sales_demo = true
          connection_membership.group_id = self.parent_object.id
          connection_membership
        end
        cm.save!
        referer[ref_object.id] = Connection::Membership.last.id
      end
      if self.master_populator.referer_hash[:connection_membership].present?
        self.master_populator.referer_hash[:connection_membership].merge!(referer)
      else
        self.master_populator.referer_hash[:connection_membership] = referer
      end
    end

    def copy_associated_models(connection_membership, ref_object_id)
      ASSOCIATED_MODELS.each do |key, value|
        value.constantize.new(connection_membership, associated_model_reference[key][ref_object_id] || [], master_populator).copy_data
      end
    end

    def connection_membership_associated_models
      return ASSOCIATED_MODELS.keys.inject({}) do |associated_model_reference, key|
        associated_model_reference[key] = convert_to_objects(master_populator.parse_file(key)).group_by(&:connection_membership_id)
        associated_model_reference
      end
    end
  end
end