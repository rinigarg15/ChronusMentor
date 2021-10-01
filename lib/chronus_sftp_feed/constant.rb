module ChronusSftpFeed
  module Constant
    SUSPENSION_REQUIRED = false
    SUSPEND_ONLY_FOR_PROGRAMS = nil
    ALLOW_LOCATION_UPDATES = false
    ALLOW_MANAGER_UPDATES = false
    REACTIVATE_SUSPENDED_USERS = false

    CHUNK_SIZE = 1000
    FILE_ENCODING = 'ISO-8859-1'
    ROW_SEPARATOR = :auto
    CSV_OPTIONS = {
      chunk_size: CHUNK_SIZE,
      keep_original_headers: true,
      file_encoding: FILE_ENCODING,
      row_sep: ROW_SEPARATOR,
      remove_empty_values: false,
      remove_zero_values: false,
      convert_values_to_numeric: false
    }

    SECONDARY_QUESTIONS_MAP = { ProfileQuestion::Type::MANAGER.to_s => "Manager", ProfileQuestion::Type::LOCATION.to_s => "Location" }

    FIRST_NAME = "First Name"
    LAST_NAME = "Last Name"
    EMAIL = "Email"
    PREVENT_NAME_OVERRIDE = false

    MULTIPLE_ANSWER_DELIMITER = "--"
    ALLOW_IMPORT_QUESTION = false
    IMPORT_QUESTION_ANSWER = "Yes"
    IMPORT_QUESTION_TEXT = "Is the user provisioned through data feed?"
    IMPORT_USER_TAGS = false
    USER_TAGS_HEADER = "Tags"
    PROGRAM_NAME_HEADER = "Track"
  end

  module UpdateType
    CREATED = 0
    UPDATED = 1
    SUSPENDED = 2
  end
end