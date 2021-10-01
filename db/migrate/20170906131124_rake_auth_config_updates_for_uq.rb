class RakeAuthConfigUpdatesForUq< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.productioneu?
        saml_auth_settings = { "title" => "STUDENT & STAFF Login", "description" => "Use your My UQ login if you are a UQ Student or Staff" }.to_yaml.gsub("\n", "\\n")
        chronus_auth_settings = { "title" => "EXTERNAL Login", "description" => "Non University Users - Please use your email to access this program" }.to_yaml.gsub("\n", "\\n")
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' AUTH_TYPE='SAMLAuth' ATTRIBUTES_IN_YAML='#{saml_auth_settings}'")
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='edu.au' SUBDOMAIN='mentoring.app.uq' AUTH_TYPE='ChronusAuth' ATTRIBUTES_IN_YAML='#{chronus_auth_settings}'")
      end
    end
  end

  def down
    # Do nothing
  end
end
