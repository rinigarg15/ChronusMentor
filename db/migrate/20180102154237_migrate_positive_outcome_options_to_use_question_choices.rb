class MigratePositiveOutcomeOptionsToUseQuestionChoices< ActiveRecord::Migration[4.2]
  def up
    invalid_choices = {}
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        common_questions = CommonQuestion.where(question_type: [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE, CommonQuestion::Type::MATRIX_RATING]).where("positive_outcome_options IS NOT NULL OR positive_outcome_options_management_report IS NOT NULL")
        qcs = QuestionChoice.includes(:translations).where(ref_obj_type: CommonQuestion.name, ref_obj_id: common_questions.collect(&:id) + common_questions.collect(&:matrix_question_id), is_other: false)
        choices_hash = {}
        qcs.each do |qc|
          choices_hash[qc.ref_obj_id] ||= {}
          qc.translations.each do |qct|
            choices_hash[qc.ref_obj_id][qct.text.downcase] = qc.id
          end
        end
        common_questions.each do |common_question|
          question = common_question.matrix_question_id.present? ? common_question.matrix_question : common_question
          question_choices = choices_hash[question.id]
          next if question_choices.blank?
          positive_outcome_options = common_question.positive_choices.map(&:strip).reject(&:blank?)
          update_positive_outcome_options!(common_question, :positive_outcome_options, invalid_choices, question_choices, positive_outcome_options, true)

          positive_outcome_options_mgmt_report = common_question.positive_choices(true).map(&:strip).reject(&:blank?)
          update_positive_outcome_options!(common_question, :positive_outcome_options_management_report, invalid_choices, question_choices, positive_outcome_options_mgmt_report, true)
        end
      end
    end
    if invalid_choices.present?
      puts "Invalid Choices For Positive Outcomes Options: #{invalid_choices}"
      Airbrake.notify(invalid_choices)
    end
  end

  def update_positive_outcome_options!(common_question, column_name, invalid_choices, question_choices, outcome_options_arr, for_up = false)

    updated_outcome_options = outcome_options_arr.collect do |opt|
      downcased_opt = for_up ? opt.downcase : opt
      if question_choices[downcased_opt]
        question_choices[downcased_opt]
      else
        invalid_choices[common_question.id] ||= {}
        invalid_choices[common_question.id][column_name] ||= []
        invalid_choices[common_question.id][column_name] << opt
        nil
      end
    end.compact.join(",")
    common_question.update_columns(column_name => updated_outcome_options, skip_delta_indexing: true) if updated_outcome_options.present?
  end

  def down
    invalid_choices = {}
    ChronusMigrate.data_migration do
      ActiveRecord::Base.transaction do
        common_questions = CommonQuestion.where(question_type: [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE, CommonQuestion::Type::MATRIX_RATING]).where("positive_outcome_options IS NOT NULL OR positive_outcome_options_management_report IS NOT NULL")
        qcs = QuestionChoice.includes(:translations).where(ref_obj_type: CommonQuestion.name, ref_obj_id: common_questions.collect(&:id) + common_questions.collect(&:matrix_question_id), is_other: false)
        choices_hash = {}
        qcs.each do |qc|
          choices_hash[qc.ref_obj_id] ||= {}
          choices_hash[qc.ref_obj_id][qc.id] = qc.text
        end
        common_questions.each do |common_question|
          question = common_question.matrix_question_id.present? ? common_question.matrix_question : common_question
          question_choices = choices_hash[question.id]

          next if question_choices.blank?
          positive_outcome_options = common_question.positive_outcome_options.split(",").map(&:strip).reject(&:blank?).map(&:to_i)
          update_positive_outcome_options!(common_question, :positive_outcome_options, invalid_choices, question_choices, positive_outcome_options)

          positive_outcome_options_mgmt_report = common_question.positive_outcome_options_management_report.split(",").map(&:strip).reject(&:blank?).map(&:to_i)
          update_positive_outcome_options!(common_question, :positive_outcome_options_management_report, invalid_choices, question_choices, positive_outcome_options_mgmt_report)
        end
      end
    end
    if invalid_choices.present?
      puts "Invalid Choices For Positive Outcomes Options: #{invalid_choices}"
      Airbrake.notify(invalid_choices)
    end
  end
end
