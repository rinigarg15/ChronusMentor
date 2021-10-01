class OAuthCredentialsController < ApplicationController
  include OpenAuthUtils::Extensions

  skip_all_action_callbacks only: [:redirect_to_secure]
  skip_before_action :require_program, :login_required_in_program

  # def redirect_to_secure
  #   # uncomment the route match '/authorize_outlook' => 'o_auth_credentials#redirect_to_secure', via: [:get] in routes.rb to check outlook and office365 in development environment
  #   redirect_to "http://secure.localhost.com:3000/session/oauth_callback?state=#{params[:state]}&code=#{params[:code]}"
  # end

  def redirect
    provider_klass = get_oauth_provider_klass(params[:name])
    set_open_auth_callback_params_in_session(nil, nil, nil, {
      source_controller_action: { controller: OAuthCredentialsController.controller_name, action: "callback" },
      oauth_callback_param_value: provider_klass.name,
      use_browsertab_in_mobile: true,
    })
    options_hash = get_options_hash_for_redirect(params)
    oauth_client = get_oauth_client(provider_klass)
    redirect_to_url = oauth_client.auth_code.authorize_url(get_open_auth_state_param)
    prepare_redirect_for_external_authentication(options_hash)
    track_activity_for_ei(EngagementIndex::Activity::INTIALIZE_CONNECT_CALENDAR, context_place: params[:ei_src], context_object: provider_klass)
    redirect_to redirect_to_url
  end

  def callback
    if is_open_auth_state_valid? && params[:code].present?
      callback_success_followups(params[:code])
    else
      callback_failure_followups(params[:code])  
    end
    redirect_to session[:o_auth_final_redirect]
  end

  def disconnect
    o_auth_creds = wob_member.o_auth_credentials
    track_activity_for_ei(EngagementIndex::Activity::DISCONNECT_CALENDAR, context_object: o_auth_creds.map{|o| o.class.name}.sort.join(","))
    o_auth_creds.destroy_all
    flash[:notice] = "feature.calendar_sync_v2.content.disconnect_success".translate
    redirect_to get_back_url_with_callback_params
  end

  private

  def callback_success_followups(code)
    provider_klass = get_oauth_provider_klass(session[:oauth_callback_params][OpenAuth::CALLBACK_PARAM])
    oauth_client = get_oauth_client(provider_klass)
    access_token = oauth_client.auth_code.get_token(code)
    o_auth_credential = update_credential_object!(wob_member, access_token, provider_klass) 
    get_flash_message_and_update_member_availability(o_auth_credential)
    track_activity_for_ei(EngagementIndex::Activity::COMPLETE_CONNECT_CALENDAR, context_object: provider_klass)
  end

  def callback_failure_followups(code)
    provider_klass = get_oauth_provider_klass(session[:oauth_callback_params][OpenAuth::CALLBACK_PARAM])
    error_message = code.blank? ? "No authorization code!" : "State Mismatch!"
    Airbrake.notify("(Member id : #{wob_member.id}) (Provider : #{provider_klass.name}) (Error Message : #{error_message})")
    flash[:error] = "feature.calendar_sync_v2.content.connection_error".translate
  end

  def update_member_availability!(member)
    member.will_set_availability_slots = false
    member.save!
  end

  def get_oauth_provider_klass(klass_name)
    klass_name.constantize
  end

  def get_oauth_client(klass)
    redirect_uri = get_redirect_uri(klass)
    klass.get_oauth_client(redirect_uri: redirect_uri)
  end

  def get_redirect_uri(klass)
    ((klass < MicrosoftOAuthCredential && Rails.env.development?) ? MicrosoftOAuthCredential::REDIRECT_URL_FOR_DEVELOPMENT : get_open_auth_callback_url)
  end

  def update_credential_object!(member, access_token, klass)
    ref_obj_type = session[:organization_wide_calendar] ? AbstractProgram.name : Member.name
    ref_obj_id = session[:organization_wide_calendar] ? @current_organization.id : member.id
    session.delete(:organization_wide_calendar)
    o_auth_credential = klass.find_or_initialize_by(ref_obj_type: ref_obj_type, ref_obj_id: ref_obj_id)
    o_auth_credential.access_token = access_token.token
    o_auth_credential.refresh_token = access_token.refresh_token
    o_auth_credential.save!
    o_auth_credential
  end

  def get_back_url_with_callback_params
    back_url(nil, additional_params: params[:callback_params])
  end

  def get_options_hash_for_redirect(params)
    options_hash = {}
    options_hash[:o_auth_final_redirect] = get_back_url_with_callback_params
    options_hash[:set_organization_wide_calendar] = params[:organization_wide_calendar]
    options_hash[:organization_wide_calendar] = params[:organization_wide_calendar].to_s.to_boolean
    options_hash
  end

  def get_flash_message_and_update_member_availability(o_auth_credential) 
    if o_auth_credential.ref_obj.is_a?(Member) 
      update_member_availability!(wob_member) 
      flash[:notice] = "feature.calendar_sync_v2.content.calendar_synced".translate(calendar_provider: o_auth_credential.ref_obj.o_auth_credentials.map{|obj| obj.class::Provider::NAME}.to_sentence) 
    else 
      flash[:notice] = "feature.calendar_sync_v2.content.organization_calendar_synced".translate 
    end 
  end
end