module QuestionChoiceExtensions
  SELECT2_SEPARATOR = "/~"
  SEPERATOR = ","

  attr_accessor :reindex_matching

  module ClassMethods
    def split_by_separator(string)
      string.split(SEPERATOR, -1)
    end

    def zip_arrays_to_hash(arr1, arr2)
      Hash[arr1.zip(arr2)]
    end
  end

  module InstanceMethods

    # Used in profile filters and admin views. This returns a english => current_locale hash . This can be enhanced to id => choices in the future
    def values_and_choices
      question_choices = self.default_choice_records
      values = question_choices.collect(&:id)
      choices = question_choices.collect(&:text)
      self.class.zip_arrays_to_hash(values, choices)
    end

    def default_choices
      question = get_question
      if question.question_choices.loaded?
        question.question_choices.select{|qc| !qc.is_other }.collect(&:text)
      else
        question.default_question_choices.collect(&:text)
      end
    end

    def default_choice_records
      question = get_question
      if question.question_choices.loaded?
        question.question_choices.select{|qc| !qc.is_other }
      else
        question.default_question_choices
      end
    end

    def other_choice_records
      if self.question_choices.loaded?
        self.question_choices.select{|qc| qc.is_other }
      else
        self.question_choices.other_choices
      end
    end

    def all_choices
      self.question_choices.collect(&:text)
    end

    def create_other_question_choice!(text)
      if text.present? && self.allow_other_option
        position = self.question_choices.maximum(:position) + 1
        self.question_choices.create!(text: text, is_other: true, position: position)
      end
    end

    def update_question_choices!(params)
      return true unless self.choice_or_select_type?
      return true unless params.present?
      question_choice_error_handling(params[:existing_question_choices_attributes])
      question_choices_params = params[:existing_question_choices_attributes][0]
      new_order = params[:question_choices][:new_order].split(",")
      self.reindex_matching = false
      new_question_choices = modify_question_choices(question_choices_params, new_order)
      update_other_choices!(new_question_choices)
      self.delta_index_matching if self.reindex_matching
      return true
    end

    def delta_index_matching
      return unless self.is_a?(ProfileQuestion)
      programs = self.organization.programs.active
      programs.each do |program|
        Matching.perform_program_delta_index_and_refresh_later(program) if self.has_match_configs?(program)
      end
    end

    def get_question
      return self.matrix_question if self.is_a?(CommonQuestion) && self.try(:matrix_question_id)
      return self
    end

    private

    def modify_question_choices(question_choices_params, new_order)
      question_choices_arr = self.question_choices.to_a
      question_choices_params.to_h.collect do |id, choice_params|
        params_text = choice_params["text"].strip
        params_text.gsub!(/\n|\r\n?/, " ")
        question_choice = find_question_choice(question_choices_arr, id, params_text)
        question_choice = self.question_choices.new unless question_choice # Do not use question_choices_arr directly.
        question_choice.text = params_text
        question_choice.position = new_order.index(id) + 1
        question_choice.is_other = false
        save_question_choice!(question_choice)
        question_choice
      end
    end

    def find_question_choice(question_choices_arr, id, params_text)
      question_choices_arr.find{|choice| choice.id.to_s == id || (choice.is_other? && choice.text.downcase == params_text.downcase)}
    end

    def save_question_choice!(question_choice)
      begin
        if question_choice.changed? || question_choice.new_record?
          self.reindex_matching ||= can_reindex_matching?(question_choice)
          question_choice.save!
        end
      rescue ActiveRecord::RecordInvalid => e
        choice_text = "\"#{question_choice.text}\" " if question_choice.text.present?
        self.errors.add(:question_choices, choice_text.to_s + question_choice.errors.full_messages.to_sentence)
        raise e
      end
    end

    def can_reindex_matching?(question_choice)
      (question_choice.ref_obj_type == ProfileQuestion.name) && !question_choice.new_record? && question_choice.text_changed?
    end

    def update_other_choices!(new_question_choices)
      deleted_choices = self.question_choices.to_a - new_question_choices
      position = self.question_choices.size
      deleted_choices.each do |choice|
        if self.allow_other_option? && choice.answer_choices.present?
          choice.is_other = true
          choice.position = position
          save_question_choice!(choice)
        else
          self.reindex_matching = true if choice.ref_obj_type == ProfileQuestion.name
          choice.destroy
        end
      end
    end

    def question_choice_error_handling(sent_question_choices)
      if sent_question_choices.blank? || sent_question_choices[0].keys.size == 1 && sent_question_choices[0].values[0]["text"].blank?
        self.errors.add(:question_choices, error_message_for_question_choices)
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end

    def error_message_for_question_choices
      return "feature.profile_customization.content.choices_blank".translate if self.is_a?(CommonQuestion) || self.choice_based?
      return "feature.profile_customization.content.choices_blank_ordered".translate
    end
  end

  # INCLUDED function
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end