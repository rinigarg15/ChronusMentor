class RakeAuthConfigManagerForSanofiAndWdol< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(:has_downtime => false) do
      if Rails.env.production?
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:add DOMAIN='chronus.com' SUBDOMAIN='sanofimentoring' AUTH_TYPE='ChronusAuth'")
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='chronus.com' SUBDOMAIN='sanofimentoring' AUTH_TYPE='SAMLAuth' ATTRIBUTES_IN_YAML='---\\n:description: If you are a Sanofi employee please login utilizing SSO. If you are\\n  not a Sanaofi employee, utilize the login credentials you created when you joined\\n  the platform.\\n'")
        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:remove DOMAIN='chronus.com' SUBDOMAIN='dol' AUTH_TYPE='ChronusAuth'")
      end
    end
  end

  def down
    # Do nothing
  end
end
