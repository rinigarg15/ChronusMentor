module ApiConstants
  AUTHORIZATION_KEY_ERROR = "authorization key is invalid"
  ACCESS_UNAUTHORISED = "Access Unauthorised"
  MAXIMUM_PROFILE_LIMIT = 10000


  module ConnectionErrors
    EXPIRE_DATE_FORMAT   = ":expiry_date has invalid format, please use YYYYMMDD"
    USER_NOT_FOUND       = "user with email '%s' not found"
    CONNECTION_NOT_FOUND = "connection with id=%s was not found"
    TERMINATION_REASON_IS_BLANK = "termination_reason can't be blank"
    TEMPLATE_ID_NOT_FOUND = "template id '%s' not found"
  end

  module UserErrors
    INCORRECT_ROLES  = "Incorrect Roles"
    INCORRECT_STATUS = "Incorrect Status"
    USER_NOT_FOUND   = "user with uuid '%s' not found"
    UUID_NOT_PASSED  = "UUID not passed"
    EMAIL_NOT_PASSED = "email not passed"
    USER_NOT_PART_OF_PROGRAM = "member with uuid '%{value}' is not part of the %{program_term}"
    PRIVACY_RESTRICTION = "access restricted due to privacy settings"
    DESTROY_ERROR = "This user cannot be removed"
  end

  module MemberErrors
    MEMBER_ALREADY_EXISTS = "member with email_id: '%{value}' already exists"
    MEMBER_DOES_NOT_EXISTS = "member with uuid '%{value}' not found"
    INVALID_STATUS_PASSED = "invalid update status passed"
    TRANSITION_NOT_POSSIBLE = "This state transition is not allowed"
    OWNER_DESTROY_ERROR = "This member cannot be removed"
    INVALID_UPDATED_AFTER_TIMESTAMP = "Invalid timestamp %{timestamp} for updated after"
    UPDATED_AFTER_TIMESTAMP_MISSING = "updated_after not passed"
    INVALID_CREATED_AFTER_TIMESTAMP = "Invalid timestamp %{timestamp} for created after"
    MAXIMUM_PROFILE_LIMIT_EXCEEDED = "Requested profile updates exceed the limit. Please try with a shorter time span"
  end

  module ResourceErrors
    RESOURCE_NOT_FOUND = "resource with id '%s' not found"
  end

  module CommonErrors
    ENTITY_NOT_FOUND = "%{entity} with %{attribute} %{value} not found"
    ENTITY_NOT_PASSED = "%{entity} not passed"
  end

end