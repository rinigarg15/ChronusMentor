module ApplicationControllerExtensions::CurrentObjects
  def current_member_or_cookie
    ChronusAbExperiment.only_use_cookie ? cookies[:uniq_token] : (current_member.try(:id) || cookies[:uniq_token])
  end

  private

  # Finds the user by looking at WOB and then through current chronus
  # user, in that order.
  #
  def current_user
    @current_user ||= (working_on_behalf? ? get_wob_from_session : get_current_user) unless @current_member == false
  end

  def current_user=(new_user)
    @current_user = new_user || false
    self.current_member = new_user.member if new_user && !working_on_behalf?
  end

  #
  # Returns the current user/member based on whether we are at the organization
  # or program level.
  #
  def current_user_or_member
    program_view? ? current_user : current_member
  end

  def current_user_or_wob_member
    program_view? ? current_user : wob_member
  end

  def current_subdomain
    request.subdomain.presence
  end

  def current_program_or_organization
    @get_current_program_or_organization ||= (@current_program || @current_organization)
  end

  def wob_member
    @current_wob_member ||= set_wob_member
  end

  def set_wob_member
    if working_on_behalf?
      wob_member_for_working_on_behalf
    else
      current_member
    end
  end

  def wob_member_for_working_on_behalf
    program_view? && current_user ? current_user.member : get_wob_member
  end

  # This method tries to get the user from the session.
  def get_wob_from_session
    get_wob_member.present? ? get_wob_member.users.active_or_pending.find_by(program_id: @current_program.try(:id)) : nil
  end

  def get_wob_member
    return current_member unless working_on_behalf?
    return get_wob_member_for_org_admin if current_member.admin?
    get_wob_member_for_prog_admin
  end

  def get_wob_member_for_org_admin
    member_at_org_level = @current_organization.members.find_by(id: session[:work_on_behalf_member])
    member_at_org_level ? member_at_org_level : current_member
  end

  def get_wob_member_for_prog_admin
    user_at_program_level = @current_program ? @current_program.all_users.find_by(id: session[:work_on_behalf_user]) : nil
    user_at_program_level ? user_at_program_level.member : current_member
  end
end