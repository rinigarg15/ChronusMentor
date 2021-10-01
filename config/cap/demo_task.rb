#Possible MENTOR_REQUEST_STYLES
# Program::MentorRequestStyle::MENTEE_TO_MENTOR = 0
# Program::MentorRequestStyle::MENTEE_TO_ADMIN  = 1
# Program::MentorRequestStyle::NONE             = 2

#Possible SUBSCRIPTION_STYLES
# Organization::SubscriptionType::BASIC       = 0
# Organization::SubscriptionType::PREMIUM     = 1
# Organization::SubscriptionType::ENTERPRISE  = 2

#Possible PROGRAM_TYPE
# Demo::ProgramType::CORPORATE    =  0
# Demo::ProgramType::EDUCATION     = 1

# Possible ENGAGEMENT_TYPE
# Program::EngagementType::CAREER_BASED   = 1
# Program::EngagementType::PROJECT_BASED  = 2

# Mentor Request Style should be Program::MentorRequestStyle::NONE and Group mentoring should be false if we need subscription_type = Organization::SubscriptionType::BASIC

Capistrano::Configuration.instance.load do
  namespace :chronus do
    DEMO_USAGE = <<-USAGE
      cap demo chronus:create_demo_program \
      NAME=<prog-name> \
      SUBDOMAIN=<prog-subdomain> \
      N_PROGRAMS=<number of programs> \
      MENTOR_REQUEST_STYLE=( 0 | 1 | 2 ) \
      GROUP_MENTORING=(true|false) \
      PROGRAM_TYPE=(0|1) \
      SUBSCRIPTION_STYLE=(0|1|2) \
      ENGAGEMENT_TYPE=(1|2)
    USAGE
    
    desc <<-DESC
      Setup a new demo program for any server. Takes the name of the program and subdomain \
      as args. For more details, also refer the the rake task db:populate_demo_program.

      Usage: #{DEMO_USAGE}
    DESC
    
    task :create_demo_program, :roles => :app do
      name = ENV['NAME']
      subdomain = ENV['SUBDOMAIN']
      total_program = ENV['N_PROGRAMS'] || 1
      moderated = ENV['MENTOR_REQUEST_STYLE']
      group_mentoring = (ENV['GROUP_MENTORING'] == "true")
      subscription_style = ENV['SUBSCRIPTION_STYLE']
      program_type = ENV['PROGRAM_TYPE']
      engagement_type = (ENV['ENGAGEMENT_TYPE'] || Program::EngagementType::CAREER_BASED).to_i

      unless (name && subdomain)
        abort("!!! Name and Subdomain mandatory. #{DEMO_USAGE}. Aborting...")
      end

      cmd = "cd /mnt/app/current && rake RAILS_ENV='#{current_deploy_mode}'"
      cmd << " NAME='#{name}' "
      cmd << " SUBDOMAIN='#{subdomain}' "
      cmd << " N_PROGRAMS='#{total_program}' "
      cmd << " MENTOR_REQUEST_STYLE='#{moderated}' "
      cmd << " GROUP_MENTORING='#{group_mentoring}' "
      cmd << " PROGRAM_TYPE='#{program_type}' "
      cmd << " SUBSCRIPTION_STYLE='#{subscription_style}' "
      cmd << " ENGAGEMENT_TYPE='#{engagement_type}' "
      cmd << " db:populate_demo_program --trace"

      run cmd
    end
  end
end
