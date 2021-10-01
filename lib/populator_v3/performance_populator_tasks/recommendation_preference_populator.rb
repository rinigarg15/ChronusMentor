class RecommendationPreferencePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    mentor_recommendation_ids = @program.mentor_recommendations.pluck(:id)
    recommendation_preferences_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, mentor_recommendation_ids)
    process_patch(mentor_recommendation_ids, recommendation_preferences_hsh)
  end

  def add_recommendation_preferences(mentor_recommendation_ids, count, options = {})
    self.class.benchmark_wrapper "Mentor Recommendations" do
      program = options[:program]
      mentor_user_ids = program.mentor_users.sample(count).collect(&:id)
      mentor_recommendation_index = 0
      loop_var = 0
      RecommendationPreference.populate(MentorRecommendation.where(id: mentor_recommendation_ids).size * count) do |recommendation_preference|
        mentor_recommendation_id = mentor_recommendation_ids[mentor_recommendation_index]
        position ||= RecommendationPreference.where(mentor_recommendation_id: mentor_recommendation_id).size + 1
        recommendation_preference.user_id = mentor_user_ids.rotate!
        recommendation_preference.mentor_recommendation_id = mentor_recommendation_id
        recommendation_preference.note = Populator.sentences(1..2)
        recommendation_preference.position = position
        position += 1
        loop_var += 1
        if loop_var == count
          loop_var = 0
          mentor_recommendation_index += 1
          position =  RecommendationPreference.where(mentor_recommendation_id: mentor_recommendation_id).size + 1
        end
        self.dot
      end
      self.class.display_populated_count(mentor_recommendation_ids.size * count, "recommendation preferences")
    end
  end

  def remove_recommendation_preferences(mentor_recommendation_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Recommendation Preferences................" do
      recommendation_preference_ids = RecommendationPreference.where(mentor_recommendation_id: mentor_recommendation_ids).group_by(&:mentor_recommendation_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      destroy_objects_with_progress_print(RecommendationPreference.where(id: recommendation_preference_ids))
      self.class.display_deleted_count(mentor_recommendation_ids.size * count, "recommendation preferences")
    end
  end
end