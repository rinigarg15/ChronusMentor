module SalesDemo
  class MentoringModelActivityPopulator < BasePopulator
    REQUIRED_FIELDS = MentoringModel::Activity.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :mentoring_model_activities)
    end

    def copy_data
      self.reference.each do |ref_object|
        mma = MentoringModel::Activity.new.tap do |mentoring_model_activity|
          assign_data(mentoring_model_activity, ref_object)
          mentoring_model_activity.ref_obj_id = master_populator.referer_hash[:mentoring_model_goal][ref_object.ref_obj_id]
          mentoring_model_activity.member_id = master_populator.referer_hash[:member][ref_object.member_id]
          mentoring_model_activity.connection_membership_id = master_populator.referer_hash[:connection_membership][ref_object.connection_membership_id]
        end
        MentoringModel::Activity.import([mma], validate: false, timestamps: false)
      end
    end
  end
end

