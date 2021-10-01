require_relative "./../../test_helper.rb"

class PreferencesHelperTest < ActionView::TestCase
  def test_get_hints_for_favorite_symbol
    mark_favorite = true
    assert_equal "feature.favorite_preference.header.favorite".translate(mentor: _mentor), get_hints_for_favorite_symbol(mark_favorite)
    mark_favorite = false
    assert_equal "feature.favorite_preference.header.unfavorite".translate(mentor: _mentor), get_hints_for_favorite_symbol(mark_favorite)
    mark_favorite = false
    assert_equal "feature.favorite_preference.header.unfavorite".translate(mentor: _mentor), get_hints_for_favorite_symbol(mark_favorite)
  end

  def test_get_favorite_preference_url
    mark_favorite = true
    preference_marked_user_id = 9
    assert_equal favorite_preferences_path({favorite_preference: {preference_marked_user_id: preference_marked_user_id}, src: ""}), get_favorite_preference_url(mark_favorite, "", {preference_marked_user_id: preference_marked_user_id})

    #with src
    assert_equal favorite_preferences_path({favorite_preference: {preference_marked_user_id: preference_marked_user_id}, src: EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE}), get_favorite_preference_url(mark_favorite, EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE, {preference_marked_user_id: preference_marked_user_id})

    mark_favorite = false
    favorite_preference_id = 8
    assert_equal favorite_preference_path(favorite_preference_id, src: EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE), get_favorite_preference_url(mark_favorite, EngagementIndex::Src::AbstractPreference::FAVORITE_LISTING_PAGE, {favorite_preference_id: favorite_preference_id})
    #with src
    assert_equal favorite_preference_path(favorite_preference_id, src: ""), get_favorite_preference_url(mark_favorite, "", {favorite_preference_id: favorite_preference_id})

    mark_favorite = false
    favorite_preference_id = 2
    assert_equal favorite_preference_path(favorite_preference_id, src: ""), get_favorite_preference_url(mark_favorite, "", {favorite_preference_id: favorite_preference_id})
  end

  def test_get_preference_method_type
    preference = true
    assert_equal DELETE_PREFERENCE, get_preference_method_type(preference)

    preference = false
    assert_equal CREATE_PREFERENCE, get_preference_method_type(preference)
  end

  def test_get_ignore_preference_url
    preference = false
    preference_marked_user_id = 9
    assert_equal ignore_preferences_path({ignore_preference: {preference_marked_user_id: preference_marked_user_id}, recommendations_view: true}), get_ignore_preference_url(preference, {preference_marked_user_id: preference_marked_user_id, recommendations_view: true})

    preference = true
    ignore_preference_id = 8
    assert_equal ignore_preference_path(ignore_preference_id, recommendations_view: true), get_ignore_preference_url(preference, {ignore_preference_id: ignore_preference_id, recommendations_view: true})

    preference = true
    ignore_preference_id = 2
    assert_equal ignore_preference_path(ignore_preference_id, recommendations_view: false), get_ignore_preference_url(preference, {ignore_preference_id: ignore_preference_id, recommendations_view: false})
  end

  def test_get_ignored_text
    content = get_ignored_text(true)
    assert_equal "Reconsider", content

    content = get_ignored_text(false)
    assert_equal "Ignore<i class=\"fa fa-lg fa-close m-l-xs\"></i>", content
  end

  def test_not_recommendations_view
    view = AbstractPreference::Source::PROFILE
    assert not_recommendations_view(view)

    view = AbstractPreference::Source::LISTING
    assert not_recommendations_view(view)

    view = AbstractPreference::Source::SYSTEM_RECOMMENDATIONS
    assert_false not_recommendations_view(view)

    view = AbstractPreference::Source::ADMIN_RECOMMENDATIONS
    assert_false not_recommendations_view(view)
  end

  def test_get_ignored_tooltip_text
    content = get_ignored_tooltip_text(true)
    assert_equal 'feature.ignore_preference.tooltip.reconsider_profile'.translate(mentor: _mentor), content

    content = get_ignored_tooltip_text(false)
    assert_equal "feature.ignore_preference.tooltip.ignore_profile".translate(mentor: _mentor), content
  end

  def test_get_icon_content_based_on_request_type
    request_type = UserPreferenceService::RequestType::MEETING
    assert_equal "fa fa-calendar-plus-o", get_icon_content_based_on_request_type(request_type)

    request_type = UserPreferenceService::RequestType::GROUP
    assert_equal "fa fa-user-plus", get_icon_content_based_on_request_type(request_type)
  end

  private

  def _mentor
    "mentor"
  end
end