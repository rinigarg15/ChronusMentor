class AddIndexToMentorRecommendationsAndRecommendationPreference< ActiveRecord::Migration[4.2]
  def up
    add_index :mentor_recommendations, :program_id
    add_index :mentor_recommendations, :sender_id
    add_index :mentor_recommendations, :receiver_id
    add_index :recommendation_preferences, :user_id
    add_index :recommendation_preferences, :mentor_recommendation_id
  end

  def down
    remove_index :mentor_recommendations, :program_id
    remove_index :mentor_recommendations, :sender_id
    remove_index :mentor_recommendations, :receiver_id
    remove_index :recommendation_preferences, :user_id
    remove_index :recommendation_preferences, :mentor_recommendation_id
  end
end
