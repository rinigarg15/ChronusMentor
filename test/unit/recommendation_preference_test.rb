require_relative './../test_helper.rb'

class RecommendationPreferenceTest < ActiveSupport::TestCase

  def test_belongs_to_mentor_recommendation
    recommendation_preference = recommendation_preferences(:recommendation_preference_1)
    mentor_recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_equal mentor_recommendation, recommendation_preference.mentor_recommendation
  end

  def test_belongs_to_preferred_user
    recommendation_preference = recommendation_preferences(:recommendation_preference_1)
    assert_equal users(:ram), recommendation_preference.preferred_user
  end

  def test_destroy_recommendation_with_no_preferences
    recommendation = mentor_recommendations(:mentor_recommendation_1)
    assert_difference "MentorRecommendation.count", -1 do
      recommendation.recommendation_preferences.destroy_all
    end
  end

  def test_es_reindex_for_recommendation_preference
    mentor = users(:f_mentor)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [mentor.id]).once
    preference = RecommendationPreference.create(user_id: mentor.id, mentor_recommendation_id: mentor_recommendations(:mentor_recommendation_1).id)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [mentor.id]).once
    RecommendationPreference.es_reindex(preference)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [mentor.id]).once
    preference.destroy
  end
end