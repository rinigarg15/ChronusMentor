# Usage: sudo bundle exec rake career_dev:change_portal_roots SUBDOMAIN=<subdomain> DOMAIN=<domain>
# Usage: sudo bundle exec rake career_dev:change_portal_roots SUBDOMAIN="nch" DOMAIN="chronus.com"
# JIRA Ticket: https://chronus.atlassian.net/browse/CD-79
# More Info : The portal default root should have prefix "cd"

namespace :career_dev do
  desc 'Change the root of all portals'
  task :change_portal_roots => :environment do
    ActiveRecord::Base.transaction do
      subdomain = ENV['SUBDOMAIN']
      domain = ENV['DOMAIN'] || DEFAULT_DOMAIN_NAME
      raise "Subdomain can't be blank" unless subdomain.present?
      organization = Program::Domain.get_organization(domain, subdomain)
      raise "Organization with domain: #{domain} and subdomain: #{subdomain} doesn't exist" unless organization.present?
      puts "Organization: #{organization.name}"
      
      organization.portals.each_with_index do |program, i|
        puts "#{program.name}: changing root '#{program.root}' to 'cd#{i+1}'"
        program.update_attribute(:root, "cd#{i+1}")
      end

      puts "Done."
    end
  end
end

