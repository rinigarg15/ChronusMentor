class AddRefObjCreatorTypeToPendingNotifications< ActiveRecord::Migration[4.2]
  def change
    rename_column :pending_notifications, :user_id, :ref_obj_creator_id
    add_column :pending_notifications, :ref_obj_creator_type, :string, limit: UTF8MB4_VARCHAR_LIMIT
    add_column :pending_notifications, :message, :text

    add_index :pending_notifications, [:ref_obj_creator_type, :ref_obj_creator_id], :name => "index_pending_notification_on_creator_type_and_id"
  end
end
