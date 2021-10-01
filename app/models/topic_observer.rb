class TopicObserver < ActiveRecord::Observer

  def after_create(topic)
    handle_subscriptions(topic)
    Topic.delay.notify_subscribers(topic.id)
    topic.forum.create_recent_activity(RecentActivityConstants::Type::TOPIC_CREATION, topic)
  end

  private

  def handle_subscriptions(topic)
    topic_user = topic.user
    forum = topic.forum

    forum.subscribe_user(topic_user)
    topic.subscribe_user(topic_user)
    if forum.is_group_forum?
      forum.group.members.each { |group_member| topic.subscribe_user(group_member) }
    end
  end
end