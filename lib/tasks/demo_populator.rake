#Possible MENTOR_REQUEST_STYLES
# Program::MentorRequestStyle::MENTEE_TO_MENTOR = 0
# Program::MentorRequestStyle::MENTEE_TO_ADMIN  = 1
# Program::MentorRequestStyle::NONE             = 2

#Possible SUBSCRIPTION_STYLES
# Organization::SubscriptionType::BASIC       = 0
# Organization::SubscriptionType::PREMIUM     = 1
# Organization::SubscriptionType::ENTERPRISE  = 2

# Possible MENTORING_MODEL_TYPE
# 0 => Tasks + Facilitation Message
# 1 => Tasks + Facilitation Message + Goals
# 2 => Tasks + Facilitation Message + Goals + Milestones

#Possible PROGRAM_TYPE
# Demo::ProgramType::CORPORATE    =  0
# Demo::ProgramType::EDUCATION     = 1

# Possible ENGAGEMENT_TYPE
# Program::EngagementType::CAREER_BASED   = 1
# Program::EngagementType::PROJECT_BASED  = 2

# Mentor Request Style should be Program::MentorRequestStyle::NONE and Group mentoring should be false if we need subscription_type = Organization::SubscriptionType::BASIC

DEMO_USAGE = "Demo_USAGE: rake db:populate_demo_program NAME=<program name> SUBDOMAIN=<subdomain> N_PROGRAMS=<number of programs> MENTOR_REQUEST_STYLE=(0|1|2) MENTORING_MODEL_TYPE=(0|1|2) GROUP_MENTORING=(true|false) PROGRAM_TYPE=(0|1) SUBSCRIPTION_STYLE=(0|1|2) ENGAGEMENT_TYPE=(1|2) FAKE_LOCATIONS=(true|false) RAILS_ENV=demo SSL_ONLY=(true|false)"

namespace :db do
  desc "Create a new demo program. #{DEMO_USAGE}"
  task :populate_demo_program => :environment do
    require 'faker'
    require 'populator'
    require_relative './../../demo/code/demo_helper'

    ActionMailer::Base.perform_deliveries = false
    reindex_es = true
    ActiveRecord::Base.transaction do
      begin
        Object.send :alias_method, :send_later, :send
        populate_fake_locations if ENV['FAKE_LOCATIONS']

        # TODO abort("Rails env should be demo. #{DEMO_USAGE}") unless Rails.env == 'demo'
        program_name = ENV['NAME'] || raise("Program name not given. #{DEMO_USAGE}")
        program_subdomain = ENV['SUBDOMAIN'] || raise("Program subdomain not given. #{DEMO_USAGE}")
        total_program = ENV['N_PROGRAMS'] || 1
        mentor_request_style = ENV['MENTOR_REQUEST_STYLE']
        mentoring_model_style = (ENV['MENTORING_MODEL_TYPE'] || 2).to_i
        one_to_many_mentoring = (ENV['GROUP_MENTORING'] == 'true')
        subscription_type = ENV['SUBSCRIPTION_STYLE']
        engagement_type = (ENV['ENGAGEMENT_TYPE'] || Program::EngagementType::CAREER_BASED_WITH_ONGOING).to_i
        program_type=ENV['PROGRAM_TYPE'] || 0

        # Overriding some settings for project based track
        if engagement_type == Program::EngagementType::PROJECT_BASED
          mentor_request_style = Program::MentorRequestStyle::NONE
          one_to_many_mentoring = true
        end

        puts "Creating a new demo program (Name: '#{program_name}', Subdomain: '#{program_subdomain}', Total_program: '#{total_program}',Engagement type: #{engagement_type}, Groups Moderated: #{mentor_request_style}, Group mentoring: #{one_to_many_mentoring}), Program type: #{program_type}..."
        # Suspend ES delta indexing on all models. Reindex after population.
        DelayedEsDocument.skip_es_delta_indexing do
          abort("No locations in database. Populate locations and run the demo populator") if Location.count.zero?
          populate_demo_program(program_name.dup, program_subdomain.dup, :total_program => total_program, :mentor_request_style => mentor_request_style, :allow_one_to_many_mentoring => one_to_many_mentoring, :subscription_type => subscription_type, :program_type => program_type, mentoring_model_style: mentoring_model_style, engagement_type: engagement_type)
        end
      rescue => ex
        reindex_es = false
        raise ex
      end
    end
    if reindex_es
      models_list = ChronusElasticsearch.models_with_es.map { |x| x.name}
      ElasticsearchReindexing.indexing_flipping_deleting(models_list)
    end
  end

  private

  def populate_demo_program(name, subdomain, options = {})
    organization = nil
    program = nil
    #options[:theme_css] = Rails.root.to_s + "/themes/global_themes/modern_blue-green.css"
    #options[:theme_name] = "Modern Blue Green"
    total_program = options[:total_program].to_i
    program_name = ["Leadership Development", "Career Development", "Diversity & Inclusion"]
    for i in 4..total_program
      program_name << "Program #{i}"
    end
    for i in 1..total_program
      options[:program_name] = program_name[i-1]
      if i == 1
        program_objects = create_program_and_organization(name, subdomain, i, options)
        program = program_objects[0]
        organization = program_objects[1]
      else
        program = create_program(organization, i, options)
      end
      program.reload
      update_demo_features(program)
      create_users_and_populate_data(program, options)
      
    end
  end

  def create_users_and_populate_data(program, options = {})
    program_type = options[:program_type] || 0
    subscription_type = options[:subscription_type]
    engagement_type = options[:engagement_type]

    # Terminology change for project based track
    if engagement_type == Program::EngagementType::PROJECT_BASED
      update_customized_terms(program, {
        CustomizedTerm::TermType::MENTORING_CONNECTION_TERM => "Project"
      })
    end

    # Create an admin user and set the user as the owner
    admin_objects = create_program_admin(program)
    admin = admin_objects[:user]
    program.set_owner!(admin)
    populate_membership_requests(program, program_type)
    populate_announcements(program)
    populate_invitations(program)
 
    # Create Mentors, Students, Groups
    populate_mentoring_model_templates(program, options[:mentoring_model_style])
    populate_mentors_and_students(program, 10, 20)
    populate_mentor_requests(program)
    populate_groups_between_mentors_and_students(program, subscription_type, 8, engagement_type: engagement_type)

    populate_program_forums(program, program_type)
    populate_program_qa(program)
    populate_program_articles(program, program_type)
    populate_program_survey(program)
    populate_theme(program, options[:theme_name], options[:theme_css])
    if engagement_type == Program::EngagementType::PROJECT_BASED
      populate_pending_groups(program)

      dp = DataPopulator.new
      dp.populate_project_requests(program, 5)
      dp.populate_connection_questions(program, 4)
      dp.populate_connection_answers(program)
    elsif subscription_type == Organization::SubscriptionType::ENTERPRISE.to_s
      populate_availability_slots(program)
    end

    populate_default_campaigns(program)
    puts "*** DONE ***"
  end

  def update_customized_terms(program, term_options = {})
    term_hash = program.customized_terms.where(term_type: term_options.keys).includes(:translations).group_by{|term| term.term_type}
    term_options.each do |term_type, term_val|
      term = term_hash[term_type].first
      term.update_term(term: term_val)
    end
  end

end
