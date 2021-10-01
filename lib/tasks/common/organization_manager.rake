# TASK: :set_attr
# USAGE: rake common:organization_manager:set_attr DOMAIN=<domain> SUBDOMAIN=<subdomain> ATTR=<logout_path|email_from_address|white_label|favicon_link|audit_user_communication> VALUE=<>
# EXAMPLE: rake common:organization_manager:set_attr DOMAIN="localhost.com" SUBDOMAIN="ceg" ATTR="logout_path" VALUE="https://chronus.com"

namespace :common do
  namespace :organization_manager do
    desc "Set an attr for the specified organization"
    task set_attr: :environment do
      Common::RakeModule::Utils.execute_task do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        allowed_attrs = ["logout_path", "email_from_address", "white_label", "favicon_link", "audit_user_communication"]
        raise "Invalid attr! Allowed attrs are #{allowed_attrs}.join(', ')" unless ENV["ATTR"].in?(allowed_attrs)

        value = ENV["VALUE"]
        value = value.to_s.to_boolean if ENV["ATTR"].in?(["white_label", "audit_user_communication"])
        organization.send("#{ENV['ATTR']}=", value)
        organization.save!
        Common::RakeModule::Utils.print_success_messages("#{ENV['VALUE']} is set as ENV['ATTR'] for #{organization.url}!")
      end
    end

    task set_programs_count: :environment do
      Organization.includes(:programs).each do |organization|
        programs_count = organization.programs.size
        next unless organization.programs_count != programs_count
        organization.update_attributes!(programs_count: programs_count)
      end
      Common::RakeModule::Utils.print_success_messages("Program counts updated successfully")
    end
  end
end