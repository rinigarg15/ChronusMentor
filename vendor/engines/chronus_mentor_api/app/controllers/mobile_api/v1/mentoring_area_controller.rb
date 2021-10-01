class MobileApi::V1::MentoringAreaController < MobileApi::V1::BasicController
  before_action :authenticate_user
  before_action :fetch_group
  before_action :set_page_controls_allowed
  after_action :mark_visit
  include MobileApi::V1::ApplicationHelper

  protected

  def set_connection_membership
    @connection_membership = @group.membership_of(current_user)
  end

  def render_presenter_response(result_hash)
    result_hash[:data].merge!(common_options(current_user, @group, current_program))
    super
  end

  def render_success(partial_view_path)
    super(partial_view_path, common_options(current_user, @group, current_program))
  end

  def set_page_controls_allowed
    @page_controls_allowed = @group.present? && @group.active?
  end

  def prohibit_writes
    unless !!@page_controls_allowed
      render_errors({can_perform_writes: false}, 403)
    end
  end

  private

  def common_options(user, group, program)
    (program.mentoring_connections_v2_enabled? ? mentoring_area_features(group, program) : {}).
      merge(request.get? ? user_connections(user) : {}).merge(page_controls_allowed: @page_controls_allowed)
  end

  def mentoring_area_features(group, program)
    group_role_permissions = group.object_role_permissions.group_by(&:object_permission_id)
    admin_role, other_roles = categorize_roles(program)
    group_features = {}
    ## This does the same logic as the group.can_manage_mm_tasks?
    ## But in a very performance efficient manner.
    ObjectPermission.all.each do |object_permission|
      role_permissions = group_role_permissions[object_permission.id] || []
      group_features[object_permission.name] = {
        admin: role_permissions.any?{|role_permission| role_permission.role_id == admin_role.id },
        other_users: role_permissions.any?{|role_permission| other_roles.collect(&:id).include?(role_permission.role_id) }
      }
    end
    {group_features: group_features}
  end

  def user_connections(acting_user)
    user_groups = []
    ## The eager loading below ( members: :member ), may look very confusing :P. That is because the association (group.members) returns user objects
    ## TODO:: This association should be fixed soon.
    acting_user.groups.published.includes(members: {member: :profile_picture}).each do |group|
      user_groups << { name:  group.name, id: group.id, image_url: generate_connection_url(group, acting_user, size: :very_small) }
    end
    {user_groups: user_groups}
  end

  def fetch_group
    @group = current_user.groups.published.find(params[:group_id])
  end

  def mark_visit
    @group.delay.mark_visit(current_user) if @group.present?
  end

  def categorize_roles(program)
    program_roles = program.roles.index_by(&:name)
    admin_role = program_roles[RoleConstants::ADMIN_NAME]
    other_roles = program_roles.values.select{|role| role.for_mentoring? }
    [admin_role, other_roles]
  end
end