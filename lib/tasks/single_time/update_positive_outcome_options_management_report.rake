# JIRA Ticket: https://chronus.atlassian.net/browse/AP-17247
# More Info : Update default positive_outcome_options_management_report

namespace :single_time do
desc 'update_positive_outcome_options_management_report'
  task :update_positive_outcome_options_management_report => :environment do
    ActiveRecord::Base.transaction do
      Program.active.includes([:translations, :enabled_db_features, :disabled_db_features, organization: [:enabled_db_features, :disabled_db_features], surveys: [:translations, survey_questions: [:translations, rating_questions: [:translations]]]]).each do |program|
        program.surveys.select{|survey| program.only_one_time_mentoring_enabled? ? survey.meeting_feedback_survey? : survey.engagement_survey? }.each do |survey|
          question = survey.survey_questions.find(&:rating_type?)
          if question.present?
            question_choices = question.question_info.split(",")
            question_choices_count = question_choices.count
            median_value = (question_choices_count.to_f/2).ceil
            positive_outcome_options = question_choices.first(median_value).join(',')
            question.update_column(:positive_outcome_options_management_report, positive_outcome_options)
          end
        end
      end
    end
  end
end