# Usage: rake db:populate_scanner_program RAILS_ENV=standby SUBDOMAIN=<subdomain> DOMAIN=<domain>

namespace :db do
  desc "Populating Security scanner"
  task :populate_scanner_program => :environment do
    require 'faker'
    require 'populator'
    require_relative './scanner_helper.rb'

    ActionMailer::Base.perform_deliveries = false
    ActiveRecord::Base.connection.execute "SET AUTOCOMMIT=0;"
    ActiveRecord::Base.transaction do
      create_and_populate_organization(ENV['DOMAIN'] || ScannerConstants::PROGRAM_DOMAIN, ENV['SUBDOMAIN'] || ScannerConstants::PROGRAM_SUBDOMAIN)
    end
  end
end

private

def create_and_populate_organization(domain, subdomain)
  if Program::Domain.get_organization(domain, subdomain)
    raise "Error: Organization with domain #{domain} and subdomain #{subdomain} already exists"
  end
  puts "Starting..."
  organization = Program::Domain.get_organization(domain, subdomain) || Organization.new
  organization.name = 'Scanner'
  organization.subscription_type = Organization::SubscriptionType::PREMIUM
  organization.save!
  DataPopulator.populate_default_contents(organization)
  unless organization.program_domains.any?
    pdomain = organization.program_domains.new()
    pdomain.subdomain = subdomain.dup
    pdomain.domain = domain.dup
    pdomain.save!
  end
  organization.enabled_features = FeatureName.all
  populate_sections(organization)
  populate_profile_questions(organization)
  create_org_admin(organization)
  create_org_mentor_and_mentee(organization)
  populate_members(organization)
  create_and_populate_programs(organization)
  populate_articles(organization)
  populate_organization_languages(organization)
  populate_messages(organization)
  puts "Done."
end

def create_and_populate_programs(organization)
  Program::MentorRequestStyle.all.each do |mentor_request_style|
    suffix = mentor_request_style.to_s
    say_populating "Scanner Program #{suffix}" do
      program = organization.programs.new
      program.name = 'Scanner Program' + suffix
      program.root = "scanner" + suffix
      program.mentor_request_style = mentor_request_style
      program.description = "Description" + suffix
      program.save!
      DataPopulator.populate_default_contents(program)
      populate_program(program)
    end
  end
end

def populate_program(program)
  populate_users(program)
  populate_role_questions(program)
  populate_membership_requests(program)
  populate_profile_answers(program)
  populate_mentor_requests(program)
  populate_scraps(program)
  populate_availability_slots(program)
  populate_announcements(program)
  populate_admin_messages(program)
  populate_invitations(program)
  populate_program_qa(program)
  populate_forums(program)
  populate_connections(program)
  populate_meetings(program)
  populate_program_events(program)
  populate_user_settings(program)
  populate_bulk_match(program)
  populate_coaching_goals(program)
  populate_coaching_goal_activities(program)
  populate_common_questions(program)
  populate_common_answers(program)
  populate_confidentiality_audit_log(program)
  populate_connection_private_notes(program)
  populate_contact_admin_setting(program)
  populate_flags(program)
end
