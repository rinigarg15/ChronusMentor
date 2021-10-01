class AddMessageRootIdToAbstractMessageReceivers< ActiveRecord::Migration[4.2]
  def up
    add_column :abstract_message_receivers, :message_root_id, :integer, null: false, default: 0

    say_with_time "Updating root messages" do
      AbstractMessageReceiver.joins(:message).update_all("abstract_message_receivers.message_root_id=messages.root_id")
    end
  end

  def down
    remove_column :abstract_message_receivers, :message_root_id
  end
end
