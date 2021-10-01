class MigrateSurveyFiltersInAdminViewToQuestionChoices< ActiveRecord::Migration[4.2]
  def up
    invalid_choices = {}

    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        AdminView.where.not(filter_params: nil).find_each do |admin_view|
          filter_params = admin_view.filter_params_hash
          if filter_params && filter_params["survey"] && filter_params["survey"]["survey_questions"]
            filter_params["survey"]["survey_questions"].each do |key, value|
              if value["question"].present? && value["choice"].present? && [AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s].include?(value["operator"])

                question_id = value["question"].split("answers").last.to_i
                common_question = CommonQuestion.find_by(id: question_id)
                next if common_question.blank?

                common_question = common_question.matrix_question if common_question.matrix_question_id.present?
                qcs = QuestionChoice.includes(:translations).where(ref_obj_type: CommonQuestion.name, ref_obj_id: common_question.id, is_other: false)

                next if qcs.blank?
                qc_text_hash = {}
                qcs.each do |qc|
                  qc.translations.each do |qct|
                    qc_text_hash[qct.text.downcase] = qc.id
                  end
                end
                choice_arr = []
                choices_for_match = []
                value["choice"].split(",").map(&:strip).reject(&:blank?).each do |choice|
                  choice_id = qc_text_hash[choice.downcase]
                  if choice_id.present?
                    choice_arr << choice_id
                  else
                    choices_for_match << choice
                  end
                end

                filter_params["survey"]["survey_questions"][key]["choice"] = choice_arr.join(",")

                if choices_for_match.any?
                  invalid_choices[admin_view.id] ||= {}
                  invalid_choices[admin_view.id][key] ||= {}
                  invalid_choices[admin_view.id][key][question_id] = choices_for_match
                end
              end
            end
            admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
            admin_view.save!
          end
        end
      end
    end
    if invalid_choices.present?
      puts "Invalid Choices: #{invalid_choices}"
      Airbrake.notify(invalid_choices)
    end
  end

  def down
    ChronusMigrate.data_migration do
      invalid_choices = {}
      ActiveRecord::Base.transaction do
        AdminView.where.not(filter_params: nil).find_each do |admin_view|
          filter_params = admin_view.filter_params_hash
          if filter_params && filter_params["survey"] && filter_params["survey"]["survey_questions"]
            filter_params["survey"]["survey_questions"].each do |key, value|
              if value["question"].present? && value["choice"].present? && [AdminViewsHelper::QuestionType::WITH_VALUE.to_s, AdminViewsHelper::QuestionType::NOT_WITH_VALUE.to_s, AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s].include?(value["operator"])

                question_id = value["question"].split("answers").last.to_i
                common_question = CommonQuestion.find_by(id: question_id)
                next if common_question.blank?

                common_question = common_question.matrix_question if common_question.matrix_question_id.present?
                qcs = QuestionChoice.includes(:translations).where(ref_obj_type: CommonQuestion.name, ref_obj_id: common_question.id, is_other: false)

                next if qcs.blank?
                qc_ids_hash = {}
                qcs.each do |qc|
                  qc_ids_hash[qc.id.to_s] = qc.text
                end

                value_arr = []
                value["choice"].split(",").each do |choice|
                  if qc_ids_hash[choice].present?
                    value_arr << qc_ids_hash[choice]
                  else
                    invalid_choices[admin_view.id] ||= {}
                    invalid_choices[admin_view.id][key] ||= {}
                    invalid_choices[admin_view.id][key][question_id] ||= []
                    invalid_choices[admin_view.id][key][question_id] << choice
                  end
                end
                filter_params["profile"]["questions"][key]["choice"] = value_arr.join(",")
              end
            end
            admin_view.filter_params = AdminView.convert_to_yaml(filter_params)
            admin_view.save!
          end
        end
      end
      if invalid_choices.present?
        puts "Invalid Choices: #{invalid_choices}"
        Airbrake.notify(invalid_choices)
      end
    end
  end
end
