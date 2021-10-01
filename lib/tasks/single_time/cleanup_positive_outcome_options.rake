# Usage: bundle exec rake single_time:cleanup_positive_outcome_options

namespace :single_time do
  desc 'Clean up invalid choices in positive outcome options'
  task :cleanup_positive_outcome_options => :environment do
    choice_mapping = {
      # invalid choice => correct choices that can be mapped
      "Very good" => ["Very Satisfied"],
      "Good" => ["Satisfied"],
      "Achieved all my goals" => ["Achieved all her goals", "Achieved all of their goals", "Mentee achieved all goals", "Overcame all of their obstacles", "Strongly agree"],
      "Achieved some of my goals" => ["Achieved some of her goals", "Achieved some of their goals", "Menteee achieved some goals", "Overcame some of their obstacles", "Mostly agree"],
      "Very Satisfied" => ["Strongly agree"],
      "Satisfied" => ["Mostly agree", "Agree"]
    }

    CommonQuestion.where(question_type: [CommonQuestion::Type::SINGLE_CHOICE, CommonQuestion::Type::MULTI_CHOICE, CommonQuestion::Type::RATING_SCALE, CommonQuestion::Type::MATRIX_RATING]).where.not(positive_outcome_options: nil).each do |cq|

      question_info = cq.question_info.split(",").map(&:strip)
      choices = cq.positive_outcome_options.split(",").map(&:strip)
      invalid_choices = choices.collect {|choice| choice unless question_info.include?(choice) }.reject(&:blank?).compact
      to_be_updated_outcome = invalid_choices.collect do |choice|
        if choice_mapping[choice].present? && (mapped_choice = (question_info & choice_mapping[choice])).any?
          mapped_choice[0]
        end
      end.uniq.compact.join(",")
      cq.update_columns(positive_outcome_options: to_be_updated_outcome, skip_delta_indexing: true) if to_be_updated_outcome.present?
    end

  end
end