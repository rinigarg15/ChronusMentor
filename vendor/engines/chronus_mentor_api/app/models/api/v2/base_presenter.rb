class Api::V2::BasePresenter
  attr_accessor :program, :organization

  # roles mapping
  module RolesMapping
    MENTEE_ROLE = "mentee"
    MENTOR_ROLE = "mentor"
    ADMIN_ROLE  = "admin"
    TEACHER_ROLE  = "teacher"

    # separator sign
    def self.separator
      ","
    end

    def self.get_valid_roles(program, roles_array)
      validated_roles = []
      roles_array.each do |role|
        database_role = program.roles.find_by(name: role)
        if database_role.present?
          validated_roles << role 
        else
          return []
        end
      end
      return validated_roles
    end

    # aliases between roles constants and API strings
    def self.aliases
      {
        RoleConstants::STUDENT_NAME => MENTEE_ROLE,
        RoleConstants::MENTOR_NAME  => MENTOR_ROLE,
        RoleConstants::ADMIN_NAME   => ADMIN_ROLE,
        RoleConstants::TEACHER_NAME   => TEACHER_ROLE
      }.freeze
    end

    # API alias to role
    def self.role_from_alias(role_alias)
      aliases.invert[role_alias]
    end

    # list of API alias to role
    def self.roles_from_aliases(roles_string)
      roles_array = roles_string.to_s.split(separator)
      delta = roles_array - aliases.values
      delta.empty? ? roles_array.map { |role_alias| role_from_alias(role_alias) } : []
    end

    # comma separated API aliases
    def self.aliased_names(roles)
      roles.collect { |r| aliases[r] }
    end
  end

  def initialize(program=nil, organization=nil)
    self.program = program
    self.organization = organization
  end

protected
  # everything OK
  def success_hash(data)
    {
      success: true,
      data:    data,
    }
  end

  # something went wrong
  def errors_hash(errors)
    {
      success: false,
      errors: errors,
    }
  end
end
