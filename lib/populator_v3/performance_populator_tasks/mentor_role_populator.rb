class MentorRolePopulator < PopulatorTask
  def patch(options = {})
    return unless @program.default_role_names.include?(RoleConstants::MENTOR_NAME)
    user_ids = @program.users.active.includes(:roles).select{|user| user.roles.empty?}.collect(&:id)
    users_count = @program.users.active.includes(:roles).reject{|user| user.is_admin? }.size
    count = ((@options[:percents_ary].first.to_f/100) * users_count).round
    return if @program.users.active.mentors.count >= count
    add_roles(user_ids, count, @options)
  end

  def add_roles(user_ids, count, options = {})
    program = options[:program]
    role = program.roles.find_by(name: "RoleConstants::MENTOR_NAME".constantize)
    RolePopulator.add_roles(user_ids, count, options, role)
  end

  def remove_roles(member_ids, count, options = {})    
  end
end