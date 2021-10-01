class TopicPopulator < PopulatorTask
  def patch(options = {})
    forum_ids = @program.forums.pluck(:id)
    topic_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, forum_ids)
    process_patch(forum_ids, topic_hsh)
  end

  def add_topics(forum_ids, topic_count, options = {})
    self.class.benchmark_wrapper "Forum Topics" do
      program = options[:program]
      role_user_ids = {}
      program.roles.non_administrative.each do |role|
        role_user_ids[role.name] = role.users.active.pluck(:id)
      end
      forums = Forum.where(id: forum_ids).to_a
      Topic.populate(topic_count * forum_ids.size, :per_query => 10_000) do |topic|
        forum = forums.first
        forums = forums.rotate
        topic.forum_id = forum.id
        user_ids = if role_user_ids.include?(RoleConstants::STUDENT_NAME)
          forum.available_for_student? ? role_user_ids[RoleConstants::STUDENT_NAME] : role_user_ids[RoleConstants::MENTOR_NAME]
        else
          role_user_ids[role_user_ids.keys.sample]
        end
        topic.user_id = user_ids
        topic.title = Populator.words(5..10)
        topic.body = Populator.sentences(2..4)
        topic.hits = 10..30
        topic.sticky_position = 0
        topic.posts_count = 0
        topic.created_at = program.created_at
        topic.updated_at = program.created_at..Time.now
        self.dot
      end
      self.class.display_populated_count(forum_ids.size * topic_count, "Forum Topics")
    end
  end

  def remove_topics(forum_ids, count, options = {})
    self.class.benchmark_wrapper "Removing topics....." do
      topic_ids = Topic.where(forum_id: forum_ids).select("id, forum_id").group_by(&:forum_id).map { |a| a[1].last(count) }.flatten.collect(&:id)
      Topic.where(id: topic_ids).destroy_all
      self.class.display_deleted_count(forum_ids.size * count, "Forum Topics")
    end
  end
end