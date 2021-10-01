# bundle exec rake single_time:collect_invalid_choices_in_admin_view
namespace :single_time do
  desc 'Migrate answer_text in ProfileAnswer to AnswerChoice model'
  task :collect_invalid_choices_in_admin_view => :environment do
    CSV.open("/tmp/invalid_choices_in_admin_view.csv", "w") do |csv|
      csv << ["Organization", "Program", "Account Name", "Admin View ID", "Admin View Title", "CommonQuestionId", "CommonQuestionText", "Actual Choices Available", "Invalid Choice Currently Present in Admin View", "All Choices in Admin View", "Is Not Operator"]
      AdminView.includes(:program).where.not(filter_params: nil).find_each do |admin_view|
        filter_params = admin_view.filter_params_hash
        if filter_params && filter_params["survey"] && filter_params["survey"]["survey_questions"]
          filter_params["survey"]["survey_questions"].each do |_key, value|
            if value["question"].present? && value["choice"].present? && [AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s].include?(value["operator"])
              question_id = value["question"].split("answers").last.to_i
              common_question = CommonQuestion.find_by(id: question_id)
              question_info = common_question.question_info if common_question.present?
              next if question_info.blank?
              question_info = question_info.split(",").map(&:strip)
              question_info_lower = question_info.map(&:downcase)
              invalid_choices = []
              choices = value["choice"].split(",").map(&:strip)
              choices.each do |choice|
                if question_info_lower.exclude?(choice.downcase)
                  invalid_choices << choice
                end
              end
              if invalid_choices.present?
                program =  admin_view.program
                organization = (program.is_a?(Organization) ? program : program.organization)
                csv << ["#{organization.name}(#{organization.url})", program.name, organization.account_name, admin_view.id, admin_view.title, common_question.id, common_question.question_text, common_question.question_info, invalid_choices.join(","), choices.join(","), [AdminViewsHelper::QuestionType::NOT_IN.to_s, AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s].include?(value["operator"])]
              end
            end
          end
        end
      end
    end
  end

  # bundle exec rake single_time:collect_invalid_choices_in_positive_outcome_options
  desc "Collect invalid choices in positive outcome options"
  task :collect_invalid_choices_in_positive_outcome_options => :environment do
    CSV.open("/tmp/invalid_choices_in_positive_outcome_options.csv", "w") do |csv|
      csv << ["CommonQuestionId", "Common Question Text", "Program Url", "Account Name", "Actual Choices", "Invalid Choices", "Org Active", "Type", "Survey Name"]
      CommonQuestion.where(question_type: [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE, CommonQuestion::Type::MATRIX_RATING]).where.not(positive_outcome_options: nil).each do |cq|

        question_info = cq.question_info.split(",").map(&:strip)
        question_info_lower = question_info.map(&:downcase)
        invalid_choices = []
        choices = cq.positive_outcome_options.split(",").map(&:strip)
        choices.each do |choice|
          if question_info_lower.exclude?(choice.downcase)
            invalid_choices << choice
          end
        end
        if invalid_choices.present?
          program = cq.program

          csv << [cq.id, cq.question_text, program.url, program.organization.account_name, cq.question_info, choices.join(","), program.organization.active?, cq.type, cq.is_a?(SurveyQuestion) ? cq.survey.name : nil]
        end
      end
    end
  end
end
