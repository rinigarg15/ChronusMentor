module ApplicationControllerExtensions::ActionEvents::RequireAccess
  private

  # Use this as a before filter
  def require_program
    unless @current_program
      if current_member
        flash[:error] = "common_text.error_msg.page_not_found".translate
        redirect_to programs_list_path
      else
        redirect_to root_organization_url(:subdomain => REDIRECT_SUBDOMAIN, :host => DEFAULT_HOST_NAME)
      end
    end
  end

  def require_user
    if @current_program && !logged_in_program?
      flash[:error] = "feature.program.content.not_part_of_program_error".translate(program_name: @current_program.name)
      # current_user will not be set if the user is suspended in the program
      # suspended users should be shown flash message on suspension -
      # whenever they access pages requiring current_user be present and program_root_path
      # check redirections_unlogged_in_and_other_roles filter before changing the redirect path
      redirect_to root_path
    else
      require_program
    end
  end

  def require_organization
    # access without a subdomain
    unless @current_organization
      redirect_to root_organization_url(:subdomain => REDIRECT_SUBDOMAIN, :host => DEFAULT_HOST_NAME)
      return false
    end
  end

  # If not super user, redirect to super login page.
  def require_super_user
    unless super_console?
      redirect_to super_login_path
      return false
    end
  end
end