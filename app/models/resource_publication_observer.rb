class ResourcePublicationObserver < ActiveRecord::Observer
  def after_save(resource_publication)
    create_admin_view_cache(resource_publication)
    reindex_followups(resource_publication)
  end

  def after_destroy(resource_publication)
    reindex_followups(resource_publication)
  end

  private

  def create_admin_view_cache(resource_publication)
    admin_view = resource_publication.admin_view
    return unless admin_view.present?
    admin_view.delay(queue: DjQueues::HIGH_PRIORITY).refresh_user_ids_cache if admin_view.can_create_admin_view_user_cache?
  end

  def reindex_followups(resource_publication)
    ResourcePublication.es_reindex(resource_publication)
  end
end
