module SalesDemo
  class GroupCheckinPopulator < BasePopulator
    REQUIRED_FIELDS = GroupCheckin.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:date, :created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :group_checkins)
    end

    def copy_data
      self.reference.each do |ref_object|
        gc = GroupCheckin.new.tap do |group_checkin|
          assign_data(group_checkin, ref_object)

          group_checkin.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          group_checkin.user_id = master_populator.referer_hash[:user][ref_object.user_id]
          group_checkin.group_id = master_populator.referer_hash[:group][ref_object.group_id]

          if ref_object.checkin_ref_obj_type == "MentoringModel::Task"
            group_checkin.checkin_ref_obj_id = master_populator.referer_hash[:mentoring_model_task][ref_object.checkin_ref_obj_id]
          else
            group_checkin.checkin_ref_obj_id = master_populator.referer_hash[:member_meeting][ref_object.checkin_ref_obj_id]
          end
        end
        GroupCheckin.import([gc], validate: false, timestamps: false)
      end
    end
  end
end
