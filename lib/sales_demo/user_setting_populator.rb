module SalesDemo
  class UserSettingPopulator < BasePopulator
    REQUIRED_FIELDS = UserSetting.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :user_settings)
    end

    def copy_data
      self.reference.each do |ref_object|
        us = UserSetting.new.tap do |user_setting|
          assign_data(user_setting, ref_object)
          user_setting.user_id = master_populator.referer_hash[:user][ref_object.member_id]
        end
        UserSetting.import([us], validate: false, timestamps: false)
      end
    end
  end
end