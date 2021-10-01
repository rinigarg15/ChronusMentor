class RakeUpdateAuthConfigForTamkeen< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.production?
        additional_config = {
          "import_data" => {
            "name_identifier" => "Name",
            "attributes" => {
              "Member" => {
                "first_name" => "FirstName",
                "last_name" => "LastName",
                "email" => "Email"
              },
              "ProfileAnswer" => {
                "20966" => "DOB",
                "20967" => "CPR",
                "20936" => "PersonalMobile",
                "20969" => "BusinessMobile",
                "20968" => "Address",
                "20947" => "Gender"
              }
            }
          }
        }.to_yaml.gsub("\n", "\\n")

        DeploymentRakeRunner.add_rake_task("common:auth_config_manager:update DOMAIN='tamkeen.bh' SUBDOMAIN='mentorship' AUTH_TYPE='SAMLAuth' CONFIG_IN_YAML='#{additional_config}'")
      end
    end
  end

  def down
  end
end