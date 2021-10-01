# TASK: :disable_ongoing_mentoring
# USAGE: rake common:matching_settings_updater:disable_ongoing_mentoring DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list>
# EXAMPLE: rake common:matching_settings_updater:disable_ongoing_mentoring DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1"

# TASK: :change_mentor_request_style
# USAGE: rake common:matching_settings_updater:change_mentor_request_style DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> MENTOR_REQUEST_STYLE=<0|1|2>
# EXAMPLE: rake common:matching_settings_updater:change_mentor_request_style DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1,p2" MENTOR_REQUEST_STYLE="2"

# TASK: :enable_eaton_workflow
# USAGE: rake common:matching_settings_updater:enable_eaton_workflow DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list> MIN_PREFERRED_MENTOR=<>
# EXAMPLE: rake common:matching_settings_updater:enable_eaton_workflow DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1" MIN_PREFERRED_MENTOR="3"

# TASK: :clear_pending_mentor_requests_and_offers
# USAGE: rake common:matching_settings_updater:clear_pending_mentor_requests_and_offers DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<comma_separated_list>
# EXAMPLE: rake common:matching_settings_updater:clear_pending_mentor_requests_and_offers DOMAIN="localhost.com" SUBDOMAIN="ceg" ROOTS="p1"

namespace :common do
  namespace :matching_settings_updater do
    desc "Disable ongoing mentoring in specified program(s)"
    task disable_ongoing_mentoring: :environment do
      Common::RakeModule::Utils.execute_task do
        programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])[0]
        programs.each do |program|
          raise "Ongoing connections in #{program.url}!" if program.groups.active.present?
          raise "Pending mentor requests in #{program.url}" if program.mentor_requests.active.present?
          raise "Pending mentor offers in #{program.url}!" if program.mentor_offers.pending.present?

          program.engagement_type = Program::EngagementType::CAREER_BASED
          program.save!
          program.update_default_abstract_views_for_program_management_report
          permissions_to_be_removed = RoleConstants::MENTOR_REQUEST_PERMISSIONS + ["offer_mentoring"]
          program.roles.each do |role|
            permissions_to_be_removed.each { |permission_name| role.remove_permission(permission_name) }
          end
          Common::RakeModule::Utils.print_success_messages("Ongoing mentoring has been disabled in #{program.url}!")
        end
      end
    end

    desc "Change mentor request style of specified program(s)"
    task change_mentor_request_style: :environment do
      Common::RakeModule::Utils.execute_task do
        programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])[0]
        programs.each do |program|
          raise "Pending mentor requests in #{program.url}" if program.mentor_requests.active.present?
          raise "Invalid MENTOR_REQUEST_STYLE!" if ENV["MENTOR_REQUEST_STYLE"].blank?

          program.mentor_request_style = ENV["MENTOR_REQUEST_STYLE"].to_i
          program.save!
          Common::RakeModule::Utils.print_success_messages("Mentor request style of #{program.url} has been updated!")
        end
      end
    end

    desc "Enable eaton matching workflow in specified program(s)"
    task enable_eaton_workflow: :environment do
      Common::RakeModule::Utils.execute_task do
        programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])[0]
        programs.each do |program|
          raise "Pending mentor requests in #{program.url}" if program.mentor_requests.active.present?

          program.mentor_request_style = Program::MentorRequestStyle::MENTEE_TO_ADMIN
          program.allow_preference_mentor_request = true
          program.min_preferred_mentors = ENV['MIN_PREFERRED_MENTOR'].to_i
          program.save!
          Common::RakeModule::Utils.print_success_messages("Eaton matching workflow has been enabled for #{program.url}!")
        end
      end
    end

    desc "Remove pending mentor requests and offers from specified program(s)"
    task clear_pending_mentor_requests_and_offers: :environment do
      Common::RakeModule::Utils.execute_task do
        programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])[0]
        programs.each do |program|
          pending_mentor_requests = program.mentor_requests.active
          pending_mentor_offers = program.mentor_offers.pending
          puts "Pending mentor requests in #{program.url}: #{pending_mentor_requests.size}"
          puts "Pending mentor offers in #{program.url}: #{pending_mentor_offers.size}"
          pending_mentor_requests.destroy_all
          pending_mentor_offers.destroy_all
          Common::RakeModule::Utils.print_success_messages("Pending mentor requests and offers in #{program.url} have been removed!")
        end
      end
    end
  end
end