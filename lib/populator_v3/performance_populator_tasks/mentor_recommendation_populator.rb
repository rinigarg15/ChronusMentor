class MentorRecommendationPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return unless @options[:common]["mentor_recommendation_enabled?"]
    receiver_ids = @program.student_users.pluck(:id)
    mentor_recommendations_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, receiver_ids)
    process_patch(receiver_ids, mentor_recommendations_hsh)
  end

  def add_mentor_recommendations(receiver_ids, count, options = {})
    self.class.benchmark_wrapper "Mentor Recommendations" do
      status = [MentorRecommendation::Status::PUBLISHED, MentorRecommendation::Status::DRAFTED]
      program = options[:program]
      admin_user_id = program.admin_users.first.id
      MentorRecommendation.populate(count * receiver_ids.size) do |mr|
        mr.program_id = program.id
        mr.status = status.sample
        mr.sender_id = admin_user_id
        mr.receiver_id = receiver_ids.first
        receiver_ids = receiver_ids.rotate
        self.dot
      end
      self.class.display_populated_count(receiver_ids.size * count, "mentor recommendations")
    end
  end

  def remove_mentor_recommendations(receiver_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentor Recommendations................" do
      mentor_recommendation_ids = MentorRecommendation.where(receiver_id: receiver_ids).group_by(&:receiver_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      destroy_objects_with_progress_print(MentorRecommendation.where(id: mentor_recommendation_ids))
      self.class.display_deleted_count(receiver_ids.size * count, "mentor recommendations")
    end
  end
end