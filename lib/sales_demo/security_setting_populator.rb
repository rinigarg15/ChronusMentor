module SalesDemo
  class SecuritySettingPopulator < BasePopulator
    REQUIRED_FIELDS = [:linkedin_token, :linkedin_secret, :created_at, :updated_at]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :security_settings)
    end

    def copy_data
      # using general assumption used in sales demo populator, ie, only one organization is being populated
      raise "SecuritySetting objects count is not 1" if self.reference.size != 1
      ref_object = self.reference.first
      security_setting = Organization.find(master_populator.referer_hash[:organization][ref_object.program_id]).security_setting
      assign_data(security_setting, ref_object)
      security_setting.save!
    end
  end
end