module AnswerChoiceQuery
  SEPERATOR = ", "
  DELIMITOR = " | "

  attr_accessor :invalid_choice

  module ClassMethods
    def update_answer_text(answer, question_choice, is_destroy = false, is_choice_based = false)
      return unless is_choice_based
      qc_ids = answer.answer_choices.collect(&:question_choice_id)
      qc_ids -= [question_choice.id] if is_destroy
      question = answer.get_question
      answer_texts = question.question_choices.select{|qc| qc.id.in?(qc_ids)}.collect(&:text)
      answer_text_str = answer_texts.join(answer.get_answer_seperator(question))
      answer.update_columns(answer_text: answer_text_str, skip_delta_indexing: true)
    end

    def destroy_answer_choices(answer, question_choice, is_destroy)
      return unless is_destroy
      answer_choices = answer.answer_choices
      choices_to_be_deleted = answer_choices.select{|ac| ac.question_choice_id == question_choice.id}
      # On deleting all answer choices, its corresponding profile answer also will be deleted. So elasticsearch reindexing will be handled in profile answer after destroy.
      skip_reindex = (answer_choices.collect(&:id) - choices_to_be_deleted.collect(&:id)).empty?
      choices_to_be_deleted.each(&:destroy)
      return skip_reindex
    end
  end

  module InstanceMethods
    def get_question
      return self.profile_question if self.is_a?(ProfileAnswer)
      return self.common_question
    end

    def get_matrix_question(question = nil)
      question ||= get_question
      if question.try(:matrix_question_id)
        question = question.matrix_question
      end
      question
    end

    def get_answer_seperator(question = get_question)
      return DELIMITOR if question.try(:ordered_options_type?)
      return SEPERATOR if question.choice_based?
    end

    def answer_value_for_choice_or_select_type(question)
      value = selected_choices(question)
      question.single_option_choice_based? ? value.first : value
    end

    def selected_choices_to_str(question = get_question)
      choices = self.answer_value(question)
      if question.choice_or_select_type?
        Array(choices).flatten.join_by_separator(SEPERATOR)
      else
        Array(choices).flatten.join(SEPERATOR)
      end
    end
 
    # Options: # collect_records is used to return question choice objects. By default texts will be returned.
    # default_choices: to return default question choices
    # other_choices: to return other question choices
    def selected_choices(question = nil, options = {})
      question ||= get_question
      return [] if options[:other_choices].present? && !question.allow_other_option?
      qc_ids = self.answer_choices.collect(&:question_choice_id)
      qcs = filter_question_choices_based_on_option(question, qc_ids, options)
      return qcs if options[:collect_records]
      if question.try(:ordered_options_type?) || options[:order].present?
        return selected_ordered_choices(qcs, qc_ids)
      end
      qcs.collect(&:text).reject(&:blank?)
    end

    def selected_ordered_choices(qcs, qc_ids)
      qc_ids_hash = qcs.index_by(&:id)
      # same question choice can be mapped to answer choices in different positions
      qc_ids.collect {|qc_id| qc_ids_hash[qc_id].text if qc_ids_hash[qc_id] }.reject(&:blank?)
    end

    def filter_question_choices_based_on_option(question, qc_ids, options = {})
      question = get_matrix_question(question)
      qcs = if question.question_choices.loaded?
              question.question_choices.select {|qc| qc_ids.include?(qc.id) }
            else
              question.question_choices.where(id: qc_ids)
            end
      return qcs.select{|qc| !qc.is_other? } if options[:default_choices]
      return qcs.select{|qc| qc.is_other? } if options[:other_choices]
      return qcs
    end

    # Takes in either a string, array or Hash. If the answer_texts is a string and then needs to be split by comma then from_import should be passed as true.
    def choices_to_a(answer_texts, question = get_question, from_import = false)
      return [] if answer_texts.blank?
      case answer_texts
      when Hash
        answer_texts.values.flatten.map(&:strip).reject(&:blank?)
      when String
        string_choices_to_a(answer_texts, question, from_import)
      when Array
        answer_texts.flatten.map(&:strip).reject(&:blank?)
      else
        answer_texts
      end
    end

    def string_choices_to_a(answer_texts, question, from_import = false)
      # To handle choice having comma
      answer_texts.split_by_comma(!from_import || question.single_option_choice_based?)
    end

    def create_or_delete_answer_choices(answer_texts, question = get_question, from_import = false)
      answer_texts = choices_to_a(answer_texts, question, from_import)
      return delete_residue_answer_choices if answer_texts.blank?
      answer_texts = compact_choices(answer_texts, question)
      self.answer_text = answer_texts.join(get_answer_seperator(question))
      ac_ids = create_answer_choices(question, answer_texts)
      return if self.invalid_choice
      delete_residue_answer_choices(ac_ids.compact)
    end

    def create_answer_choices(question, answer_texts)
      ac_ids = []
      position = 0
      self.invalid_choice = false
      question = get_matrix_question(question)
      default_choices_hash, other_choices_hash = build_choices_hash(question)
      answer_texts.each do |text|
        question_choice = find_or_create_question_choice!(text, question, default_choices_hash, other_choices_hash)
        if question_choice.blank?
          # validation will fail if the choice is invalid.
          self.invalid_choice = true
          break
        end
        ac_ids << find_or_initialize_answer_choice(question_choice, position)
        position += 1 if question.try(:ordered_options_type?)
      end
      ac_ids
    end

    def find_or_create_question_choice!(text, question, default_choices_hash, other_choices_hash)
      question_choice = default_choices_hash[text]
      question_choice ||= other_choices_hash[text]
      question_choice ||= question.create_other_question_choice!(text)
      other_choices_hash[text] = question_choice unless default_choices_hash[text] || other_choices_hash[text]
      question_choice
    end

    def build_choices_hash(question)
      default_choices_hash = {}
      other_choices_hash = {}
      question.question_choices.each do |qc|
        if qc.is_other?
          other_choices_hash[qc.text] = qc
        else
          default_choices_hash[qc.text] = qc
        end
      end
      [default_choices_hash, other_choices_hash]
    end

    def compact_choices(answer_texts, question)
      return answer_texts unless question.allow_other_option?
      compacted_answer_texts = []
      choice_question = get_matrix_question(question)
      answer_texts.each do |answer_text|
        if choice_question.default_choices.include?(answer_text)
          compacted_answer_texts << answer_text
        else
          compacted_answer_texts += compact_other_choices(answer_text, question)
        end
      end
      compacted_answer_texts
    end

    def compact_other_choices(other_text, question)
      return [] if other_text.blank? || !question.allow_other_option?
      # Only for MULTI_CHOICE type, other texts will be split by comma. For other types, it will be taken as it is.
      if question.multi_choice_type?
        other_text.split(COMMA_SEPARATOR).map(&:strip).reject(&:blank?)
      else
        [other_text.strip]
      end
    end

    def find_or_initialize_answer_choice(question_choice, position = 0)
      if question_choice.present?
        answer_choice = find_answer_choice(question_choice, position)
        return answer_choice.id if answer_choice.present?
        # answer choices will be auto-saved when profile answer gets saved.
        self.answer_choices.build(question_choice_id: question_choice.id, position: position, ref_obj: self)
        return
      end
    end

    def find_answer_choice(question_choice, position = 0)
      if self.answer_choices.loaded?
        self.answer_choices.find {|ac| ac.question_choice_id == question_choice.id && ac.position == position}
      else
        self.answer_choices.find_by(question_choice_id: question_choice.id, position: position)
      end
    end

    def delete_residue_answer_choices(ac_ids = [])
      return if self.new_record?
      if ac_ids.blank?
        self.answer_choices.reject(&:new_record?).map(&:mark_for_destruction)
      else
        self.answer_choices.select{|ac| ac.id.present? && ac_ids.exclude?(ac.id)}.map(&:mark_for_destruction)
      end
    end

    def get_options_from_value(value)
      if value.is_a?(Hash) && value.has_key?(:answer_text)
        question = value[:question]
        from_import = value[:from_import]
        value = value[:answer_text]
      end
      [question || get_question, from_import || false, value]
    end
  end

  # INCLUDED function
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end