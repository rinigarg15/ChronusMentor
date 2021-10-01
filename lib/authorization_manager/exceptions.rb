module AuthorizationManager #:nodoc:
  # Base error class for AuthorizationManager module
  class AuthorizationManagerError < StandardError
  end

  # Raised when attempting to access a role that is not in the program
  class NoSuchRoleForProgramException < AuthorizationManagerError
  end

  # Raised when an expected role is not available for the user.
  class RoleNotFoundForUserException < AuthorizationManagerError
  end

  # Raised when a non existed permission is referred.
  class NoSuchPermissionException < AuthorizationManagerError
  end

  # Raised when program is not set for a record when expected.
  class ProgramNotSetException < AuthorizationManagerError
  end

  # Raised when attempting to use a role related action that is not supported
  # in the given context.
  class UnSupportedRoleActionException < AuthorizationManagerError
  end
end