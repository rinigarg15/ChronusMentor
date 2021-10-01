class GroupStateChangePopulator < PopulatorTask
  def patch(options= {})
    return unless @program.engagement_enabled?
    group_ids = @program.groups.pluck(:id)
    group_state_changes_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, group_ids)
    process_patch(group_ids, group_state_changes_hsh) 
  end

  def add_group_state_changes(group_ids, count, options = {})
    self.class.benchmark_wrapper "Group State Change" do
      program = options[:program]

      # # closed groups      
      # groups = program.groups.where(id: group_ids, status: Group::Status::CLOSED)

      # # nil to active tracker
      # counter = -1
      # GroupStateChange.populate(groups.size, :per_query => 10_000) do |group_state_change|
      #   group = groups[(counter += 1)]
      #   update_group_state_change!(group_state_change, group, nil, Group::Status::ACTIVE)
      #   self.dot
      #   group_state_change
      # end

      # # active to closed tracker
      # counter = -1
      # GroupStateChange.populate(groups.size, :per_query => 10_000) do |group_state_change|
      #   group = groups[(counter += 1)]
      #   update_group_state_change!(group_state_change, group, Group::Status::ACTIVE, group.status)
      #   self.dot
      #   group_state_change
      # end

      # # groups in other statuses
      # groups = program.groups.where(id: group_ids, "status != ?", Group::Status::CLOSED)

      groups = program.groups.where(id: group_ids)
      counter = -1
      GroupStateChange.populate(groups.size, :per_query => 10_000) do |group_state_change|
        group = groups[(counter += 1)]
        update_group_state_change!(group_state_change, group, nil, group.status)
        self.dot
        group_state_change
      end

      self.class.display_populated_count(group_ids.size * count, "Group State Change")
    end
  end

  def update_group_state_change!(group_state_change, group, from_state, to_state)
    group_state_change.group_id = group.id
    group_state_change.from_state = from_state
    group_state_change.to_state = to_state
    group_state_change.date_id = group.created_at.utc.to_i/1.day.to_i
  end

  def remove_group_state_changes(group_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Group State Change................" do
      group_state_change_ids = GroupStateChange.where(:group_id => group_ids).select([:id, :group_id]).group_by(&:group_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      GroupStateChange.where(:id => group_state_change_ids).destroy_all
      self.class.display_deleted_count(group_ids.size * count, "User State Changes")
    end
  end
end