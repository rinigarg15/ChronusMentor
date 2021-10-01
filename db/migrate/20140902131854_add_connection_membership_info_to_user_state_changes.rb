class AddConnectionMembershipInfoToUserStateChanges< ActiveRecord::Migration[4.2]
  def up
    add_column :user_state_changes, :connection_membership_info, :text
    UserStateChange.reset_column_information
    user_state_change_objects = []
    counter = 0
    one_day_to_i = 1.day.to_i

    UserStateChange.includes(user: :connection_membership_state_changes).find_each do |user_state_change|
      # Handling user state changes that were created in the initial user state migration
      if user_state_change.info_hash[:state][:from] == nil
        membership_roles = []
      else
        # Handling user state changes that were created from the call backs
        membership_state_changes = user_state_change.user.connection_membership_state_changes.select{|cmsc| cmsc.date_time < (user_state_change.date_time||user_state_change.created_at)}
        membership_roles = get_roles_from_membership_state_changes(membership_state_changes)
      end

      user_state_change.set_connection_membership_info({role: {from_role: membership_roles, to_role: membership_roles}})
      user_state_change_objects << user_state_change
      
      print '.' if counter % 100 == 0
      counter += 1
    end

    User.includes([{connection_membership_state_changes: :connection_membership}, :state_transitions]).find_each do |user|
      membership_from_roles = []
      membership_to_roles = []
      user_state_transitions = user.state_transitions.sort_by{|state_change| [state_change.date_id, state_change.created_at]}.reverse

      last_add_role_ids = []
      last_remove_role_ids = []
      from_membership_roles = []
      user.connection_membership_state_changes.sort_by{|cmsc| cmsc.date_time}.each do |cmsc|
        info = {state: {}, role: {}}
        transition_before_membership_created = user_state_transitions.find{|state_change| compare_time_or_date_id(state_change, cmsc)}
        info[:state][:from] = info[:state][:to] = transition_before_membership_created.info_hash[:state][:to]
        info[:role][:from] = info[:role][:to] = transition_before_membership_created.info_hash[:role][:to]

        cmsc_info = cmsc.info_hash
        if Group::Status::ACTIVE_CRITERIA.include?(cmsc_info[:group][:to_state]) && cmsc_info[:connection_membership][:to_state] == Connection::Membership::Status::ACTIVE && (!Group::Status::ACTIVE_CRITERIA.include?(cmsc_info[:group][:from_state]) || cmsc_info[:connection_membership][:from_state] != Connection::Membership::Status::ACTIVE)
          add_role_ids = last_add_role_ids.dup
          add_role_ids << cmsc.connection_membership.role_id
          remove_role_ids = last_remove_role_ids.dup
        elsif Group::Status::ACTIVE_CRITERIA.include?(cmsc_info[:group][:from_state]) && cmsc_info[:connection_membership][:from_state] == Connection::Membership::Status::ACTIVE && (!Group::Status::ACTIVE_CRITERIA.include?(cmsc_info[:group][:to_state]) || cmsc_info[:connection_membership][:to_state] != Connection::Membership::Status::ACTIVE)
          add_role_ids = last_add_role_ids.dup
          remove_role_ids = last_remove_role_ids.dup
          remove_role_ids << cmsc.connection_membership.role_id
        else
          next
        end

        to_membership_roles = array_subtract(add_role_ids.dup, remove_role_ids)

        transition = user.state_transitions.new(date_id: cmsc.date_id)
        transition.set_info(info)
        transition.set_connection_membership_info({role: {from_role: from_membership_roles.uniq, to_role: to_membership_roles.uniq}})
        user_state_change_objects << transition

        from_membership_roles = to_membership_roles
        last_add_role_ids = add_role_ids
        last_remove_role_ids = remove_role_ids

        print '.' if counter % 100 == 0
        counter += 1
      end
    end
    UserStateChange.import user_state_change_objects, on_duplicate_key_update: [:connection_membership_info], validate: false
  end

  def down
    remove_column :user_state_changes, :connection_membership_info
  end

  def get_roles_from_membership_state_changes(membership_state_changes)
    roles_to_add = []
    roles_to_remove = []
    membership_state_changes.each do |membership_state_change|
      info = membership_state_change.info_hash
      if Group::Status::ACTIVE_CRITERIA.include?(info[:group][:to_state]) && info[:connection_membership][:to_state] == Connection::Membership::Status::ACTIVE && (!Group::Status::ACTIVE_CRITERIA.include?(info[:group][:from_state]) || info[:connection_membership][:from_state] != Connection::Membership::Status::ACTIVE)
        roles_to_add << membership_state_change.role_id
      elsif Group::Status::ACTIVE_CRITERIA.include?(info[:group][:from_state]) && info[:connection_membership][:from_state] == Connection::Membership::Status::ACTIVE && (!Group::Status::ACTIVE_CRITERIA.include?(info[:group][:to_state]) || info[:connection_membership][:to_state] != Connection::Membership::Status::ACTIVE)
        roles_to_remove << membership_state_change.role_id
      end
    end
    array_subtract(roles_to_add, roles_to_remove)
    return roles_to_add
  end

  def array_subtract(array1, array2)
    array2.each do |element|
      array1.delete_at(array1.index(element) || array1.length)
    end
    return array1
  end

  def compare_time_or_date_id(state_change, cmsc)
    if state_change.info_hash[:state][:from] == nil
      state_change.date_id <= cmsc.date_id
    else
      (state_change.date_time||state_change.created_at) < cmsc.date_time
    end
  end
end
