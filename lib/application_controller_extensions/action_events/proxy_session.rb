module ApplicationControllerExtensions::ActionEvents::ProxySession
  private

  def setup_proxy_session
    parent_session_id = params[SID_PARAM_NAME]

    if parent_session_id
      if (@parent_session = ActiveRecord::SessionStore::Session.find_by(session_id: parent_session_id))
        logger.info "*** Setting up proxy session for #{parent_session_id}"
        init_proxy_session_from_parent_session
      end
    elsif session[:continue_secure_access] && session[:parent_session_id]
      @parent_session = ActiveRecord::SessionStore::Session.find_by(session_id: session[:parent_session_id])
      session[:continue_secure_access] = nil
    end
  end

  def proxy_session_access?
    @parent_session.present?
  end

  # This is in the before filter and also during logout_killing_session! so
  # that the new session can have a reference back to the parent.
  def init_proxy_session_from_parent_session
    session[:parent_session_id] = @parent_session.session_id
    variables_to_copy_from_parent_session = [:member_id, :back_url, :last_visit_url, :home_organization_id, 
      :home_program_id, :login_mode, :invite_code, :reset_code, :signup_code, :signup_roles]
    copy_variables_from_parent_session(variables_to_copy_from_parent_session)
  end

  def copy_from_proxy_session_to_parent_session
    return unless proxy_session_access?

    copy_default_keys_to_parent_session

    # Copy flashes. For whatever reason, flash is not in session["flash"]
    @parent_session.data["flash"] = flash
    @parent_session.data[:proxy_session_id] = request.session_options[:id]
    @parent_session.save!

    session[:set_mobile_auth_cookie] = nil
    flash.clear
    logger.warn "*** Copied data from proxy (#{request.session_options[:id]}) to parent (#{@parent_session.session_id})"
  end

  def copy_variables_from_parent_session(keys)
    keys.each do |key|
      session[key] = @parent_session.data[key.to_s]
    end
  end

  def copy_default_keys_to_parent_session
    keys_to_copy = [
      :chronussupport_step1_complete,
      :new_custom_auth_user,
      :new_user_import_data,
      :member_id,
      :set_mobile_auth_cookie,
      "flash"
    ]

    keys_to_copy.each do |key|
      if session[key].present? || session[key.to_s].present?
        @parent_session.data[key.to_s] = session[key] || session[key.to_s]
      end
    end

  end
  
end