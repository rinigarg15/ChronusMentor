class AddIndexesToMessagesAfterMergingScraps< ActiveRecord::Migration[4.2]
  def change
    add_index :messages, :parent_id
    add_index :messages, :group_id
    add_index :messages, [:root_id, :id]
    add_index :abstract_message_receivers , [:message_root_id, :member_id], :name => "index_amr_message_root_id_and_message_id"
  end
end
