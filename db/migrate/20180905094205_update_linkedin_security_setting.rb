class UpdateLinkedinSecuritySetting < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Organization.includes(:organization_features, :security_setting, :translations, :programs).each do |org|
        unless org.linkedin_imports_allowed?
          org.enable_feature(FeatureName::LINKEDIN_IMPORTS, false) if org.has_feature?(FeatureName::LINKEDIN_IMPORTS)
          org.programs.each do |program|
            program.enable_feature(FeatureName::LINKEDIN_IMPORTS, false) if program.has_feature?(FeatureName::LINKEDIN_IMPORTS)
          end
        end
      end

      SecuritySetting.where(linkedin_token: [nil, ""], linkedin_secret: [nil, ""]).update_all(linkedin_token: APP_CONFIG[:linkedin_token], linkedin_secret: APP_CONFIG[:linkedin_secret])
    end
  end

  def down
    #Do nothing
  end
end
