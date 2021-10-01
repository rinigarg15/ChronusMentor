class AddRefObjIdMoveUserIdToRefObjIdRemoveUserIdFromOneTimeFlag< ActiveRecord::Migration[4.2]
  def change
    add_column :one_time_flags, :ref_obj_id, :integer, :null =>false
    add_column :one_time_flags, :ref_obj_type, :string, limit: UTF8MB4_VARCHAR_LIMIT, :null =>false
    add_index :one_time_flags, :ref_obj_type
    add_index :one_time_flags, :ref_obj_id
    reversible do |updateUserCol|
      updateUserCol.up do
        OneTimeFlag.update_all("ref_obj_id = user_id")
        OneTimeFlag.update_all(ref_obj_type: User.name)
      end
    end
    remove_column :one_time_flags, :user_id, :integer
  end
end