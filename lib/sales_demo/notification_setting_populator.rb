module SalesDemo
  class NotificationSettingPopulator < BasePopulator
    REQUIRED_FIELDS = NotificationSetting.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :notification_settings)
    end

    def copy_data
      self.reference.each do |ref_object|
        ns = NotificationSetting.new.tap do |notification_setting|
          assign_data(notification_setting, ref_object)
          notification_setting.program_id = master_populator.referer_hash[:program][ref_object.program_id]
        end
        NotificationSetting.import([ns], validate: false, timestamps: false)
      end
    end
  end
end