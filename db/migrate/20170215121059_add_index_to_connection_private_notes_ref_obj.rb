class AddIndexToConnectionPrivateNotesRefObj< ActiveRecord::Migration[4.2]
  def change
    add_index :connection_private_notes, [:ref_obj_id, :type], :name => "index_connection_private_notes_on_ref_obj"
    add_index :connection_private_notes, :ref_obj_id
    add_index :connection_private_notes, :type
  end
end
