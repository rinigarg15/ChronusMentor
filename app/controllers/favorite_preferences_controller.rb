class FavoritePreferencesController < ApplicationController
  include UserListingExtensions
  include UserSearch

  allow user: :allowed_to_ignore_and_mark_favorite?
  before_action :set_source, only: [:create, :destroy]

  def create
    favorite_preference = current_user.favorite_preferences.find_by(preference_marked_user_id: params[:favorite_preference][:preference_marked_user_id])
    unless favorite_preference.present?
      favorite_preference = current_user.favorite_preferences.create!(favorite_preference_params(:create))
      track_activity_for_ei(EngagementIndex::Activity::MARK_AS_FAVORITE, context_place: @src)
      @favorite_preference_created = true
    end
    set_mentor_details(favorite_preference)
    set_ignore_and_favorite_hash
    set_mentor_lisiting_vars if @src == EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE
  end

  def destroy
    favorite_preference = current_user.favorite_preferences.find(params[:id])
    set_mentor_details(favorite_preference)
    favorite_preference.destroy! if favorite_preference.present?
    set_ignore_and_favorite_hash
    set_mentor_lisiting_vars if @src == EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE
    track_activity_for_ei(EngagementIndex::Activity::UNMARK_AS_FAVORITE, context_place: @src)
  end

  def index
    @back_link = {link: session[:back_url]}
    set_ignore_and_favorite_hash
    set_mentor_lisiting_vars
    track_activity_for_ei(EngagementIndex::Activity::VIEW_FAVORITES)
  end

  private

  def set_mentor_details(favorite_preference)
    @mentor_name = favorite_preference.preference_marked_user.name_only
    @mentor_id = favorite_preference.preference_marked_user_id
  end

  def set_source
    @src = params[:src]
  end

  def favorite_preference_params(action)
    params.require(:favorite_preference).permit(AbstractPreference::MASS_UPDATE_ATTRIBUTES[action])
  end

  def set_ignore_and_favorite_hash
    ups = UserPreferenceService.new(@current_user)
    @favorite_preferences_hash = ups.get_favorite_preferences_hash
    @ignore_preferences_hash = ups.get_ignore_preferences_hash
  end

  def set_mentor_lisiting_vars
    @role = RoleConstants::MENTOR_NAME
    @favorite_users = @current_user.valid_favorite_users
    @student_document_available = @current_user.present? && @current_user.student_document_available?
    @match_results = @current_user.student_cache_normalized
    @viewer_role = @current_user.get_priority_role if !!@current_user
    user_ids = @favorite_users.collect(&:id)
    defined?(initialize_mentor_actions_for_users) ? initialize_mentor_actions_for_users(user_ids) : User.initialize_mentor_actions_for_users(user_ids)
    initialize_filterable_and_summary_questions
    initialize_role_specific_values
  end
end