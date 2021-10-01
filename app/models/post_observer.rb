class PostObserver < ActiveRecord::Observer

  def after_create(post)
    handle_subscriptions(post)
    after_publish_actions(post) if post.published?
  end

  def after_update(post)
    if post.saved_change_to_published? && post.published?
      after_publish_actions(post)
    end
  end

  def after_save(post)
    reindex_followups(post)
  end

  def after_destroy(post)
    reindex_followups(post)
  end

  private

  def reindex_followups(post)
    Post.es_reindex(post)
  end

  def handle_subscriptions(post)
    post_user = post.user
    post.topic.subscribe_user(post_user)
    post.forum.subscribe_user(post_user)
  end

  def after_publish_actions(post)
    PostObserver.delay.send_emails(post.id)
    post.forum.create_recent_activity(RecentActivityConstants::Type::POST_CREATION, post)
  end

  def self.send_emails(post_id)
    post = Post.published.find_by(id: post_id)
    return if post.blank?

    Forum.deliver_notifications(post)
  end
end