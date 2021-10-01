class RakeUpdateAuthConfigsForTamkeen< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        saml_auth_attributes = { "title" => "Tamkeen Login" }.to_yaml.gsub("\n", "\\n")

        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:remove DOMAIN='tamkeen.bh' SUBDOMAIN='mentorship' AUTH_TYPE='ChronusAuth'")
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='tamkeen.bh' SUBDOMAIN='mentorship' AUTH_TYPE='SAMLAuth' ATTRIBUTES_IN_YAML='#{saml_auth_attributes}'")
      end
    end
  end

  def down
  end
end