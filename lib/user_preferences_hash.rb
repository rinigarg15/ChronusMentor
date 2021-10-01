module UserPreferencesHash

  def set_user_preferences_hash(set_ignore_hash=true)
    ups = UserPreferenceService.new(@current_user)
    @favorite_preferences_hash = ups.get_favorite_preferences_hash
    @ignore_preferences_hash = ups.get_ignore_preferences_hash if set_ignore_hash
  end
end