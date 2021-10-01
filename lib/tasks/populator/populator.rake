PERFORMANCE_USAGE = "rake populator:performance NAME='Mentoring Performance' SUBDOMAIN='performance' MENTOR_REQUEST_STYLE=(0|1|2) SUBSCRIPTION_STYLE=(0|1|2) ENGAGEMENT_TYPE=(1|2)"
namespace :populator do
  desc "Create data for performance tests #{PERFORMANCE_USAGE}"
  task performance: :environment do
    require_relative './../../../demo/code/demo_helper'
    require_relative 'data_populator'
    require_relative 'performance_populator'
    require 'faker'
    require 'populator'
    DelayedEsDocument.skip_es_delta_indexing do
      perform_startup_tasks!
      settings = initialize_settings
      # Use the override below for testing the populator with smaller numbers
      # override!(settings)
      PerformancePopulator.new.generate(settings)
    end
    models_list = ChronusElasticsearch.models_with_es.map { |x| x.name}
    ElasticsearchReindexing.indexing_flipping_deleting(models_list)
  end

  private

  def initialize_settings
    settings = {}
    settings[:program_options] = {
      allow_one_to_many_mentoring: true,
      subscription_type: ENV['SUBSCRIPTION_STYLE'] || Organization::SubscriptionType::ENTERPRISE,
      mentor_request_style: ENV['MENTOR_REQUEST_STYLE'] || Program::MentorRequestStyle::MENTEE_TO_MENTOR,
      engagement_type: ENV['ENGAGEMENT_TYPE'] || Program::EngagementType::CAREER_BASED_WITH_ONGOING
    }
    settings[:name] = ENV['NAME'] || raise("Program name not given. #{PERFORMANCE_USAGE}")
    settings[:subdomain] = ENV['SUBDOMAIN'] || raise("Program subdomain not given. #{PERFORMANCE_USAGE}")    
    # Additional Programs in the organization which will contain minimal data
    settings[:additional_programs] = ENV['ADDITIONAL_PROGRAMS'] || 10
    # Users in other programs of the organization
    settings[:additional_users] = ENV['ADDITIONAL_USERS'] || 1000
    # On program creation, 3 sections are created. the below variable is to specify additional sections
    settings[:sections] = ENV['SECTIONS'] || 12
    # On program creation, by default 15 profile questions are created
    settings[:additional_profile_questions] = ENV['ADDITIONAL_PROFILE_QUESTIONS'] || 75
    settings[:mentors] = ENV['MENTORS'] || 40_000
    settings[:students] = ENV['STUDENTS'] || 60_000
    # On program creation, by default 4 milestones are created
    settings[:additional_milestones] = ENV['ADDITIONAL_MILESTONES'] || 8
    settings[:groups] = ENV['GROUPS'] || 40_000
    settings[:mentor_requests] = ENV['MENTOR_REQUESTS'] || 20_000
    settings[:project_requests] = ENV['PROJECT_REQUESTS'] || 10_000
    settings[:qas] = ENV['QAS'] || 6_000
    # Qa Answers per Qa Question
    settings[:qa_answers] = ENV['QA_ANSWERS'] || 1..10
    settings[:articles] = ENV['ARTICLES'] || 10_000
    # Number of comments per article
    settings[:article_comments] = ENV['ARTICLE_COMMENTS'] || 10..15
    settings[:forums] = ENV["FORUMS"] || 5
    # The topics count below will populate the topics for the forum
    settings[:topics] = ENV['TOPICS'] || 10..30
    # Posts per Topic
    settings[:posts] = ENV["POSTS"] || 100..200
    # Subscriptions for the forum
    settings[:forum_subscriptions] = ENV["FORUM_SUBSCRIPTIONS"] || 1_000
    settings[:membership_requests] = ENV['MEMBERSHIP_REQUESTS'] || 20_000
    settings[:resources] = ENV['RESOURCES'] || 50
    settings[:program_invitations] = ENV['PROGRAM_INVITATIONS'] || 50_000
    # By default every program has 5 surveys
    settings[:surveys] = ENV["SURVEYS"] || 50
    # Number of users who should answer a survey question of a particular survey
    settings[:survey_answers] = ENV["SURVEY_ANSWERS"] || 5_000
    # Number of availability slots per mentor
    settings[:availability_slots_per_mentor] = ENV["AVAILABILITY_SLOTS_PER_MENTOR"] || 1
    settings[:spot_meeting_requests] = ENV["SPOT_MENTORING_REQUESTS"] || 20_000
    settings[:admin_messages] = ENV["ADMIN_MESSAGES"] || 50_000
    settings[:inbox_messages] = ENV["INBOX_MESSAGES"] || 50_000
    settings[:program_events] = ENV["PROGRAM_EVENTS"] || 100
    settings[:announcements] = ENV["ANNOUNCEMENTS"] || 100
    settings[:tags] = ENV["TAGS"] || 5000
    settings[:connection_questions] = ENV["CONNECTION_QUESTIONS"] || 10
    settings[:group_interval] = ENV["GROUP_INTERVAL"] || 14
    settings[:group_progress_count] = ENV["GROUP_PROGRESS_COUNT"] || 500
    settings[:task_template_count] = ENV["TASK_TEMPLATE_COUNT"] || 50
    settings[:goal_template_count] = ENV["GOAL_TEMPLATE_COUNT"] || 5
    settings[:milestone_template_count] = ENV["MILESTONE_TEMPLATE_COUNT"] || 10
    settings[:facilitation_template_count] = ENV["FACILITATION_TEMPLATE_COUNT"] || 5
    settings
  end

  def perform_startup_tasks!
    DataPopulator.benchmark_wrapper "prerequsites" do
      ActionMailer::Base.perform_deliveries = false
      Object.send :alias_method, :send_later, :send
      Permission.create_default_permissions
      Feature.create_default_features
      Theme.find_or_create_by(:name =>'Default')
      if Location.count.zero?
        Rake::Task["geo:populate"].invoke
      end
    end
  end

  def override!(settings)
    settings.merge!(
      additional_programs: 1,
      additional_users: 10,
      sections: 5,
      additional_profile_questions: 10,
      mentors: 100,
      students: 200,
      additional_milestones: 5,
      groups: 10,
      mentor_requests: 10,
      project_requests: 5,
      qas: 20,
      qa_answers: 10..10,
      articles: 20,
      article_comments: 5,
      forums: 2,
      topics: 5,
      posts: 20,
      forum_subscriptions: 10,
      membership_requests: 50,
      resources: 10,
      program_invitations: 50,
      surveys: 2,
      survey_answers: 10,
      availability_slots_per_mentor: 1,
      spot_meeting_requests: 10,
      admin_messages: 10,
      inbox_messages: 10,
      program_events: 10,
      announcements: 10,
      tags: 50,
      connection_questions: 2,
      group_interval: 1,
      group_progress_count: 2,
      milestone_template_count: 2,
      task_template_count: 10,
      goal_template_count: 2,
      facilitation_template_count: 2
    )
  end
end