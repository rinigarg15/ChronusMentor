# Methods are intentionally encapsulated by GlobalizationUtils.run_in_locale(I18n.default_locale) to reduce performance implications.

module ChoicesUpdateHandler

  module Common
    def compact_single_choice_answer_choices(answers, ignore_allow_other_option = false)
      # ignore_allow_other_option is to support RATING_SCALE questions
      return if self.allow_other_option? && !ignore_allow_other_option

      question_choices = self.default_choices
      answers.each do |answer|
        unless question_choices.include?(answer.answer_value(self))
          answer.destroy
        end
      end
    end

    def compact_multi_choice_answer_choices(answers, options_limit = nil)
      # options_limit is to support ORDERED_OPTIONS questions
      return if self.allow_other_option? && options_limit.nil?

      question_choices = self.default_choices
      answers.each do |answer|
        # single choice -> multi choice conversion is also handled here
        # converting to array for safety
        current_choices = Array(answer.answer_value(self))
        new_choices = self.allow_other_option? ? current_choices : (current_choices & question_choices)
        new_choices = new_choices[0..(options_limit - 1)] if options_limit.present?

        next if new_choices.size == current_choices.size
        update_or_destroy_answer_for_compact_mutli_choice(answer, new_choices)
      end
    end

    private

    def update_or_destroy_answer_for_compact_mutli_choice(answer, new_choices)
      if new_choices.size > 0
        answer.answer_value = {answer_text: new_choices, question: self}
        answer.save!
      else
        answer.destroy
      end
    end
  end

  module ProfileQuestion
    include Common

    def compact_answers_for_ordered_options_to_single_choice_conversion(answers)
      question_choices = self.default_choices
      answers.each do |answer|
        current_choices = answer.selected_choices(self, order: true)
        new_choice  = if self.allow_other_option?
                        current_choices[0]
                      else
                        current_choices.find { |current_choice| question_choices.include?(current_choice) }
                      end

        if new_choice.present?
          answer.answer_value = {answer_text: new_choice, question: self}
          answer.save!
        else
          answer.destroy
        end
      end
    end

    def compact_answers_for_ordered_options_to_multi_choice_conversion(answers)
      question_choices = self.default_choices
      answers.each do |answer|
        current_choices = answer.selected_choices(self, order: true)
        new_choices = if self.allow_other_option?
                        current_choices
                      else
                        current_choices & question_choices
                      end

        if new_choices.size > 0
          answer.answer_value = {answer_text: new_choices, question: self}
          answer.save!
        else
          answer.destroy
        end
      end
    end
  end
end