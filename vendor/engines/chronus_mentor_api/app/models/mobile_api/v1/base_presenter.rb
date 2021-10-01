class MobileApi::V1::BasePresenter
  include MobileApi::V1::ApplicationHelper

  attr_accessor :program

  # roles mapping
  module RolesMapping
    MENTEE_ROLE = "mentee"
    MENTOR_ROLE = "mentor"
    ADMIN_ROLE  = "admin"

    # separator sign
    def self.separator
      ","
    end

    # aliases between roles constants and API strings
    def self.aliases
      { RoleConstants::STUDENT_NAME => MENTEE_ROLE,
        RoleConstants::MENTOR_NAME  => MENTOR_ROLE,
        RoleConstants::ADMIN_NAME   => ADMIN_ROLE,
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
      roles.collect { |r| aliases[r] }.join(separator)
    end
  end

  def initialize(program)
    self.program = program
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