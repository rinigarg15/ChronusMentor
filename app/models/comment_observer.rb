class CommentObserver < ActiveRecord::Observer
  def after_create(comment)
    # Create an RA for the article author and the commenter
    RecentActivity.create!(
      :programs => [comment.publication.program],
      :member => comment.user.member,
      :ref_obj => comment,
      :action_type => RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION,
      :target => RecentActivityConstants::Target::ALL
    )

    Comment.delay.notify_watchers(comment.id, RecentActivityConstants::Type::ARTICLE_COMMENT_CREATION)
  end
end
