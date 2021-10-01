# == Schema Information
#
# Table name: auth_configs
#
#  id                :integer          not null, primary key
#  organization_id   :integer          not null
#  auth_type         :string(255)      not null
#  config            :text(65535)
#  created_at        :datetime
#  updated_at        :datetime
#  title             :string(255)
#  password_message  :text(65535)
#  regex_string      :text(65535)
#  use_email         :boolean          default(FALSE)
#  description       :text(65535)
#  logo_file_name    :string(255)
#  logo_content_type :string(255)
#  logo_file_size    :integer
#  logo_updated_at   :datetime
#

class AuthConfig < ActiveRecord::Base
  include ChronusS3Utils

  SAML_METADATA_FILE_FORMATS = ["application/xml", "text/xml"]

  module Type
    CHRONUS        = "ChronusAuth"
    OPENSSL        = "OpenSSLAuth"
    SAML           = "SAMLAuth"
    BBNC           = "BBNCAuth"
    LDAP           = "LDAPAuth"
    Cookie         = "CookieAuth"
    SOAP           = "SOAPAuth"
    OPEN           = "OpenAuth"

    def self.all
      [CHRONUS, OPENSSL, SAML, BBNC, LDAP, Cookie, SOAP, OPEN]
    end

    def self.verbose(type)
      if type == CHRONUS
        "display_string.Email".translate
      else
        "feature.login_management.header.title.#{type}".translate
      end
    end
  end

  AUTHS_WITH_REMOTE_LOGIN = [Type::OPENSSL, Type::SAML, Type::BBNC, Type::Cookie, Type::OPEN]
  AUTHS_WITH_BASE64_ENCODING = [Type::LDAP, Type::OPENSSL, Type::SAML, Type::SOAP, Type::OPEN]

  MASS_UPDATE_ATTRIBUTES = {
    update: [:title, :logo],
    update_password_policy: [:regex_string, :password_message]
  }

  has_attached_file :logo, AUTH_CONFIG_LOGO_STORAGE_OPTIONS
  translates :title, :password_message

  sanitize_attributes_content :password_message

  belongs_to_organization foreign_key: "organization_id"
  has_many :login_identifiers, dependent: :destroy

  validates :organization, presence: true
  validates :auth_type, inclusion: { in: Type.all }
  validates :enabled, inclusion: { in: [true, false] }, if: :default?
  validates :enabled, inclusion: { in: [true] }, if: :custom?
  validate :validate_auth_type_uniqueness, :validate_enabled
  validates_attachment_content_type :logo, content_type: PICTURE_CONTENT_TYPES
  validates_attachment_size :logo, less_than: AttachmentSize::LOGO_OR_BANNER_ATTACHMENT_SIZE, message: Proc.new { "flash_message.message.file_attachment_too_big".translate(file_size: AttachmentSize::LOGO_OR_BANNER_ATTACHMENT_SIZE / ONE_MEGABYTE) }

  default_scope -> { where(enabled: true) }
  scope :non_indigenous, -> { where.not(auth_type: Type::CHRONUS) }

  ##############################################################################
  # INSTANCE METHODS
  ##############################################################################

  def title
    if self.indigenous?
      Type.verbose(self.auth_type)
    elsif self.linkedin_oauth?
      "feature.login_management.header.linkedin".translate
    elsif self.google_oauth?
      "feature.login_management.header.google".translate
    elsif self[:title].present?
      self[:title]
    else
      "#{self.auth_type.gsub("Auth", "")} #{'display_string.Login'.translate}"
    end
  end

  def logo_url
    if self.indigenous?
      ChronusAuth::LOGO
    elsif self.linkedin_oauth?
      OpenAuthUtils::Configurations::Linkedin::LOGO
    elsif self.google_oauth?
      OpenAuthUtils::Configurations::Google::LOGO
    elsif self.logo.exists?
      self.logo.url
    end
  end

  def indigenous?
    self.auth_type == Type::CHRONUS
  end

  def non_indigenous?
    !self.indigenous?
  end

  def remote_login?
    AUTHS_WITH_REMOTE_LOGIN.include?(self.auth_type) || self.token_based_soap_auth?
  end

  def only_remote_login?
    !AUTHS_WITH_REMOTE_LOGIN.include?(self.auth_type)
  end

  def remote_login_url
    self.get_options["url"]
  end

  def get_options
    return {} if self.config.blank?

    options =
      if AUTHS_WITH_BASE64_ENCODING.include?(self.auth_type)
        Marshal.load(Base64.decode64(self.config))
      else
        Marshal.load(self.config)
      end

    if self.oauth? && options["configuration"].present?
      options["configuration"].get_options(self).merge!(options)
    else
      options
    end
  end

  def set_options!(options)
    return nil if options.blank?

    self.config =
      if AUTHS_WITH_BASE64_ENCODING.include?(self.auth_type)
        Base64.encode64(Marshal.dump(options))
      else
        Marshal.dump(options)
      end
    self.save!
  end

  def saml_auth?
    self.auth_type == Type::SAML
  end

  def token_based_soap_auth?
    self.auth_type == Type::SOAP && !!self.get_options["get_token_url"]
  end

  def linkedin_oauth?
    return false unless self.oauth?
    return self.get_options["configuration"] == OpenAuthUtils::Configurations::Linkedin
  end

  def google_oauth?
    return false unless self.oauth?
    return self.get_options["configuration"] == OpenAuthUtils::Configurations::Google
  end

  def oauth?
    self.auth_type == Type::OPEN
  end

  def default_oauth?
    self.default? && self.oauth?
  end

  def saml_settings(url = nil)
    settings = Onelogin::Saml::Settings.new

    settings.assertion_consumer_service_url = url if url

    options = self.get_options
    settings.issuer                         = options["issuer"]
    settings.idp_sso_target_url             = options["idp_sso_target_url"] #"https://fedauth-test.colorado.edu/idp/profile/SAML2/Redirect/SSO"
    settings.idp_destination                = options["idp_destination"] #"https://fedauth-test.colorado.edu/idp/profile/SAML2/Redirect/SSO"
    settings.idp_base64_cert                = options["idp_base64_cert"]
    settings.idp_cert_fingerprint           = options["idp_cert_fingerprint"] #"2C:4E:4D:74:5B:4E:8C:A2:A7:BD:26:E2:7E:D4:9A:32:69:0F:61:74"
    settings.name_identifier_format         = options["name_identifier_format"] #"urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
    settings.idp_slo_target_url             = options["idp_slo_target_url"]
    settings.xmlsec_certificate             = options["xmlsec_certificate"]
    settings.xmlsec_privatekey              = options["xmlsec_privatekey"]
    settings.xmlsec_privatekey_pwd          = options["xmlsec_privatekey_pwd"]
    settings.xmlsec1_path                   = "xmlsec1"

    settings.authn_signed                   = !!options["authn_signed"]

    settings.strict_encoding                = !!options["strict_encoding"]

    unless options["skip_authn_context"]
      # Optional for most SAML IdPs
      settings.requested_authn_context = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"
    end

    settings
  end

  def generate_saml_slo_request(attributes)
    return unless self.saml_settings.idp_slo_target_url.present?

    Onelogin::Saml::LogOutRequest.create(self.saml_settings, attributes)
  end

  def default?
    self.indigenous? || self.linkedin_oauth? || self.google_oauth?
  end

  def custom?
    !self.default?
  end

  def disabled?
    !self.enabled?
  end

  def enable!
    return if self.enabled?

    self.enabled = true
    self.save!
  end

  def disable!
    return if self.disabled?

    self.enabled = false
    self.save!
  end

  def remove_logo!
    self.logo = nil
    self.save!
  end

  def can_be_disabled?
    self.default? && !self.organization.standalone_auth?
  end

  def can_be_deleted?
    self.custom? && !self.organization.standalone_auth?
  end

  def use_browsertab_in_mobile?
    self.google_oauth?
  end

  ##############################################################################
  # CLASS METHODS
  ##############################################################################

  def self.get_attributes_for_mobile_single_logout(auth_config, attributes)
    return if auth_config.nil?

    if auth_config.auth_type == Type::SAML && auth_config.saml_settings.idp_slo_target_url.present?
      variables_to_be_set = SAMLAuth.get_attributes_for_saml_slo({}).keys.map(&:to_s).join(',')
      SAMLAuth.get_attributes_for_saml_slo(attributes).merge(variables_to_be_set: variables_to_be_set)
    end
  end

  def self.classify(auth_configs)
    default_auths = [:indigenous?, :linkedin_oauth?, :google_oauth?].map do |login_method|
      auth_configs.find(&login_method)
    end
    { default: default_auths.compact, custom: (auth_configs - default_auths) }
  end

  def self.attr_value_map_for_default_auths(for_sales_demo = false)
    [
      { auth_type: Type::CHRONUS },
      { auth_type: Type::OPEN, enabled: for_sales_demo, config: Base64.encode64(Marshal.dump( { "configuration" => OpenAuthUtils::Configurations::Linkedin } )) },
      { auth_type: Type::OPEN, enabled: for_sales_demo, config: Base64.encode64(Marshal.dump( { "configuration" => OpenAuthUtils::Configurations::Google } )) }
    ]
  end

  def self.default_oauth_methods
    [:linkedin_oauth?, :google_oauth?]
  end

  private

  def validate_auth_type_uniqueness
    return if self.organization.blank?

    # ignoring linkedin_oauth and google_oauth,
    # only one auth_config must exist per auth_type per organization
    auth_configs = AuthConfig.unscoped.where(organization_id: self.organization_id).where.not(id: self.id).to_a

    invalid =
      if self.default_oauth?
        AuthConfig.default_oauth_methods.any? do |auth_method|
          auth_configs.find(&auth_method).present? && self.send(auth_method)
        end
      else
        auth_configs.reject!(&:default_oauth?)
        self.auth_type.in?(auth_configs.map(&:auth_type))
      end

    if invalid
      auth_type = self.default_oauth? ? self.title : AuthConfig::Type.verbose(self.auth_type)
      self.errors.add(:base, "activerecord.custom_errors.auth_config.type_uniqueness".translate(auth_type: auth_type))
    end
  end

  def validate_enabled
    return if self.organization.blank? || self.enabled?

    auth_configs = self.organization.auth_configs
    auth_configs -= [self]
    if auth_configs.empty?
      self.errors.add(:base, "activerecord.custom_errors.auth_config.atleast_one_login_be_enabled_v1".translate)
    end
  end
end