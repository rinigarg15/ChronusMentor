class CreateGroupStateChangesForMissedCases< ActiveRecord::Migration[4.2]
  def up
    return unless GroupStateChange.any?
    created_time_of_previous_migration = GroupStateChange.first.created_at
    # As all the groups state changes were imported at the smae time in the migration, they have the same created at
    # Need to verrify the same in all envs
    non_missing_group_ids = GroupStateChange.where(:created_at => created_time_of_previous_migration).pluck(:group_id)
    missing_groups = Group.where("id NOT IN (?)", non_missing_group_ids)

    group_state_change_objects = []
    missing_groups.select([:id, :status, :created_at, :published_at, :closed_at, :pending_at, :program_id, :creator_id]).includes(:program, :created_by).find_each do |group|
      if group.program.project_based?
        # group.closed_at < created_time_of_previous_migration consdition is added to make sure that a state change object is not created for groups 
        # which satisfy the other conditions now but not during the time of group state change migration. One fail case is a group satisfied the conditions then but 
        # then it became active and closed again. We will miss this as closed_at gets updated.
        if group.pending_at.present? && group.published_at.present? && group.closed_at.present? && group.created_by.present? && group.created_by.is_admin? && group.closed_at < created_time_of_previous_migration
          group_state_change_objects << group.state_changes.new(from_state: nil, to_state: Group::Status::DRAFTED, date_id: get_date_id(group.created_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::DRAFTED, to_state: Group::Status::PENDING, date_id: get_date_id(group.pending_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::PENDING, to_state: Group::Status::ACTIVE, date_id: get_date_id(group.published_at))
          group_state_change_objects << group.state_changes.new(from_state: Group::Status::ACTIVE, to_state: Group::Status::CLOSED, date_id: get_date_id(group.closed_at)) if group.closed?
        end
      end
    end
    GroupStateChange.import group_state_change_objects
  end

  def down
  end

  private

  def get_date_id(timestamp)
    (timestamp.utc.to_i / 86400)
  end
end