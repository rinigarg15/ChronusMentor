class MentoringModel::Task::CommentObserver < ActiveRecord::Observer
  def after_create(comment)
    MentoringModel::Task::Comment.delay(:queue => DjQueues::HIGH_PRIORITY).create_scrap_from_comment(comment.id) if comment.notify
  end

end