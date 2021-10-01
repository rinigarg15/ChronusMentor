require_relative './../../../../../../test_helper'

class RecommendationPreferencePopulatorTest < ActiveSupport::TestCase
  def test_add_remove_recommendation_preferences
    program = programs(:albers)
    mentor_recommendation_ids = program.mentor_recommendations.pluck(:id)
    to_add_mentor_reco_ids = mentor_recommendation_ids.first(5)
    to_remove_mentor_reco_ids = RecommendationPreference.where(mentor_recommendation_id: mentor_recommendation_ids).pluck(:mentor_recommendation_id).uniq.first(5)
    populator_add_and_remove_objects("recommendation_preference", "mentor_recommendation", to_add_mentor_reco_ids, to_remove_mentor_reco_ids, {program: program}) 
  end
end