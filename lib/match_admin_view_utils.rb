module MatchAdminViewUtils
  def fetch_admin_views_for_matching
    @admin_view_role_hash = Hash.new
    @admin_view_role_hash[RoleConstants::MENTOR_NAME] = Array.new
    @admin_view_role_hash[RoleConstants::STUDENT_NAME] = Array.new
    list_fav_admin_views = AdminView.get_admin_views_ordered(@current_program.admin_views)
    list_fav_admin_views.each do |view|
      roles = view.get_included_roles_string
      @admin_view_role_hash[RoleConstants::MENTOR_NAME] << view if roles == RoleConstants::MENTOR_NAME
      @admin_view_role_hash[RoleConstants::STUDENT_NAME] << view if roles == RoleConstants::STUDENT_NAME
    end
  end

  def fetch_mentee_and_mentor_views(mentee_view, mentor_view, new_view_id = nil, options={})
    get_new_view(new_view_id) if new_view_id.present?
    if view_present?(@mentee_view, mentee_view)
      @mentee_view ||= mentee_view
      @mentee_view_filters, @mentee_view_users = @mentee_view.get_filters_and_users(options)
    end
    if view_present?(@mentor_view, mentor_view)
      @mentor_view ||= mentor_view
      @mentor_view_filters, @mentor_view_users = @mentor_view.get_filters_and_users(options)
    end
  end

  def view_present?(view_instance, view_local)
    return view_instance.present? || view_local.present?
  end

  def get_new_view(new_view_id)
    new_view = @current_program.admin_views.find(new_view_id)
    if new_view.present?
      roles = new_view.get_included_roles_string
      if roles == RoleConstants::MENTOR_NAME
        @mentor_view = new_view
      elsif roles == RoleConstants::STUDENT_NAME
        @mentee_view = new_view
      end
    end
  end
end