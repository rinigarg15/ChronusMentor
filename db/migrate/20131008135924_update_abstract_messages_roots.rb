class UpdateAbstractMessagesRoots< ActiveRecord::Migration[4.2]
  def up
    say_with_time "Updating root messages" do
      AbstractMessage.where(parent_id: nil).update_all("root_id=id")
    end

    say_with_time "Updating children messages" do
      AbstractMessage.where(root_id: 0).includes(:parent).find_each do |message|
        message.update_attribute(:root_id, calculate_root(message).id)
      end
    end
  end

  def down
  end

private
  def calculate_root(node)
    node_root = node
    while node_root.parent.present?
      node_root = node_root.parent
    end
    node_root
  end
end
