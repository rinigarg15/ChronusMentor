class CreatePushNotifications< ActiveRecord::Migration[4.2]
  def change
    create_table :push_notifications do |t|
      t.belongs_to :member, null: false
      t.text :notification_params
      t.boolean :unread, default: true
      t.references :ref_obj, :polymorphic => true 
      t.timestamps null: false
    end
    add_index :push_notifications, :member_id
  end
end
