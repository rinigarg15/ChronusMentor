class ConnectionMembershipStateChangePopulator < PopulatorTask
  def patch(options= {})
    return unless @program.engagement_enabled?
    connection_membership_ids = @program.connection_memberships.pluck(:id)
    connection_membership_state_changes_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, connection_membership_ids)
    process_patch(connection_membership_ids, connection_membership_state_changes_hsh) 
  end

  def add_connection_membership_state_changes(connection_membership_ids, count, options = {})
    self.class.benchmark_wrapper "Connection Membership State Change" do
      program = options[:program]
      memberships = Connection::Membership.where(:id => connection_membership_ids).includes([:user, :group])
      counter = 0
      ConnectionMembershipStateChange.populate(memberships.size, per_query: 10_000) do |membership_state_change|
        membership = memberships[counter]
        user = membership.user
        group = membership.group
        info_hash = {}
        info_hash[:group] = {from_state: group.status, to_state: group.status}
        info_hash[:user] = {from_state: user.state, to_state: user.state}
        info_hash[:connection_membership] = {from_state: nil, to_state: Connection::Membership::Status::ACTIVE}
        membership_state_change.connection_membership_id = membership.id
        membership_state_change.date_id = Time.now.utc.to_i/1.day.to_i
        membership_state_change.group_id = group.id
        membership_state_change.user_id = user.id
        membership_state_change.role_id = membership.role_id
        membership_state_change.info = ConnectionMembershipStateChange.new.set_info(info_hash)
        self.dot
        counter += 1
      end
      self.class.display_populated_count(connection_membership_ids.size * count, "Connection Membership State Change")
    end
  end

  def remove_connection_membership_state_changes(connection_membership_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Group State Change................" do
      membership_state_change_ids = ConnectionMembershipStateChange.where(:group_id => connection_membership_ids).select([:id, :connection_membership_id]).group_by(&:connection_membership_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ConnectionMembershipStateChange.where(:id => membership_state_change_ids).destroy_all
      self.class.display_deleted_count(connection_membership_ids.size * count, "Connection Membership State Changes")
    end
  end
end