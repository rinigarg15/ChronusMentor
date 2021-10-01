class PostPopulator < PopulatorTask
  def patch(options = {})
    topic_ids = @program.topics.pluck(:id)
    post_hsh = get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, topic_ids)
    process_patch(topic_ids, post_hsh)
  end

  def add_posts(topic_ids, post_count, options = {})
    self.class.benchmark_wrapper "Posts" do
      program = options[:program]
      role_user_ids = {}
      program.roles.non_administrative.each do |role|
        role_user_ids[role.name] = role.users.active.pluck(:id)
      end
      topics = Topic.where(id: topic_ids).includes(:forum)
      topics_array = topics.to_a
      Post.populate(topic_ids.size * post_count, :per_query => 10_000) do |post|
        topic = topics_array.first
        topics_array.rotate!
        user_ids = if role_user_ids.include?(RoleConstants::STUDENT_NAME)
          topic.forum.available_for_student? ? role_user_ids[RoleConstants::STUDENT_NAME] : role_user_ids[RoleConstants::MENTOR_NAME]
        else
          role_user_ids[role_user_ids.keys.sample]
        end
        post.user_id = user_ids
        post.topic_id = topic.id
        post.body = Populator.sentences(2..4)
        post.published = [true, true, true, true, false].sample
        post.created_at = topic.created_at..Time.now
        post.updated_at = post.created_at
        self.dot
      end
      topics.update_all(:posts_count => post_count)
      self.class.display_populated_count(topic_ids.size * post_count, "Post")
    end
  end

  def remove_posts(topic_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Posts....." do
      post_ids = Post.where(:topic_id => topic_ids).select("posts.id, topic_id").group_by(&:topic_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Post.where(:id => post_ids).destroy_all
      self.class.display_deleted_count(topic_ids.size * count, "Post")
    end
  end
end