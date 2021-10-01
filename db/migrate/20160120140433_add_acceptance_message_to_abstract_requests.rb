class AddAcceptanceMessageToAbstractRequests< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_requests, :acceptance_message, :text
  end
end
