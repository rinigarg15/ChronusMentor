# TASK: :add
# USAGE: rake common:program_domain_manager:add DOMAIN=<domain> SUBDOMAIN=<subdomain> NEW_DOMAIN=<new_domain> NEW_SUBDOMAIN=<new_subdomain> DEFAULT=<>
# EXAMPLE: rake common:program_domain_manager:add DOMAIN="localhost.com" SUBDOMAIN="ceg" NEW_DOMAIN="localhost.com" NEW_SUBDOMAIN="ceg.new" DEFAULT="true"

# TASK: :remove
# USAGE: rake common:program_domain_manager:remove DOMAIN=<domain> SUBDOMAIN=<subdomain>
# EXAMPLE: rake common:program_domain_manager:remove DOMAIN="localhost.com" SUBDOMAIN="ceg"

# TASK: :update
# USAGE: rake common:program_domain_manager:update DOMAIN=<domain> SUBDOMAIN=<subdomain> NEW_DOMAIN=<new_domain> NEW_SUBDOMAIN=<new_subdomain> DEFAULT=<>
# EXAMPLE: rake common:program_domain_manager:update DOMAIN="localhost.com" SUBDOMAIN="ceg" NEW_DOMAIN="localhost.com" NEW_SUBDOMAIN="ceg.new" DEFAULT="true"

namespace :common do
  namespace :program_domain_manager do
    desc "Add new Program Domain for an organization"
    task add: :environment do
      Common::RakeModule::Utils.execute_task do
        organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
        new_program_domain = organization.program_domains.new
        new_program_domain.domain = ENV["NEW_DOMAIN"]
        new_program_domain.subdomain = ENV["NEW_SUBDOMAIN"]
        new_program_domain.is_default = false
        new_program_domain.save!
        Common::RakeModule::ProgramDomainManager.make_default(new_program_domain) if ENV["DEFAULT"].to_boolean
        Common::RakeModule::Utils.print_success_messages("New domain has been setup for #{organization.url}!")
      end
    end

    desc "Remove an existing Program Domain"
    task remove: :environment do
      Common::RakeModule::Utils.execute_task do
        program_domain = Common::RakeModule::ProgramDomainManager.fetch_program_domain(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        organization = program_domain.organization
        raise "Only Program Domain!" if organization.program_domains.size == 1

        if program_domain.is_default?
          other_program_domain = (organization.program_domains - [program_domain])[0]
          Common::RakeModule::ProgramDomainManager.make_default(other_program_domain)
        end
        program_domain.destroy
        Common::RakeModule::Utils.print_success_messages("Specified program domain has been removed! Default: #{other_program_domain.try(:get_url) || organization.url}")
      end
    end

    desc "Update an existing Program Domain"
    task update: :environment do
      Common::RakeModule::Utils.establish_cloned_db_connection(ENV["CLONED_SOURCE_DB"])
      Common::RakeModule::Utils.execute_task do
        program_domain = Common::RakeModule::ProgramDomainManager.fetch_program_domain(ENV["DOMAIN"], ENV["SUBDOMAIN"])
        program_domain.domain = ENV["NEW_DOMAIN"]
        program_domain.subdomain = ENV["NEW_SUBDOMAIN"]
        program_domain.save!
        Common::RakeModule::ProgramDomainManager.make_default(program_domain) if ENV["DEFAULT"].to_boolean
        Common::RakeModule::Utils.print_success_messages("Specified program domain has been updated!")
      end
    end
  end
end