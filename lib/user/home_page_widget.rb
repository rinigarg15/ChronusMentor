module User::HomePageWidget
  extend ActiveSupport::Concern

  def can_render_home_page_widget?
    self.program.project_based? && self.available_projects_for_user.first.any?
  end

  def roles_for_sending_project_request
    self.roles.for_mentoring.with_permission_name(RolePermission::SEND_PROJECT_REQUEST).select{ |role| self.allow_project_requests_for_role?(role) }
  end

  def available_projects_for_user_for_scope(groups_scope=nil, eager_load_answers=false)
    project_based_roles_for_mentoring = self.roles_for_sending_project_request.pluck(:id)
    return [[], false] unless project_based_roles_for_mentoring.present?

    groups_scope ||= self.program.groups.global.open_connections
    groups_scope = groups_scope.includes(answers: :answer_choices) if eager_load_answers
    groups = groups_scope.reject_groups_with_ids(ids_of_groups_user_is_part_of_or_sent_request_to).recently_available_first.available_projects(project_based_roles_for_mentoring).limit(ProgramsController::MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET + 1)
    return [groups.to_a, groups.size > ProgramsController::MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET]
  end

  def available_projects_for_user(eager_load_answers=false)
    self.program.project_based? ? available_projects_for_user_for_scope(nil, eager_load_answers) : []
  end

  private

  def ids_of_groups_user_is_part_of_or_sent_request_to
    (self.groups.pluck(:id) + self.sent_project_requests.pluck(:group_id)).uniq
  end

end