#usage: bundle exec rake single_time:survey_answer_deletion DOMAIN='' SUBDOMAIN='' ROOT='' USER_IDS='' SURVEY_IDS=''
namespace :single_time do
  task survey_answers_deletion: :environment do
    Common::RakeModule::Utils.execute_task do
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOT"])
      program = programs.first
      user_ids = program.users.where(id: ENV['USER_IDS'].split(',')).pluck(:id)
      survey_ids = program.surveys.where(id: ENV['SURVEY_IDS'].split(',')).pluck(:id)
      SurveyAnswer.where(survey_id: survey_ids, user_id: user_ids).destroy_all
    end
  end
end
