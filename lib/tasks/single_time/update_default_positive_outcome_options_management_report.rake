# More Info : Update default positive_outcome_options_management_report

namespace :single_time do
desc 'update_default_positive_outcome_options_management_report'
  task :update_default_positive_outcome_options_management_report => :environment do
    date = Date.strptime("01/11/2018".strip, MeetingsHelper::DateRangeFormat.call).to_date.end_of_day.utc - 10.hours
    ActiveRecord::Base.transaction do
      Program.active.includes([:translations, :enabled_db_features, :disabled_db_features, organization: [:enabled_db_features, :disabled_db_features], surveys: [:translations, survey_questions: [:translations, rating_questions: [:translations]]]]).each do |program|
        program.surveys.select{|survey| program.only_one_time_mentoring_enabled? ? survey.meeting_feedback_survey? : survey.engagement_survey? }.each do |survey|
          question = survey.survey_questions.find(&:rating_type?)
          if question.present? && question.positive_outcome_options_management_report.present? && question.updated_at < date && question.created_at < date
            question_choices = question.question_info.split(",")
            question_choices_count = question_choices.count
            median_value = (question_choices_count.to_f/2).floor
            positive_outcome_options = question_choices.first(median_value).join(',')
            question.update_column(:positive_outcome_options_management_report, positive_outcome_options)
          end
        end
      end
    end
  end
end