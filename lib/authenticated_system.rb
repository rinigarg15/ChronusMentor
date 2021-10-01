module AuthenticatedSystem
  protected

  ############## Savage beast ##############

    # Updates the *last seen at* of the current_user
    # Delta indexing is disabled by default for performance boost.
    # Delta indexing is performed if the argument +perform_delta+ is explicitly set to true.
    def update_last_seen_at(perform_delta = false)
      return unless logged_in_program?

      unless working_on_behalf?
        # Don't delta index the user for the last_seen_at update
        if perform_delta
          current_user.update_attribute(:last_seen_at, Time.now.utc)
        else
          db_time = Time.now.utc.to_s(:db)
          ActiveRecord::Base.connection.execute("UPDATE `users` SET `last_seen_at` = '#{db_time}', `updated_at` = '#{db_time}' WHERE `users`.`id` = #{current_user.id}")
        end
      end
    end

    def admin?
      current_user && current_user.is_admin?
    end

    ############## End of Savage beast ##############

    # Returns true or false if the user is logged in.
    # Preloads @current_member with the user model if they're logged in.
    def logged_in_organization?
      !!current_member
    end

    # Accesses the current user from the session.
    # Future calls avoid the database because nil is not equal to false.
    def current_member
      unless @current_member == false
        if @current_organization.present?
          @current_member ||= (login_from_session || login_from_basic_auth || login_from_cookie || login_from_mobile_auth || false)
        else
          @current_member = false
        end
      end
    end

    # Store the given user id in the session.
    # Also Updates the current session with the logged in users id (or nil if not
    # logged in). session.model gives the current active session.
    def current_member=(new_user)
      session[:member_id] = new_user ? new_user.id : nil
      @current_member = new_user || false
      @current_organization = @current_member.organization if @current_member
    end

    # Check if the user is authorized
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the user
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorized?
    #    current_member.login != "bob"
    #  end
    #
    def authorized?(action=nil, resource=nil, *args)
      logged_in_organization?
    end

    # Filter method to enforce a login requirement. Login requirement refers to setting current_user here.
    #
    # To require logins for all actions, use this in your controllers:
    #
    #   before_action :login_required_in_program
    #
    # To require logins for specific actions, use this in your controllers:
    #
    #   before_action :login_required_in_program, only: [ :edit, :update ]
    #
    # To skip this in a subclassed controller:
    #
    #   skip_before_action :login_required_in_program
    #
    def login_required_in_program(auth_config_id = nil)
      authorized? ? (logged_in_program? ? true : require_user) : access_denied(auth_config_id)
    end

    def login_required_in_organization(auth_config_id = nil)
      authorized? || access_denied(auth_config_id)
    end

    def login_required_at_current_level(auth_config_id = nil)
      logged_in_at_current_level? || access_denied(auth_config_id)
    end

    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the login screen.
    #
    # Override this method in your controllers if you want to have special
    # behavior in case the user is not authorized
    # to access the requested action.  For example, a popup window might
    # simply close itself.
    def access_denied(auth_config_id = nil)
      respond_to do |format|
        format.any(:html, :pdf) do
          back_mark_pages(force_mark: request.get?)
          redirect_to new_session_path(auth_config_id: auth_config_id)
        end
        format.any(:js, :json) do
          xhr_access_denied(auth_config_id)
        end
      end
    end

    def xhr_access_denied(auth_config_id)
      auth_config = get_and_set_current_auth_config
      if auth_config.blank? || auth_config.remote_login?
        render js: "window.location.href = \"#{new_session_path(auth_config_id: auth_config_id)}\";", status: :unauthorized
      else
        unless ENV['CUCUMBER_ENV']
          return request_http_basic_authentication 'Web Password'
        else
          logger.info "*** Unauthenticated Ajax request xhr_access_denied"
          head :unauthorized
        end
      end
    end

    # Inclusion hook to make #current_user and #logged_in_organization?
    # available as ActionView helper methods.
    def self.included(base)
      base.send :helper_method, :current_member, :logged_in_organization?, :authorized? if base.respond_to? :helper_method
    end

    #
    # Login
    #

    # Called from #current_user.  First attempt to login by the user id stored in the session.
    def login_from_session
      self.current_member = @current_organization.members.find_by(id: session[:member_id]) if session[:member_id] && @current_organization
      return @current_member
    end

    # Called from #current_member.  Now, attempt to login by basic authentication information.
    def login_from_basic_auth
      authenticate_with_http_basic do |login, password|
        auth_config = @current_organization.chronus_auth
        auth_obj = ProgramSpecificAuth.authenticate(auth_config, login, password)
        self.current_member = auth_obj.member if auth_obj.authenticated?
      end
      return @current_member
    end

    def login_from_mobile_auth
      if is_mobile_app? && cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN].present? && !secure_domain_access?
        device = MobileDevice.includes(member: :organization).where(mobile_auth_token: cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN], platform: mobile_platform).first
        member = device.member if device.present? && device.member.organization == @current_organization
        if member
          device.set_mobile_auth_cookie(cookies, true) #refresh mobile_auth_cookie
          self.current_member = member
        end
      end
      return @current_member
    end

    #
    # Logout
    #

    # Called from #current_member.  Finaly, attempt to login by an expiring token in the cookie.
    # for the paranoid: we _should_ be storing user_token = hash(cookie_token, request IP)
    def login_from_cookie
      user = cookies[:auth_token] && @current_organization.members.find_by(remember_token: cookies[:auth_token]) if @current_organization
      if user && user.remember_token?
        self.current_member = user
        handle_remember_cookie! false # freshen cookie token (keeping date)
        self.current_member
      end
      return @current_member
    end

    # This is ususally what you want; resetting the session willy-nilly wreaks
    # havoc with forgery protection, and is only strictly necessary on login.
    # However, **all session state variables should be unset here**.
    def logout_keeping_session!
      # Kill server-side auth cookie
      @current_member.forget_me if @current_member.is_a? Member
      @current_member = false     # not logged in, and don't do it for me
      kill_remember_cookie!     # Kill client-side auth cookie
      logger.info "*** logout_keeping_session! for #{request.session_options[:id]}"
      session[:member_id] = nil   # keeps the session but kill our variable
      # explicitly kill any other session variables you set
      if proxy_session_access?
        @parent_session.data["member_id"] = nil
        logger.info "*** logout_keeping_session! parent session member_id reset"
      elsif (sid = session[:proxy_session_id])
        s = ActiveRecord::SessionStore::Session.find_by(session_id: sid)
        if s.present?
          s.data["member_id"] = nil; s.save!
          logger.info "*** logout_keeping_session! proxy session member_id reset"
        end
      end
    end

    # The session should only be reset at the tail end of a form POST --
    # otherwise the request forgery protection fails. It's only really necessary
    # when you cross quarantine (logged-out to logged-in).
    def logout_killing_session!(preserve_session_values = false, options = {})
      old_sess_id = request.session_options[:id]
      old_proxy_session = session[:proxy_session_id]
      logout_keeping_session!

      session_values = {}
      if preserve_session_values
        session.to_hash.each do |key, value|
          session_values[key.to_sym] = value
        end
      elsif !options[:dont_preserve_values_for_saml_slo]
        session.to_hash.each do |key, value|
          if ["name_id", "name_qualifier", "session_index", "slo_enabled", :slo_enabled, :session_index, :name_qualifier, :name_id].include?(key)
            session_values[key.to_sym] = value
          end
        end
      end

      sess = reset_session

      logger.info "*** logout_killing_session! Changed session from #{old_sess_id} to #{request.session_options[:id]}"
      if proxy_session_access?
        init_proxy_session_from_parent_session
        logger.info "*** logout_killing_session! Init parent session (#{@parent_session.session_id}) for #{request.session_options[:id]}"
      elsif ((sid = old_proxy_session) && (s = ActiveRecord::SessionStore::Session.find_by(session_id: sid)))
        s.destroy
        logger.info "*** logout_killing_session! Destroy old proxy session (#{s.session_id}) for parent #{old_sess_id}"
      end
      session.update(session_values)

      sess # Preserve return value
    end

    #
    # Remember_me Tokens
    #
    # Cookies shouldn't be allowed to persist past their freshness date,
    # and they should be changed at each login

    # Cookies shouldn't be allowed to persist past their freshness date,
    # and they should be changed at each login

    def valid_remember_cookie?
      return nil unless @current_member
      (@current_member.remember_token?) && (cookies[:auth_token] == @current_member.remember_token)
    end

    # Refresh the cookie auth token if it exists, create it otherwise
    def handle_remember_cookie! new_cookie_flag
      return unless @current_member
      case
      when valid_remember_cookie? then @current_member.refresh_token # keeping same expiry date
      when new_cookie_flag        then @current_member.remember_me
      else                             @current_member.forget_me
      end
      send_remember_cookie!
    end

    def kill_remember_cookie!
      cookies.delete :auth_token
    end

    def send_remember_cookie!
      cookies[:auth_token] = {
        value: @current_member.remember_token,
        expires: @current_member.remember_token_expires_at }
    end

end
