class ProgramSpecificAuth

  class Status
    AUTHENTICATION_FAILURE = 0
    NO_USER_EXISTENCE      = 1
    AUTHENTICATION_SUCCESS = 2
    ACCOUNT_BLOCKED        = 3
    PASSWORD_EXPIRED       = 4
    MEMBER_SUSPENSION      = 5
    PERMISSION_DENIED      = 6
    INVALID_TOKEN          = 7
  end

  class StatusParams
    AUTHENTICATION_FAILURE = 'a'
    NO_USER_EXISTENCE      = 'b'
    AUTHENTICATION_SUCCESS = 'c'
    ACCOUNT_BLOCKED        = 'd'
    PASSWORD_EXPIRED       = 'e'
    MEMBER_SUSPENSION      = 'f'
    PERMISSION_DENIED      = 'g'
  end

  attr_accessor :uid, :data, :member, :error_message, :status, :auth_config, :import_data, :linkedin_access_token,
    :prioritize_validation, :has_data_validation, :is_data_valid, :permission_denied_message,
    :nftoken, :name_qualifier, :session_index, :slo_enabled, :name_id

  def initialize(auth_config, data)
    self.auth_config = auth_config
    self.data = data
  end

  def self.authenticate(auth_config, *args)
    auth_obj = self.new(auth_config, args)

    klass = auth_config.auth_type.constantize
    authenticated = klass.authenticate?(auth_obj, auth_obj.auth_config.get_options)

    auth_obj.set_member!(authenticated, klass)
    auth_obj.set_status!(authenticated)
    auth_obj
  end

  def authenticated?
    self.status == Status::AUTHENTICATION_SUCCESS
  end

  def no_user_existence?
    self.status == Status::NO_USER_EXISTENCE
  end

  def authentication_failure?
    self.status == Status::AUTHENTICATION_FAILURE
  end

  def account_blocked?
    self.status == Status::ACCOUNT_BLOCKED
  end

  def password_expired?
    self.status == Status::PASSWORD_EXPIRED
  end

  def member_suspended?
    self.status == Status::MEMBER_SUSPENSION
  end

  def permission_denied?
    self.status == Status::PERMISSION_DENIED
  end

  def invalid_token?
    self.status == Status::INVALID_TOKEN
  end

  def deny_permission?
    self.has_data_validation && !self.is_data_valid
  end

  def set_member!(authenticated, klass)
    return if !authenticated || self.authentication_failure?
    return if (klass == ChronusAuth) || self.uid.blank?

    self.member || self.set_member_from_uid!
    self.member || self.set_member_from_email!
  end

  def set_status!(authenticated)
    self.status ||=
      if !authenticated || self.uid.blank?
        Status::AUTHENTICATION_FAILURE
      elsif self.prioritize_validation && self.deny_permission?
        Status::PERMISSION_DENIED
      elsif self.member.try(:suspended?)
        Status::MEMBER_SUSPENSION
      elsif self.member.present?
        Status::AUTHENTICATION_SUCCESS
      elsif self.deny_permission?
        Status::PERMISSION_DENIED
      else
        Status::NO_USER_EXISTENCE
      end
  end

  def is_uid_email?
    ValidatesEmailFormatOf::validate_email_format(self.uid.to_s, check_mx: false).nil?
  end

  def set_member_from_uid!
    self.member = LoginIdentifier.find_by(auth_config_id: self.auth_config.id, identifier: self.uid).try(:member)
  end

  def set_member_from_email!
    email = self.import_data.try(:[], Member.name).try(:[], "email")
    email ||= self.uid if self.is_uid_email?
    member = self.auth_config.organization.members.find_by(email: email) if email.present?

    if member.present?
      if LoginIdentifier.exists?(member_id: member.id, auth_config_id: self.auth_config.id)
        self.member = nil
        self.status = Status::AUTHENTICATION_FAILURE
        self.error_message = "flash_message.user_flash.mismatch_uid".translate
      else
        self.member = member
      end
    end
  end
end