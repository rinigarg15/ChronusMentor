class Article::PublicationObserver < ActiveRecord::Observer
  def after_create(publication)
    # Trigger emails to the admins.
    Article::Publication.delay.notify_users(publication.id, RecentActivityConstants::Type::ARTICLE_CREATION)
  end

  def after_destroy(publication)
    Article::Publication.es_reindex(publication)
  end
end
