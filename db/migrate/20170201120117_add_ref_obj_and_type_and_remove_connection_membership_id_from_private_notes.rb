class AddRefObjAndTypeAndRemoveConnectionMembershipIdFromPrivateNotes< ActiveRecord::Migration[4.2]
  def change
    add_column :connection_private_notes, :ref_obj_id, :integer
    add_column :connection_private_notes, :type, :string, limit: UTF8MB4_VARCHAR_LIMIT
    AbstractNote.reset_column_information
    migrate_existing_notes
  end

  def migrate_existing_notes
    AbstractNote.where(ref_obj_id: nil).update_all("ref_obj_id = connection_membership_id, type='Connection::PrivateNote'")
  end
end