module ApplicationControllerExtensions::CommonChecks
  private

  def logged_in_program?
    !!current_user
  end

  # Returns whether login is done at the current level, be it a program or an
  # organization.
  #
  def logged_in_at_current_level?
    program_view? ? logged_in_program? : logged_in_organization?
  end

  # Returns whether the admin is working on behalf .
  #
  def working_on_behalf?
    logged_in_organization? && session[:work_on_behalf_member].present?
  end

  def organization_view?
    @current_organization && !program_view?
  end

  def program_view?
    !!@current_program
  end

  def super_user_or_feature_enabled?(feature_name)
    super_user_or? do
      @current_organization.has_feature?(feature_name)
    end
  end

  # check if super user or execute given block
  def super_user_or?
    super_console? || Proc.new.call
  end

  #
  # Returns whether to render the program selector in the top header.
  #
  def show_program_selector?(member_has_many_active_programs = true)
    # Not WOB and belongs to more than one program
    @current_organization.active? && logged_in_organization? && ((working_on_behalf? && current_member.admin?) || !working_on_behalf?) && many_programs_in_organization?(member_has_many_active_programs)
  end

  # Matches if the browser is IE and the version is less given version
  def is_ie_less_than?(version)
    browser.ie? && browser.version.to_i < version
  end

  # Returns whether we are currently inside super console.
  def super_console?
    session[ChronusSessionsController::SUPER_CONSOLE_SESSION_KEY] == true
  end

  def can_view_programs_listing_page?
    return false if @current_organization.standalone? || @current_organization.programs.published_programs.empty?
    if logged_in_organization?
      @current_organization.programs_listing_visible_to_logged_in_users?
    else
      @current_organization.programs_listing_visible_to_all?
    end
  end

  def check_is_admin?
    (program_view? && current_user.is_admin?) || (organization_view? && wob_member.admin? && @current_organization.org_profiles_enabled?)
  end

  def can_create_portals?
    super_console? && @current_organization.career_development_enabled?
  end

  def accepted_signup_terms?
    params[:signup_terms].to_s.to_boolean
  end

  #### PERMISSION FILTERS ####

  def admin_at_current_level?
    wob_member.admin? || (current_user && current_user.is_admin?)
  end

  def check_program_has_ongoing_mentoring_enabled
    @is_ongoing_mentoring_enabled ||= current_program.project_based? || current_program.ongoing_mentoring_enabled?
  end

  def can_view_ongoing_mentoring_related_page?
    @can_view_ongoing_related_page ||= current_program.project_based? || (current_program.ongoing_mentoring_enabled? && (!current_program.consider_mentoring_mode? || current_user.is_admin? || (User::MentoringMode.ongoing_sanctioned.include?(current_user.mentoring_mode) || current_user.groups.active.present?)))
  end

  #
  # Similar to +authorize_user_action+, but operates in the context of a
  # organization and member.
  #
  def authorize_member_action(member)
    Proc.new { wob_member == member || wob_member.admin? }
  end

  #### PERMISSION FILTERS ####

  def many_programs_in_organization?(member_has_many_active_programs)
    ( member_has_many_active_programs || (@current_organization.enrollment_page_enabled? && !@current_organization.standalone?) )
  end
end
