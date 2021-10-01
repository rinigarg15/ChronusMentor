module AuthorizationManager
  # Provides methods for handling roles and permissions to the program model.
  module ProgramExtensions
    #
    # Returns the first Role in the with the given name
    #
    def get_role(role_name)
      get_roles(role_name).first
    end


    def has_role?(role_name)
      get_role(role_name).present?
    end
    
    #
    # Returns all the Roles with the given name.
    #
    def get_roles(*role_names)
      role_names = [role_names].flatten.collect(&:to_s)
      if is_a?(Organization)
        # If organization, return all roles of organization + programs.
        (roles + all_roles).select{|role| role_names.include?(role.name)}.uniq
      elsif is_a?(Program)
        # If program, return the program roles alone.
        roles.select{|role| role_names.include?(role.name)}
      end
    end

    # Captures the following method invocations and defines the behaviour for
    # them
    #   program.<role_name>_users => program.admin_users, program.mentor_users
    #
    def method_missing(method_name, *args)
      if method_name.to_s =~ AuthorizationManager::AuthPatterns::ROLE_USERS # <role_name>_users
        role_names = $1.split('_or_')

        # Fetch all role objects for the role name. For organization, this will
        # also return program level roles with the name.
        roles = get_roles(role_names)

        # Cannot fetch users for a role that is not in the program.
        raise NoSuchRoleForProgramException if roles.collect(&:name).uniq.size != role_names.size

        if is_a?(Program)
          # TODO https://rails.lighthouseapp.com/projects/8994/tickets/2460-calling-empty-on-a-scope-with-select-distinct-table_name-throws-error
          # Once the above bug is fixed, we can use the <code>for_role</code>
          # As we will no longer require distinct

          # Construct a scope so that this collection can be cascaded if required.
          User.where("roles.id IN (?)", roles.collect(&:id)).joins(:roles).readonly(false)
        elsif is_a?(Organization)
          self.all_users.for_role(role_names)
        end

      else
        # None of the methods that we want to capture. Over to the super
        # implementation.
        super
      end
    end
  end
end
