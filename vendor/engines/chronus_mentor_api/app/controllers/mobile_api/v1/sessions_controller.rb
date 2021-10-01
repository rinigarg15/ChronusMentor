class MobileApi::V1::SessionsController < MobileApi::V1::BasicController
  include AuthenticationUtils
  skip_before_action :require_program
  # We skip setting versions for verify organization to avoid multiple refresh app downloads
  # TODO::Clean this up while submitting to app store as we already handled this in client side by having a 10sec time window
  skip_before_action :load_current_organization, :require_organization, :load_current_root, :load_current_program, :set_client_versions, only: :verify_organization
  before_action Proc.new{ authenticate_user(false) }, only: :destroy
  before_action :set_locale_and_terminology_helpers, except: :destroy

  # ToDo: This mapping is needed to handle organization setup for mobile client in the academywomen environment

  ORGANIZATION_MAP = {
    "ementorprogram.org" => {domain: "chronus.com", subdomain: 'academywomen', name: "Our Programs"}
  }

  ## MobileToDo: This will work only for standalone auths.
  def create
    auth_config = get_and_set_current_auth_config
    auth_obj = ProgramSpecificAuth.authenticate(auth_config, *[params[:email], params[:password]])
    handle_auth_scenarios(auth_obj, params[:device_token])
  end

  def verify_organization
    organization_url = strip_prefixes(params[:organization_url])
    organization = get_organization(organization_url)
    
    response_hash = {data_hash: {}, status: 403, errors: {}}


    if organization.present?
      secure_program_domain = organization.chronus_default_domain
      if !secure_program_domain.nil?
        @current_organization = organization #setting @current_organization inorder to send default params.
        response_hash.merge!(data_hash: {details: {subdomain: secure_program_domain.subdomain, domain: secure_program_domain.domain, org_name: organization.name}}, status: 200)        
      else
        response_hash.merge!(status: 403, errors: {org_has_secure_domain: false})
      end
    elsif ORGANIZATION_MAP.keys.include?(organization_url)
      organization = ORGANIZATION_MAP[organization_url]
      response_hash.merge!(data_hash: {details: {subdomain: organization[:subdomain], domain: organization[:domain], org_name: organization[:name]}},
                          status: 200)
    else
      response_hash.merge!(status: 403, errors: {org_exists: false})
    end    
    generate_response(response_hash[:data_hash], response_hash[:status], response_hash[:errors])
  end

  ## TODO:: This action does not have authenticate_user check, ideally all the logged in requests should have the check
  def destroy
    mobile_device_obj = current_member.mobile_devices.find_by(mobile_auth_token: params[:mobile_auth_token])
    auth_config = current_member.auth_config
    redirect_url = additional_attributes = nil
    case auth_config.auth_type
    when AuthConfig::Type::SAML
      if auth_config.saml_settings.idp_slo_target_url.present?
        redirect_url = saml_slo_url(host: @current_organization.domain, subdomain: @current_organization.subdomain, protocol: "http")
        additional_attributes = SAMLAuth.get_attributes_for_saml_slo({}).keys.map(&:to_s)
      end
    end
    mobile_device_obj.destroy if mobile_device_obj.present?
    generate_response({success: true, redirect_url: redirect_url, additional_params: additional_attributes}, 200) 
  end

private

  def split_domains(parsed_url)
    options = []
    options << [[parsed_url.domain, parsed_url.public_suffix].join("."), parsed_url.subdomain.presence]
    options << [parsed_url.public_suffix.presence, [parsed_url.subdomain, parsed_url.domain].reject{|x| x.blank?}.join(".")]
    options
  end

  def get_organization(organization_url)
    domain_options = split_domains(Domainatrix.parse(organization_url))
    Program::Domain.get_organization(*domain_options[0]) || Program::Domain.get_organization(*domain_options[1])
  end

  ## MobileToDo: Handle all other scenarios in sessions_controller like suspended, account blocked here.
  def handle_auth_scenarios(auth_obj, device_token)
    auth_config_member = auth_obj.member
    response_hash = {data_hash: {}, status: 403, errors: {}}
    if auth_obj.authenticated?
      self.current_member = auth_config_member
      mobile_device_obj = auth_config_member.set_mobile_access_tokens!(device_token)
      response_hash.merge!(data_hash: {details: {auth_token: mobile_device_obj.mobile_auth_token, id: auth_config_member.id, email: auth_config_member.email}},
                          status: 200)
    
    elsif auth_obj.member_suspended?
      response_hash.merge!(status: 403, errors: {user_suspended: true})
      
    elsif auth_obj.account_blocked?
      reactivation_enabled = auth_config_member.organization.security_setting.reactivation_email_enabled?            
      response_hash.merge!(data_hash: {can_reactivate: reactivation_enabled}, # can_reactivate can be integrated later.
                           status: 403, 
                           errors: {account_blocked: true})
   
    elsif auth_obj.password_expired?
      response_hash.merge!(status: 403, errors: {password_expired: true})
    
    else
      response_hash.merge!(status: 403, errors: {other: true})
    end
    
    return generate_response(response_hash[:data_hash], response_hash[:status], response_hash[:errors])
  end

  def generate_response(data_hash, status, errors={})
    render_response(data: data_hash.merge!(errors: errors), status: status)
  end

  def strip_prefixes(organization_url)
    organization_url.sub(/^https?\:\/\//, '').sub(/^www./,'').downcase
  end
end
