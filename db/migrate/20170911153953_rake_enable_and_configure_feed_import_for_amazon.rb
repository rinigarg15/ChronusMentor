class RakeEnableAndConfigureFeedImportForAmazon< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        config_options = {
          "csv_options" => {
            "key_mapping" => {
              "Supervisor Name" => "Manager/Supervisor",
              "Department Name" => "Department",
              "Level" => "Job Level",
              "STeam Name" => "Reporting Relationship Steam Name",
              "Tenure ID" => "Amazon tenure",
              "Country" => "Work Location Country",
              "Full/Part" => "Full-Time or Part-Time",
              "Full Location" => "Work Location Full",
              "GL-Expense" => "Business Unit",
              "User Logon ID" => "Username",
              "Manager?" => "Manager Flag"
            }
          },
          "allow_location_updates" => true,
          "secondary_questions_map" => {
            "#{ProfileQuestion::Type::LOCATION}" => "Work Location Full"
          }
        }.with_indifferent_access.to_yaml
        DeploymentRakeRunner.add_rake_task("common:feed_import_configuration_manager:update_options DOMAIN='chronus.com' SUBDOMAIN='amazon-mentoring' CONFIG_OPTIONS_IN_YAML='#{config_options.gsub!("\n", "\\n")}'")
      end
    end
  end

  def down
    #Do nothing
  end
end