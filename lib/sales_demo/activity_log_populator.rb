module SalesDemo
  class ActivityLogPopulator < BasePopulator
    REQUIRED_FIELDS = ActivityLog.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :activity_logs)
    end

    def copy_data
      self.reference.each do |ref_object|
        al = ActivityLog.new.tap do |activity_log|
          assign_data(activity_log, ref_object)
          activity_log.user_id = master_populator.referer_hash[:user][ref_object.user_id]
          activity_log.program_id = master_populator.referer_hash[:program][ref_object.program_id]
        end
        ActivityLog.import([al], validate: false, timestamps: false)
      end
    end
  end
end

