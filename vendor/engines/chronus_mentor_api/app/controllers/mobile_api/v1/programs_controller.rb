class MobileApi::V1::ProgramsController < MobileApi::V1::BasicController
  skip_before_action :require_program
  before_action Proc.new{ authenticate_user(false) } , :except => [:published_list]
  before_action :set_locale_and_terminology_helpers, only: :published_list
  
  def index
    @programs = current_member.active_programs.ordered.includes(:translations, :contact_admin_setting)
    render_success "programs/index"
  end

  def enrollable_list
    @users, @roles, @programs = @current_organization.get_enrollment_content(current_member)
    @mem_reqs = current_member.membership_requests.pending.includes(:roles).group_by(&:program_id)
    render_success("programs/enrollable_list")
  end

  # Todo: Keeping this to support only older versions of published app. Use of this API method has been deprecated in the mobile-client code.
  def published_list
    @programs = @current_organization.programs.published_programs.ordered.includes([:translations, :contact_admin_setting])
    render_success "programs/index"
  end

  def select
    root_map = { "p1" => "collegenow", "p2" => "ikic-mentoring" }
    program_root = params[:program_root]
    program = @current_organization.programs.find_by(root: program_root) || @current_organization.programs.find_by!(root: root_map[program_root.to_s])
    @current_program = program
    @user = current_member.user_in_program(program)
    update_last_seen_at(true) if @user
    render_response(data: {
      id: @user.id, state: @user.state, roles: MobileApi::V1::BasePresenter::RolesMapping.aliased_names(@user.role_names),
      visible_roles: MobileApi::V1::BasePresenter::RolesMapping.aliased_names(@user.visible_non_admin_roles)
    })
  end
end
