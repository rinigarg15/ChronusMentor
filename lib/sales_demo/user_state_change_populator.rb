module SalesDemo
  class UserStateChangePopulator < BasePopulator
    REQUIRED_FIELDS = UserStateChange.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :date_time]

    def initialize(master_populator)
      super(master_populator, :user_state_changes)
    end

    def copy_data
      self.reference.each do |ref_object|
        usc = UserStateChange.new.tap do |user_state_change|
          assign_data(user_state_change, ref_object)
          user_state_change.set_info(modify_hash(ref_object.info))
          user_state_change.set_connection_membership_info(modify_hash(ref_object.connection_membership_info, :from_role, :to_role))
          user_state_change.date_id = (user_state_change.created_at.to_i / 1.day.to_i)
          user_state_change.user_id = master_populator.referer_hash[:user][ref_object.user_id]
        end
        UserStateChange.import([usc], validate: false, timestamps: false)
      end
    end
  end
end

