# Time taken: 73.89 seconds for production data in development environment
class AddReactivationStatesToUsers< ActiveRecord::Migration[4.2]
  def up
    add_column :users, :track_reactivation_state, :string
    add_column :users, :global_reactivation_state, :string
  end

  def down
    remove_column :users, :track_reactivation_state
    remove_column :users, :global_reactivation_state

    Organization.active.where(programs_count: 1).each do |organization|
      program = organization.programs.first
      suspended_member_ids = program.users.suspended.pluck(:member_id)
      organization.members.where(id: suspended_member_ids).update_all("state = #{Member::Status::SUSPENDED}")
    end
  end
end