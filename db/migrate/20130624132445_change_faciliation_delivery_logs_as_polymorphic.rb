class ChangeFaciliationDeliveryLogsAsPolymorphic< ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      rename_column :facilitation_delivery_logs, :facilitation_message_id, :facilitation_delivery_loggable_id
      add_column :facilitation_delivery_logs, :facilitation_delivery_loggable_type, :string
      ActiveRecord::Base.connection.execute("UPDATE facilitation_delivery_logs SET facilitation_delivery_loggable_type='FacilitationMessage'")
    end
  end

  def down
    rename_column :facilitation_delivery_logs, :facilitation_delivery_loggable_id, :facilitation_message_id
    remove_column :facilitation_delivery_logs, :facilitation_delivery_loggable_type
  end
end
