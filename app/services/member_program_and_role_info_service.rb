class MemberProgramAndRoleInfoService
  def initialize(organization)
    @organization = organization
    @programs_hash = @organization.programs.ordered.includes(:translations, :roles => [:customized_term => :translations]).group_by(&:id)
  end

  def fetch_member_roles_hash(member_ids)
    member_roles_hash = {}
    members = @organization.members.where("id IN (?)", member_ids).includes(:users => [:roles])
    members.each do |member|
      member_roles_hash[member.id] = get_programs_and_roles(member.users, @programs_hash)
    end
    return member_roles_hash
  end

  private

  def get_programs_and_roles(users, programs_hash)
    user_program_roles = []
    users.each do |user|
      program = programs_hash[user.program_id].first
      user_program_roles << {:program_name => program.name, :role_names => get_role_names(user, program), :program_root => program.root, :program_position => program.position, :user_suspended => user.suspended?}
    end
    return user_program_roles.sort_by{ |hash| hash[:program_position] }
  end

  def get_role_names(user, program)
    role_names = []
    (program.roles & user.roles).each do |role|
      role_names << RoleConstants.human_role_string([role.name], program: program)
    end
    return role_names.sort
  end
end