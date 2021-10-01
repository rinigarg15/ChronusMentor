class UserPopulator < GenericUserPopulator
  def patch(options = {})
    member_ids = @organization.members.active.pluck(:id)
    category = get_organization_category(@organization)
    users_count_ary = @options[:org_node][category]["users_count"]
    admin_member_id = member_ids.first
    total_members = member_ids.size
    @organization.programs.each_with_index do |program, index|
      users_count = users_count_ary[index]
      current_member_ids = member_ids.shift(users_count + 1)
      users_hsh = program.users.active.where(:member_id => current_member_ids + [admin_member_id]).pluck(:member_id).group_by{|x| x}
      @options[:program] = program
      process_patch((current_member_ids + [admin_member_id]).uniq, users_hsh)
    end
  end

  def add_users(member_ids, count, options = {})
    add_users_with_state(member_ids, count, options)
  end

  def remove_users(member_ids, count, options = {})
    self.class.benchmark_wrapper "Remove Users....." do
      program = options[:program]
      user_ids = program.users.where(:member_id => member_ids, state: [User::Status::SUSPENDED, User::Status::ACTIVE]).select("id, member_id").group_by(&:member_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      remove_users_with_state(program, user_ids)
      self.class.display_deleted_count(member_ids.size * count, "Users")
    end
  end
end