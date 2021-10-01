class UserStateChangePopulator < PopulatorTask
  def patch(options = {})
    user_ids = @program.users.active.pluck(:id)
    user_state_changes_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_ids)
    process_patch(user_ids, user_state_changes_hsh) 
  end

  def add_user_state_changes(user_ids, count, options = {})
    self.class.benchmark_wrapper "User State Change" do
      program = options[:program]
      users = program.users.where(id: user_ids).includes([:roles, :connection_memberships, :groups])
      counter = 0
      UserStateChange.populate(users.size, :per_query => 10_000) do |transition|
        user = users[counter]
        info = {state: {}, role: {}}
        info[:state][:from] = nil
        info[:state][:to] = user.state
        info[:role][:from] = nil
        info[:role][:to] = user.role_ids
        connection_membership_info = {role: {from_role: [], to_role: user.role_ids}}
        connection_membership_info[:role][:to_role] = [] unless @program.engagement_enabled?
        transition.date_id = user.created_at.utc.to_i/1.day.to_i
        transition.user_id = user.id
        transition.info = UserStateChange.new.set_info(info)
        transition.connection_membership_info = UserStateChange.new.set_connection_membership_info(connection_membership_info)
        counter += 1
        self.dot
        transition
      end
      # At this point there wont be any connection membership created, skipping here, will be populated at the membership state change populator
      self.class.display_populated_count(user_ids.size * count, "User State Change")
    end

    # connection_memberships = Connection::Membership.where(user_id: user_ids).includes([:user, :group])
    # counter = 0
    # ConnectionMembershipStateChange.populate(connection_memberships.size, :per_query => 10_000) do |membership_state_change|
    #   membership = connection_memberships[counter]
    #   user = membership.user
    #   group = membership.group
    #   info_hash = {}
    #   info_hash[:group] = {from_state: group.status, to_state: group.status}
    #   info_hash[:user] = {from_state: user.state, to_state: user.state}
    #   info_hash[:connection_membership] = {from_state: Connection::Membership::Status::ACTIVE, to_state: Connection::Membership::Status::ACTIVE}
    #   membership_state_change.connection_membership_id = membership.id
    #   membership_state_change.date_id = user.created_at.utc.to_i/1.day.to_i
    #   membership_state_change.group_id = group.id
    #   membership_state_change.user_id = user.id
    #   membership_state_change.role_id = membership.role_id
    #   membership_state_change.set_info(info_hash)
    #   counter += 1
    #   self.dot
    #   membership_state_change
    # end
  end

  def remove_user_state_changes(user_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User State Change................" do
      user_state_change_ids = UserStateChange.where(:user_id => user_ids).select([:id, :user_id]).group_by(&:user_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      UserStateChange.where(:id => user_state_change_ids).destroy_all
      self.class.display_deleted_count(user_ids.size * count, "User State Changes")
    end
  end
end