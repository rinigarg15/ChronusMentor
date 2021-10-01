module AuthorizationManager
  # Provides methods for handling roles and permissions to the user model.
  module UserExtensions
    # Handles the authorization related method invocations and defines the
    # behaviour for them
    def method_missing(method_name, *args)
      if method_name.to_s =~ AuthorizationManager::AuthPatterns::HAS_ONLY_ROLE # is_<role_1>_only?
        # The user should have only one role which is $1.
        role_name = $1
        self.roles.size == 1 && has_role?(role_name)
      elsif method_name.to_s =~ AuthorizationManager::AuthPatterns::HAS_ANY_ROLE # is_<role_1>_or_<role_2>?
        role_names = $1.split('_or_')
        not lookup_roles(role_names).empty?
      elsif method_name.to_s =~ AuthorizationManager::AuthPatterns::HAS_ALL_ROLES # is_<role_1>_and_<role_2>?
        role_names = $1.split('_and_')
        all_roles = lookup_roles(role_names)

        # All roles in role_names should be there.
        all_roles.collect(&:name).uniq.size == role_names.size
      elsif method_name.to_s =~ AuthorizationManager::AuthPatterns::HAS_SINGLE_ROLE # is_<role_name>?
        role_name = $1
        not lookup_role(role_name).nil?
      elsif method_name.to_s =~ AuthorizationManager::AuthPatterns::HAS_PERMISSION # can_<permission_name>?
        permission_name = $1
        # No such permission. Panic!
        raise NoSuchPermissionException unless Permission.exists_with_name?(permission_name)

        # Check whether the user has the permission
        self.roles.collect(&:permissions).flatten.collect(&:name).include?(permission_name)
      else
        # None of the methods that we want to capture. Over to the super
        # implementation.
        super
      end
    end

    # Adds the role with name <i>role_name</i> to the user
    def add_role(role_name)
      role = self.program.get_role(role_name)

      # Cannot add a role that the program does not support.
      raise NoSuchRoleForProgramException if role.nil?
      self.roles << role
    end

    # Removes the role with the name <i>role_name</i> for the user
    def remove_role(role_name)
      role = lookup_role(role_name)

      # Cannot remove a role that the user does not have.
      raise RoleNotFoundForUserException if role.nil?
      self.roles.delete(role)
    end

    # Returns whether the user has the role with name <i>role_name</i>
    def has_role?(role_name)
      # Just delegate to is_<role_name>?
      self.send("is_#{role_name}?")
    end

    private

    # Returns all the Roles of the user having names in <i>role_names</i>
    def lookup_roles(role_names)
      # Note that the self.roles could be an uncommitted association hence we
      # are just *filtering* on the <i>roles</i> collection and not using a
      # self.roles.find_by_name since the latter will result in a SQL query.
      self.roles.select{|r| role_names.include?(r.name)}
    end

    # Returns the Role of the user having the given <i>role_name</i>
    def lookup_role(role_name)
      self.roles.find{|r| r.name == role_name}
    end
  end
end
