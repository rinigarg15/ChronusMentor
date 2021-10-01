module SalesDemo
  class RecentActivityPopulator < BasePopulator
    REQUIRED_FIELDS = RecentActivity.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :recent_activities)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        ra = RecentActivity.new.tap do |recent_activity|
          assign_data(recent_activity, ref_object)
          recent_activity.organization_id = master_populator.referer_hash[:organization][ref_object.organization_id]
          recent_activity.member_id = master_populator.referer_hash[:member][ref_object.member_id]
          if ref_object.ref_obj_type == "Group"
            recent_activity.ref_obj_id = master_populator.referer_hash[:group][ref_object.ref_obj_id]
          elsif ref_object.ref_obj_type == "AbstractMessage"
            recent_activity.ref_obj_id = master_populator.referer_hash[:scrap][ref_object.ref_obj_id]
          else
            next
          end
        end
        referer[ref_object.id] = RecentActivity.last.id
        RecentActivity.import([ra], validate: false, timestamps: false)
      end
      master_populator.referer_hash[:recent_activity] = referer
    end
  end
end

