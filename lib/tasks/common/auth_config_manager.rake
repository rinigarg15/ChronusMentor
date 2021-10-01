# TASK: :add
# USAGE: rake common:auth_config_manager:add DOMAIN=<domain> SUBDOMAIN=<subdomain> AUTH_TYPE=<auth_type> LOCALE=<locale> ATTRIBUTES=<> CONFIG=<>
# EXAMPLE: rake common:auth_config_manager:add DOMAIN="localhost.com" SUBDOMAIN="ceg" AUTH_TYPE="SAMLAuth" LOCALE="fr-CA" ATTRIBUTES="{:title=>\"External Login\"}" CONFIG= "{\"idp_cert_fingerprint\"=>\"12345\"}"

# TASK: :update
# USAGE: rake common:auth_config_manager:update DOMAIN=<domain> SUBDOMAIN=<subdomain> AUTH_TYPE=<new_domain> LOCALE=<new_subdomain> ATTRIBUTES=<> CONFIG=<>
# EXAMPLE: rake common:auth_config_manager:update DOMAIN="localhost.com" SUBDOMAIN="ceg" AUTH_TYPE="SAMLAuth" LOCALE="fr-CA" ATTRIBUTES="{:title=>\"External Login\"}" CONFIG="{\"idp_cert_fingerprint\"=>\"12345\"}"

namespace :common do
  namespace :auth_config_manager do
    desc "Add an AuthConfig to an organization"
    task add: :environment do
      Common::RakeModule::Utils.execute_task(locale: ENV["LOCALE"]) do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        auth_config = organization.auth_configs.new(auth_type: ENV["AUTH_TYPE"])
        Common::RakeModule::AuthConfigManager.set_attributes_and_options_for_auth_config(auth_config, ENV["ATTRIBUTES"], ENV["CONFIG"])
        Common::RakeModule::Utils.print_success_messages("New AuthConfig has been added!")
      end
    end

    desc "Update an AuthConfig of an organization"
    task update: :environment do
      Common::RakeModule::Utils.execute_task(locale: ENV["LOCALE"]) do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        auth_config = Common::RakeModule::AuthConfigManager.fetch_auth_config(organization, ENV["AUTH_TYPE"])
        Common::RakeModule::AuthConfigManager.set_attributes_and_options_for_auth_config(auth_config, ENV["ATTRIBUTES"], ENV["CONFIG"])
        Common::RakeModule::Utils.print_success_messages("AuthConfig has been updated!")
      end
    end
  end
end