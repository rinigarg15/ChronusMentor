class PreferenceBasedMentorListsRecommendationService
  MAX_LISTS_TO_DISPLAY = 10

  attr_accessor :mentee, :program, :mentor_lists, :ignored_mentor_lists

  def initialize(mentee)
    @mentee = mentee
    @ignored_mentor_lists = mentee.preference_based_mentor_lists.ignored
    @program = mentee.program
    @mentor_lists = []
    build_mentor_lists
  end

  def has_recommendations?
    mentor_lists.any?
  end

  def get_ordered_lists
    mentor_lists.sort_by{|list| -list.weight}.first(MAX_LISTS_TO_DISPLAY)
  end

  private

  def build_mentor_lists
    if mentee.explicit_preferences_configured?
      set_mentor_lists_from_explicit_preferences
    else
      set_mentor_lists_from_match_configs
    end
    self.mentor_lists = PreferenceBasedMentorList.select_mentor_lists_meeting_criteria(mentor_lists, program.mentor_users.active.pluck(:member_id))
    self.mentor_lists.reject!{|ml| is_ignored?(ml)}
  end

  def set_mentor_lists_from_explicit_preferences
    mentee.explicit_user_preferences.includes({question_choices: [:translations], role_question: [{profile_question: [:translations, :question_choices]}]}).each do |preference|
      if preference.location_type?
        add_location_to_mentor_lists(preference.preference_string, preference.weight_scaled_to_one, preference.profile_question)
      else
        add_question_choices_to_mentor_lists(preference.question_choices, preference.weight_scaled_to_one, preference.profile_question)
      end
    end
  end

  def set_mentor_lists_from_match_configs
    GlobalizationUtils.run_in_locale(I18n.default_locale) do
      MatchConfig.get_match_configs_of_filterable_mentor_questions_for_mentee(mentee, program).each do |match_config|
        location_or_choices = match_config.get_mentor_location_or_questions_choices_for(mentee)
        if location_or_choices.is_a?(String)
          add_location_to_mentor_lists(location_or_choices, match_config.weight, match_config.mentor_profile_question)
        else
          add_question_choices_to_mentor_lists(location_or_choices, match_config.weight, match_config.mentor_profile_question)
        end
      end
    end
  end

  def add_location_to_mentor_lists(location_string, weight, profile_question)
    country, state, city = location_string.split(Location::FULL_LOCATION_SPLITTER).reverse
    location = Location.find_first_reliable_location_with(city, state, country)
    mentor_lists << PreferenceBasedMentorList.new(ref_obj: location, weight: weight, profile_question: profile_question) if location.present?
  end

  def add_question_choices_to_mentor_lists(question_choices, weight, profile_question)
    question_choices.each {|qc| mentor_lists << PreferenceBasedMentorList.new(ref_obj: qc, weight: weight, profile_question: profile_question)}
  end

  def is_ignored?(mentor_list)
    (mentor_list.type == Location.name) ? is_location_ignored?(mentor_list) : is_question_choice_ignored?(mentor_list)
  end

  def is_location_ignored?(mentor_list)
    ignored_mentor_lists.find{|ml| (ml.type == Location.name) && (ml.ref_obj.full_city == mentor_list.ref_obj.full_city) && (ml.profile_question == mentor_list.profile_question)}.present?
  end

  def is_question_choice_ignored?(mentor_list)
    ignored_mentor_lists.find{|ml| (ml.type == QuestionChoice.name) && (ml.ref_obj == mentor_list.ref_obj) && (ml.profile_question == mentor_list.profile_question)}.present?
  end
end