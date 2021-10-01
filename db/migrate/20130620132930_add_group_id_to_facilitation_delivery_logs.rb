class AddGroupIdToFacilitationDeliveryLogs< ActiveRecord::Migration[4.2]
  def change
    add_column :facilitation_delivery_logs, :group_id, :integer
  end
end
