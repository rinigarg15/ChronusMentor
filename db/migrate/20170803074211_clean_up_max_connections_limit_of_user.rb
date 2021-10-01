class CleanUpMaxConnectionsLimitOfUser< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      role_ids = Role.where(name: RoleConstants::MENTOR_NAME).pluck(:id)
      mentor_user_ids = RoleReference.where(role_id: role_ids, ref_obj_type: User).pluck(:ref_obj_id)
      User.where.not(id: mentor_user_ids).update_all(max_connections_limit: nil)
    end
  end

  def down
    #Do nothing
  end
end
