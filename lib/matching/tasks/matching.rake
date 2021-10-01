namespace :matching do
  desc "Enqueue's a DJ for full indexing"
  task :full_index_and_refresh_later => :environment do
    Matching.perform_full_index_and_refresh_later
  end

  desc "Performs a full index of the match document and full refresh of the score"
  task :full_index_and_refresh => :environment do
    Matching.perform_full_index_and_refresh
  end

  # Example: bundle exec rake matching:delta_index_and_refresh_for_organization SUBDOMAIN="iitm" DOMAIN="localhost.com"
  desc "Performs delta index of the match document and refresh of the score for the given organization"
  task :delta_index_and_refresh_for_organization => :environment do
    organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
    Matching.perform_organization_delta_index_and_refresh(organization.id)
  end

  desc "Clears the match document and score and performs a full index and full refresh"
  task :clear_and_full_index_and_refresh => :environment do
    Matching.perform_clear_and_full_index_and_refresh
  end
end