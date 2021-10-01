# look at mentor rotate

namespace :cm do
  desc "Populates random analytical data for campaigns scoped under a program"
  task analytics_demo_populator: :environment do
    require 'highline/import'

    program_id  = ENV['PROGRAM_ID'] || raise("Program name not given. DEMO_USAGE: rake cm:analytics_demo_populator PROGRAM_ID=<program_id>")
    program     = Program.find(program_id)

    choice = ask("Are you sure you want to continue populating dummy analytics for the program: #{program.name}? [y/n] ")
    abort unless choice == "y"
    DemoCampaignPopulator.setup_program_with_default_campaigns(program_id)
    CampaignPopulator.link_program_invitation_campaign_to_mailer_template(program_id)
    puts "Population Successful"
  end

  desc "Enables CampaignManagement feature and populates dummy data for all the programs"
  # ENV['LIMIT'] added for testing
  
  task populate_demo_campaigns_for_all_active_programs: :environment do
    program_limit  = ENV['LIMIT'] || 0
    scope = Program.active
    scope = scope.limit(program_limit) unless program_limit.to_i.zero?
    scope.each do |program|
      DemoCampaignPopulator.setup_program_with_default_campaigns(program.id)
      CampaignPopulator.link_program_invitation_campaign_to_mailer_template(program_id)
    end
  end
end

