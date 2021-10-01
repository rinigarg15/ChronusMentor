class ActsAsTaggableOn::TaggingObserver < ActiveRecord::Observer

  def after_save(tagging)
    reindex_user(tagging)
  end

  def after_destroy(tagging)
    reindex_user(tagging)
  end

  private

  def reindex_user(tagging)
    return unless tagging.taggable_type == User.name
    DelayedEsDocument.delayed_update_es_document(User, tagging.taggable_id)
  end
end