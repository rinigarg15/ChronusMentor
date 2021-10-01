# TASK: :add_permission
# USAGE: rake common:role_manager:add_permission DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> ROLE_NAME=<> PERMISSION=<>
# EXAMPLE: rake common:role_manager:add_permission DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1" ROLE_NAME="mentor" PERMISSION="view_reports"

# TASK: :remove_permission
# USAGE: rake common:role_manager:remove_permission DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> ROLE_NAME=<> PERMISSION=<>
# EXAMPLE: rake common:role_manager:remove_permission DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1" ROLE_NAME="mentor" PERMISSION="view_reports"

namespace :common do
  namespace :role_manager do
    desc "Provision the given role with specified permission"
    task add_permission: :environment do
      Common::RakeModule::Utils.execute_task do
        programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])[0]
        programs.each do |program|
          role = program.find_role(ENV["ROLE_NAME"])
          role.add_permission(ENV["PERMISSION"])
        end
        Common::RakeModule::Utils.print_success_messages("#{ENV['PERMISSION']} has been added for #{ENV['ROLE_NAME']} in #{programs.map(&:url).join(', ')}")
      end
    end

    desc "Revoke the specified permission from given role"
    task remove_permission: :environment do
      Common::RakeModule::Utils.execute_task do
        programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])[0]
        programs.each do |program|
          role = program.find_role(ENV["ROLE_NAME"])
          role.remove_permission(ENV["PERMISSION"])
        end
        Common::RakeModule::Utils.print_success_messages("#{ENV['PERMISSION']} has been revoked for #{ENV['ROLE_NAME']} in #{programs.map(&:url).join(', ')}")
      end
    end
  end
end