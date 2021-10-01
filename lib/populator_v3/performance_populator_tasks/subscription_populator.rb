class SubscriptionPopulator < PopulatorTask
  def patch(options = {})
    user_ids = @program.users.active.pluck(:id) - @program.admin_users.active.pluck(:id)
    subscription_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_ids)
    process_patch(user_ids, subscription_hsh) 
  end

  def add_subscriptions(user_ids, subscriptions_count, options = {})
    program = options[:program]
    program.roles.non_administrative.each do |role|
      role_user_ids = program.send("#{role.name}_users").where(id: user_ids).active.pluck(:id)
      forums = program.forums.for_role([role.name]).includes(:topics)
      add_role_subscriptions(role_user_ids, forums.pluck(:id), forums.collect(&:topics).flatten.collect(&:id).compact, subscriptions_count, options)
    end
  end

  def add_role_subscriptions(user_ids, forum_ids, topic_ids, subscriptions_count, options = {})
    self.class.benchmark_wrapper "Forum Subscription" do
      Subscription.populate(subscriptions_count * user_ids.size, :per_query => 10_000) do |subscription|
        subscription.ref_obj_id = forum_ids.first
        forum_ids = forum_ids.rotate
        subscription.ref_obj_type = Forum.to_s
        subscription.user_id = user_ids.first
        user_ids = user_ids.rotate
        self.dot
      end
      self.class.display_populated_count(user_ids.size * subscriptions_count, "Forum Subscription")
    end
  end

  def remove_subscriptions(user_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Forum Subscription....." do
      subscription_ids = Subscription.where(:user_id => user_ids).select("user_id, subscriptions.id").group_by(&:user_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      Subscription.where(:id => subscription_ids).destroy_all
      self.class.display_deleted_count(user_ids.size * count, "Forum Subscription")
    end
  end
end