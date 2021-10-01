class AddMultiColumnIndexOnScraps< ActiveRecord::Migration[4.2]
  def change
  	add_index :messages, [:ref_obj_id, :ref_obj_type], :name => "index_message_on_ref_obj"
  end
end
