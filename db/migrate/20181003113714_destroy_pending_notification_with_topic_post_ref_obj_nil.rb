class DestroyPendingNotificationWithTopicPostRefObjNil < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      pending_notification_topic_ref_obj_ids = PendingNotification.where(ref_obj_type: Topic).pluck(:ref_obj_id)
      pending_notification_post_ref_obj_ids = PendingNotification.where(ref_obj_type: Post).pluck(:ref_obj_id)
      valid_topic_ids = Topic.pluck(:id)
      valid_post_ids = Post.pluck(:id)
      diff_topic_ref_obj_ids = (pending_notification_topic_ref_obj_ids - valid_topic_ids).uniq
      diff_post_ref_obj_ids = (pending_notification_post_ref_obj_ids - valid_post_ids).uniq
      PendingNotification.where(ref_obj_id: diff_topic_ref_obj_ids, ref_obj_type: Topic).destroy_all
      PendingNotification.where(ref_obj_id: diff_post_ref_obj_ids, ref_obj_type: Post).destroy_all
    end
  end

  def down
  end
end
