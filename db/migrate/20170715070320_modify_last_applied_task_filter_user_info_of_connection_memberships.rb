class ModifyLastAppliedTaskFilterUserInfoOfConnectionMemberships < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Connection::Membership.where.not(last_applied_task_filter_user_info: nil).each do |membership|
        membership.update_column(:last_applied_task_filter_user_info, {user_info:  membership.last_applied_task_filter_user_info})
      end
    end
  end

  def down
    #Do nothing
  end
end
