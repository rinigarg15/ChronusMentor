class IgnorePreferencesController < ApplicationController
  include UserPreferencesHash

  allow user: :allowed_to_ignore_and_mark_favorite?
  before_action :get_show_match_config_matches

  def create
    @ignore_preference = current_user.ignore_preferences.find_by(preference_marked_user_id: params[:ignore_preference][:preference_marked_user_id]) || current_user.ignore_preferences.create!(ignore_preference_params(:create))
    @mentor = @ignore_preference.preference_marked_user
    @mentor_name = @ignore_preference.preference_marked_user.name_only
    set_user_preferences_and_recommendations
    track_activity_for_ei(EngagementIndex::Activity::MARK_AS_IGNORE, context_place: @recommendations_view)
  end

  def destroy
    ignore_preference = current_user.ignore_preferences.find(params[:id])
    @mentor = ignore_preference.preference_marked_user
    ignore_preference.destroy! if ignore_preference.present?
    set_user_preferences_and_recommendations
    set_match_score
    set_show_compatibility_link_variables
    @slide_down = params[:slide_down].to_s.to_boolean
    track_activity_for_ei(EngagementIndex::Activity::UNMARK_AS_IGNORE, context_place: @recommendations_view)
  end

  private

  def ignore_preference_params(action)
    params.require(:ignore_preference).permit(AbstractPreference::MASS_UPDATE_ATTRIBUTES[action])
  end

  def get_show_match_config_matches
    @show_match_config_matches = params[:show_match_config_matches].to_s.to_boolean
  end

  def set_user_preferences_and_recommendations
    set_user_preferences_hash
    @recommendations_view = params[:recommendations_view]
    recommendation_type = (@recommendations_view == AbstractPreference::Source::SYSTEM_RECOMMENDATIONS) ? MentorRecommendationsService::RecommendationCategory::SYSTEM_RECOMMENDATIONS : MentorRecommendationsService::RecommendationCategory::EXPLICIT_PREFERENCE_RECOMMENDATIONS
    @mentors_list = MentorRecommendationsService.new(current_user).get_recommendations(recommendation_type) if (@recommendations_view == AbstractPreference::Source::SYSTEM_RECOMMENDATIONS || @recommendations_view == AbstractPreference::Source::EXPLICIT_PREFERENCES_RECOMMENDATIONS)
  end

  def set_match_score
    @match_score = current_user.get_student_cache_normalized[@mentor.id]
  end

  def set_show_compatibility_link_variables
    match_view = current_user.can_send_mentor_request? || @current_program.calendar_enabled?
    @show_compatibility_link = match_view && current_user.can_see_match_details_of?(@mentor, show_match_config_matches: @show_match_config_matches) && !(@match_score.blank? || @match_score.zero?)
  end
end