class PendingUserPopulator < GenericUserPopulator
  def patch(options = {})
    member_ids = @organization.members.active.includes(:users).select([:id]).select{|m| m.users.size == 0 }.map(&:id)
    return if member_ids.empty?
    category = get_organization_category(@organization)
    pending_users_count_ary = @options[:org_node][category]["pending_users_count"]
    return if pending_users_count_ary.blank?
    admin_member_id = member_ids.first
    total_members = member_ids.size
    @organization.programs.each_with_index do |program, index|
      users_count = pending_users_count_ary[index]
      current_member_ids = member_ids.shift(users_count + 1)
      users_hsh = program.users.where(:member_id => current_member_ids, state: User::Status::PENDING).pluck(:member_id).group_by{|x| x}
      @options[:program] = program
      process_patch((current_member_ids + [admin_member_id]).uniq, users_hsh)
    end
  end

  def add_pending_users(member_ids, count, options = {})
    add_users_with_state(member_ids, count, options.merge!({state: User::Status::PENDING}))
  end

  def remove_pending_users(member_ids, count, options = {})
    self.class.benchmark_wrapper "Remove Pending Users....." do
      program = options[:program]
      user_ids = program.users.where(:member_id => member_ids, state: User::Status::PENDING).select("id, member_id").group_by(&:member_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      remove_users_with_state(program, user_ids)
      self.class.display_deleted_count(member_ids.size * count, "Users")
    end
  end
end