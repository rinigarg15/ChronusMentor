module PreferencesHelper
 
  def get_hints_for_favorite_symbol(mark_favorite)
    mark_favorite ? "feature.favorite_preference.header.favorite".translate(mentor: _mentor) : "feature.favorite_preference.header.unfavorite".translate(mentor: _mentor)
  end

  def get_favorite_preference_url(mark_favorite, src, options={})
    mark_favorite ? favorite_preferences_path({favorite_preference: {preference_marked_user_id: options[:preference_marked_user_id]}, src: src}) : favorite_preference_path(options[:favorite_preference_id], src: src)
  end

  def get_preference_method_type(preference)
    preference ? DELETE_PREFERENCE : CREATE_PREFERENCE
  end

  def get_ignore_preference_url(mentor_ignored, options={})
    mentor_ignored ? ignore_preference_path(options[:ignore_preference_id], recommendations_view: options[:recommendations_view], show_match_config_matches: options[:show_match_config_matches]) : ignore_preferences_path({ignore_preference: {preference_marked_user_id: options[:preference_marked_user_id]}, recommendations_view: options[:recommendations_view], show_match_config_matches: options[:show_match_config_matches]})
  end

  def get_ignored_text(mentor_ignored)
    ignored_text = mentor_ignored ? 'feature.ignore_preference.label.Reconsider'.translate : "feature.membership_request.label.ignore".translate + content_tag(:i, "", :class => "fa fa-lg fa-close m-l-xs")
    ignored_text.html_safe
  end

  def get_ignored_tooltip_text(mentor_ignored)
    ignored_tooltip_text = mentor_ignored ? 'feature.ignore_preference.tooltip.reconsider_profile'.translate(mentor: _mentor) : "feature.ignore_preference.tooltip.ignore_profile".translate(mentor: _mentor)
    ignored_tooltip_text.html_safe
  end

  def not_recommendations_view(view)
    [AbstractPreference::Source::PROFILE, AbstractPreference::Source::LISTING].include?(view)
  end

  def get_icon_content_based_on_request_type(request_type)
    request_type == UserPreferenceService::RequestType::MEETING ? "fa fa-calendar-plus-o" : "fa fa-user-plus"
  end
end