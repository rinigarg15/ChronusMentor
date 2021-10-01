class CopyAuthConfigTitleDescriptionToAuthConfigSettings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Organization.all.includes(auth_configs: :translations).each do |organization|
        chronus_auth = organization.auth_configs.find { |auth_config| auth_config.auth_type == AuthConfig::Type::CHRONUS }
        custom_auth = organization.auth_configs.find { |auth_config| auth_config.auth_type != AuthConfig::Type::CHRONUS }

        locales = []
        locales += chronus_auth.translations.map(&:locale) if chronus_auth.present?
        locales += custom_auth.translations.map(&:locale) if custom_auth.present?
        locales.uniq!

        auth_config_setting = AuthConfigSetting.create!(organization_id: organization.id)
        locales.each do |locale|
          GlobalizationUtils.run_in_locale(locale) do
            if chronus_auth.present?
              auth_config_setting.default_section_title = chronus_auth.read_attribute(:title)
              auth_config_setting.default_section_description = chronus_auth.read_attribute(:description)
            end
            if custom_auth.present?
              auth_config_setting.custom_section_title = custom_auth.read_attribute(:title)
              auth_config_setting.custom_section_description = custom_auth.read_attribute(:description)
            end
            auth_config_setting.save!
          end
        end
      end

      if Rails.env.production?
        smu_organization = Program::Domain.get_organization("edu.sg", "mentoring.alumni.smu")
        auth_config_setting = smu_organization.auth_config_setting
        auth_config_setting.custom_section_title = nil
        auth_config_setting.save!
      end
    end
  end

  def down
  end
end