class ExplicitUserPreferencesController < ApplicationController

  allow exec: :explicit_user_preferences_enabled?
  before_action :populate_preferences_from_match_configs, only: [:new]
  before_action :get_explicit_preference, only: [:update, :destroy, :change_weight]
  before_action :destroy_one_time_flag, only: [:bulk_destroy]
  before_action :get_src

  def new
    @role_questions = @current_program.get_valid_role_questions_for_explicit_preferences
    @existing_questions_data = current_user.explicit_user_preferences.includes(role_question: :profile_question)
    @all_questions_data = get_question_choices_data
    @explicit_preference = ExplicitUserPreference.new
  end

  def create
    @explicit_preference = current_user.explicit_user_preferences.create!(get_params_based_on_action(:create))
  end

  def update
    update_params = get_params_based_on_action(:update)
    @updated_preference_question_choices = preference_question_choices_changed?(update_params)
    @explicit_preference.update_attributes!(update_params)
  end

  def destroy
    @preference_id = @explicit_preference.id
    @explicit_preference.destroy
  end

  def bulk_destroy
    current_user.explicit_user_preferences.destroy_all
  end

  def change_weight
    update_params = get_explicit_preference_params(:change_weight)
    @updated_preference_weight = preference_weight_changed?(update_params)
    @explicit_preference.update_attributes!(update_params)
  end

  private

  def explicit_user_preferences_enabled?
    @current_program.explicit_user_preferences_enabled?
  end

  def get_explicit_preference
    @explicit_preference = current_user.explicit_user_preferences.find(params[:id])
  end

  def get_params_based_on_action(action)
    refined_params = get_explicit_preference_params(action)
    refined_params[:question_choice_ids] = refine_question_choices_param(refined_params[:question_choice_ids]) if refined_params[:question_choice_ids].present?
    refined_params
  end

  def get_explicit_preference_params(action)
    params[:explicit_user_preference].present? ? params[:explicit_user_preference].permit(ExplicitUserPreference::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def destroy_one_time_flag
    if params[:destroy_one_time_flag].present?
      current_user.one_time_flags.where(message_tag: OneTimeFlag::Flags::Popups::EXPLICIT_PREFERENCE_CREATION_POPUP_TAG).destroy_all
    end
  end

  def refine_question_choices_param(question_choice_ids)
    question_choice_ids.split(",").map(&:to_i)
  end

  def get_question_choices_data
    @role_questions.collect do |question|
      { id: question.id,
        text: question.profile_question.question_text,
        choices: question.profile_question.question_choices.collect{|choice| {id: choice.id, text: choice.text}},
        type: question.profile_question.question_type
      }
    end
  end

  def get_src
    @src = params[:src]
    @ga_src = ExplicitUserPreference::GA_SRC.find_index(params[:src])
  end

  def preference_question_choices_changed?(update_params)
    if @explicit_preference.question_choice_ids.present?
      update_params[:question_choice_ids].sort != @explicit_preference.question_choice_ids.sort
    else
      update_params[:preference_string] != @explicit_preference.preference_string
    end
  end

  def preference_weight_changed?(update_params)
    update_params[:preference_weight].to_i != @explicit_preference.preference_weight
  end

  def populate_preferences_from_match_configs
    if !OneTimeFlag.has_tag?(current_user, OneTimeFlag::Flags::Popups::EXPLICIT_PREFERENCE_CREATION_POPUP_TAG) && current_user.explicit_user_preferences.blank?
      ExplicitUserPreference.populate_default_explicit_user_preferences_from_match_configs(current_user, current_program)
      current_user.one_time_flags.create!(message_tag: OneTimeFlag::Flags::Popups::EXPLICIT_PREFERENCE_CREATION_POPUP_TAG)
      @show_help_text_for_default_preferences = true if current_user.reload.explicit_user_preferences.present?
    end
  end
end
