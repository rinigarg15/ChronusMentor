module SalesDemo
  class GroupStateChangePopulator < BasePopulator
    REQUIRED_FIELDS = GroupStateChange.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :group_state_changes)
    end

    def copy_data
      self.reference.each do |ref_object|
        gsc = GroupStateChange.new.tap do |group_state_change|
          assign_data(group_state_change, ref_object)
          group_state_change.date_id = (group_state_change.created_at.to_i / 1.day.to_i)

          group_state_change.group_id = master_populator.referer_hash[:group][ref_object.group_id]
        end
        GroupStateChange.import([gsc], validate: false, timestamps: false)
      end
    end
  end
end

