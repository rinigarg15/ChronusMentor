module ApplicationControllerExtensions::ActionEvents::LoadRequiredObjects
  private

  def load_current_organization
    @current_domain = request.domain
    set_current_organization
    set_variables_for_current_organization
  end

  def load_current_program
    # Cannot find the program without organization.
    return unless @current_organization

    set_current_program

    set_variables_for_current_program

    # Set the features to be enabled for this organization or program.
    enable_features(program_context.enabled_features)
  end

  # Loads the current program root name into the instance variable
  # +current_root+
  def load_current_root
    @current_root = request.env['CURRENT_PROGRAM_ROOT']
    params[:root] = @current_root
  end

  def set_current_program
    # If standalone, take the first program in the organization.
    @current_program ||= @current_organization.programs.first if @current_organization.standalone?

    # this is the root before first program root is assigned as current root
    @standalone_org_level_access = current_root.nil? && @current_program.present?

    @current_program ||= find_current_program

    # If the member is part of only one program, then set the
    # current_program to that program.
    @current_program = wob_member.programs.first if is_member_part_of_single_program?
  end

  def secure_domain_access?
    current_subdomain == SECURE_SUBDOMAIN && request.domain == DEFAULT_DOMAIN_NAME
  end

  def set_current_org_for_secure_domain_access
    unless proxy_session_access? # Linkedin redirects to secure.chronus.com after oauth. We need to redirect the user to his home organization
      # There SHOULD be a home organization that should have been set in the prior
      # access of the session. At this point, we're at a render/redirect of a
      # secure action - so redirect back to parent program
      @current_organization = Organization.find(session[:home_organization_id])

      flash.keep
      redirect_url = root_organization_url(host: current_organization.domain, subdomain: current_organization.subdomain) + request.fullpath.gsub(/^\//, "")
      redirect_to(redirect_url) and return
    end
    set_current_org_for_proxy_secure_access
  end

  def set_current_org_for_proxy_secure_access
    # SSO Access
    @current_organization = Organization.find_by(id: @parent_session.data["home_organization_id"])
    @current_program = @current_organization.programs.find_by(id: @parent_session.data["home_program_id"]) if @current_organization
  end

  def set_current_organization
    # We extract the subdomain from the "mentor" from www.mentor
    if current_subdomain.try(:start_with?, "www")
      redirect_without_www and return
    elsif secure_domain_access?
      set_current_org_for_secure_domain_access
    elsif is_new_organization_creation?
      # ONLY at the time of new organization creation by super users (programs#edit and programs#update). Since sessions are specific to subdomains,
      # redirecting from Step 2 to Step 3(programs#edit) -> "mentor.chronus.com" to "somesubdomain.chronus.com",
      # will create a new session for somedomain.chronus.com, devoid of session[:member_id] and session[:super_console].
      # To fix this, Step 3 is pointed to 'mentor.chronus.com/program_edit', with session[:new_organization_id] set.
      @current_organization = Organization.find_by(id: session[:new_organization_id])
    else
      # Normal access. current_subdomain and current_domain cannot be blank.
      @current_organization = Program::Domain.get_organization(current_domain, current_subdomain)
    end
  end

  def redirect_without_www
    if (current_subdomain =~ /^www\.(.*)$/)
      redirect_to program_root_url(subdomain: $1) and return
    elsif current_subdomain == "www"
      redirect_to url_for(params.to_unsafe_h.merge(subdomain: false, domain: @current_domain))
    end
  end

  def set_variables_for_current_organization
    if @current_organization
      # At this point, current organization is set
      session[:home_organization_id] = @current_organization.id
      TranslationsService.program = @current_organization
      unless @current_organization.security_setting.allow_search_engine_indexing?
        response.headers["X-Robots-Tag"] = "noindex"
      end
    end
  end

  def is_new_organization_creation?
    super_console? && current_subdomain == DEFAULT_SUBDOMAIN && session[:new_organization_id]
  end

  def find_current_program
    # Load program from the root url.
    root_map = { "p1" => "collegenow", "p2" => "ikic-mentoring" }
    (@current_organization.programs.find_by(root: current_root) || @current_organization.programs.find_by(root: root_map[current_root.to_s]))
  end

  def set_variables_for_current_program
    # Set current root from the program we have just recognized.
    if @current_program
      self.current_root = @current_program.root
      session[:home_program_id] = @current_program.id
      TranslationsService.program = @current_program
    end
  end

  def is_member_part_of_single_program?
    !@current_program && logged_in_organization? && wob_member.programs.size == 1
  end
end