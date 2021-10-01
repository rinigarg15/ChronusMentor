module SalesDemo
  class ConnectionMembershipStateChangePopulator < BasePopulator
    REQUIRED_FIELDS = ConnectionMembershipStateChange.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :date_time]

    attr_accessor :parent_object, :reference, :master_populator

    def initialize(parent_object, reference, master_populator)
      self.parent_object = parent_object
      self.reference = reference
      self.master_populator = master_populator
    end

    def copy_data
      state_changes =  self.reference.collect do |ref_object|
        cmsc = parent_object.state_changes.new.tap do |connection_membership_state_change|
          assign_data(connection_membership_state_change, ref_object)
          connection_membership_state_change.set_info(YAML.load(ref_object.info))
          connection_membership_state_change.date_id = (connection_membership_state_change.created_at.to_i / 1.day.to_i)
          connection_membership_state_change.role_id = self.master_populator.solution_pack_referer_hash["Role"][ref_object.role_id.to_i]
          connection_membership_state_change.user_id = self.master_populator.referer_hash[:user][ref_object.user_id]
          connection_membership_state_change.group_id = self.parent_object.group_id
          connection_membership_state_change
        end
        cmsc
      end
      parent_object.send("state_changes=", state_changes)
    end
  end
end

