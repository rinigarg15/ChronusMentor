class ProjectRequestsController < ApplicationController
  include Report::MetricsUtils
  include AbstractRequestConcern
  include SetProjectsAndConnectionQuestionAnswers

  SEPARATOR = ","

  allow user: :can_send_project_request?, only: [:new, :create]
  allow user: :project_manager_or_owner?, only: [:select_all_ids]
  allow user: :can_manage_project_requests?, only: [:manage]

  before_action :set_up_filter_params, only: [:index, :select_all_ids, :manage]
  before_action :set_up_manage_params, only: [:manage]
  before_action :set_up_project_request_listing, only: [:index, :manage]
  before_action :set_up_my_filters, only: [:index, :select_all_ids]
  before_action :get_requesting_page, only: [:new, :create]
  before_action :set_src, only: [:index, :new, :fetch_actions, :update_actions]

  before_action :fetch_group_and_set_available_roles, only: [:new, :create]
  before_action :fetch_status, only: [:fetch_actions, :update_actions]
  before_action :fetch_requests_and_response_text, only: [:update_actions]
  allow exec: :can_user_withdraw_or_approve_requests?, only: [:update_actions]


  def index
    show_flash_if_required
  end

  def new
    deny! exec: Proc.new{ @group.has_member?(current_user) || @available_roles.blank? }
    @project_request_roles = current_user.roles_for_sending_project_request
    @project_request = @group.project_requests.new
    render layout: false
  end

  def create
    sender_role_id = params[:project_request][:sender_role_id].to_i
    deny! exec: Proc.new{ @group.has_member?(current_user) || @available_roles.collect(&:id).exclude?(sender_role_id) }
    @project_request = current_user.sent_project_requests.new(project_request_params(:create))
    @project_request.program = @current_program
    @project_request.sender_role_id = sender_role_id
    @project_request.save!
    ProjectRequest.delay(queue: DjQueues::HIGH_PRIORITY).send_emails_to_admins_and_owners(@project_request.id, JobLog.generate_uuid)

    if @from_page == :src_hpw
      set_projects_and_connection_question_in_summary_hash
    end
  end

  def select_all_ids
    project_request_ids = ProjectRequest.get_project_request_ids(@filter_params, default_options)
    render json: {project_request_ids: project_request_ids.map(&:to_s)}
  end

  def fetch_actions
    @project_request = current_program.project_requests.build
    project_request_ids = params[:project_request_ids]

    if @status == AbstractRequest::Status::ACCEPTED
      render partial: "project_requests/accept_request_popup", locals: {project_request_ids: project_request_ids, ga_src: @src_path, is_manage_view: params[:is_manage_view]}
    elsif [AbstractRequest::Status::REJECTED, AbstractRequest::Status::WITHDRAWN].include?(@status)
      render partial: "project_requests/reject_or_withdraw_request_popup", locals: {project_request_ids: project_request_ids, ga_src: @src_path, status: @status, is_manage_view: params[:is_manage_view]}
    end
  end

  def update_actions
    return unless @project_requests.present?
    @is_manage_view = params[:is_manage_view].to_s.to_boolean

    case @status
    when AbstractRequest::Status::ACCEPTED
      existing_group_user_requests = @project_requests.select { |request| request.group.has_member?(request.sender) }
      if existing_group_user_requests.present?
        handle_existing_group_user_requests(existing_group_user_requests)
      else
        max_limit_exceeded_groups = get_groups_exceeding_max_limit(@project_requests)
        if max_limit_exceeded_groups.blank?
          add_default_tasks = params[:project_request].present? ? params[:project_request][:add_member_option].to_i == Group::AddOption::ADD_TASKS : true
          is_bulk_action = @project_requests.size > 1

          unavailable_groups = get_unavailable_groups(@project_requests)
          if unavailable_groups.blank?
            @project_requests.each do |project_request|
              project_request.mark_accepted(current_user, add_default_tasks)
              initialize_critical_mass(project_request, is_bulk_action)
            end
            @flash_notice = "flash_message.project_request_flash.accepted".translate(count: @project_requests.size, mentoring_connection: _mentoring_connection)
          else
            handle_unavailable_group_requests(unavailable_groups, @project_requests)
          end
        else
          @flash_error = "flash_message.project_request_flash.max_limit_error_html".translate(group_names: max_limit_exceeded_groups.collect(&:name).to_sentence, count: @project_requests.size)
        end
      end
    when AbstractRequest::Status::REJECTED
      ProjectRequest.mark_rejected(@project_requests.pluck(:id), current_user, @response_text)
      @flash_notice = "flash_message.project_request_flash.rejected".translate(count: @project_requests.size, mentoring_connection: _mentoring_connection)
    when AbstractRequest::Status::WITHDRAWN
      withdraw_project_request
    end
  end

  def manage
    set_tile_data
    set_filters_count
    show_flash_if_required
  end

  private

  def show_flash_if_required
    if !request.xhr? && params[:filtered_group_ids].present? && !params[:dont_show_flash]
      if params[:from_bulk_publish].to_s.to_boolean
        flash.now[:notice] = "feature.connection.content.notice.bulk_publish_with_pending_requests".translate(mentoring_connections: _mentoring_connections)
      else
        group = current_program.groups.find_by(id: params[:filtered_group_ids].first)
        flash.now[:notice] = "feature.connection.content.notice.published_with_pending_requests_html".translate(mentoring_connection: _mentoring_connection, group_url: view_context.link_to(group.name, profile_group_url(group))) if group.present?
      end
    end
  end

  def withdraw_project_request
    @project_request.withdraw!(@response_text)
    @flash_notice = "flash_message.project_request_flash.withdrawn".translate(mentoring_connection: _mentoring_connection)
  end

  def allow_withdraw_request?
    current_user == @project_request.sender
  end

  def handle_existing_group_user_requests(requests)
    errors = requests.collect do |request|
      "flash_message.project_request_flash.part_of_project_error_html".translate(sender_name: request.sender.name, group_name: request.group.name)
    end
    @flash_error = safe_join(errors, tag(:br))
  end

  def handle_unavailable_group_requests(groups, project_requests)
    project_requests_count = project_requests.size
    connection_term = project_requests_count == 1 ? _mentoring_connection : _mentoring_connections
    @flash_error = "flash_message.project_request_flash.unavailable_group_error_html".translate(group_names: groups.pluck(:name).to_sentence, count: project_requests_count, connection_term: connection_term)
  end

  def initialize_critical_mass(project_request, is_bulk_action)
    return if is_bulk_action
    @critical_mass_group = project_request.group.reached_critical_mass? && !project_request.group.has_future_start_date? && project_request.group
  end

  def project_request_params(action)
    params.require(:project_request).permit(ProjectRequest::MASS_UPDATE_ATTRIBUTES[action])
  end

  def get_requesting_page
    @from_page = params[:project_request].delete(:from_page).to_sym
  end

  def initialize_back_link
    @back_link = {
      label: params[:from_profile].present? ? @filter_params[:project] : _Mentoring_Connections,
      link: back_url
    }
  end

  def set_up_my_filters
    @my_filters = initialize_my_filters
  end

  def set_up_filter_params
    @filter_params = {}
    new_filters = params[:filters].present? ? params[:filters].permit(:requestor, :status, :project, :view).to_h : ActiveSupport::HashWithIndifferentAccess.new()

    if params[:view_id] && (@project_request_view = @current_program.abstract_views.find_by(id: params[:view_id]))
      @filter_params = new_filters.reverse_merge(@project_request_view.get_params_to_service_format)
    elsif params[:filters].present?
      @filter_params = new_filters
      @filter_params[:start_time], @filter_params[:end_time] = CommonFilterService.initialize_date_range_filter_params(params[:filters][:sent_between])
    end
    @filter_params[:page] = params[:page] || 1
  end

  def set_up_manage_params
    @filter_params[:status] ||= ProjectRequest::Status::STATE_TO_STRING[ProjectRequest::Status::NOT_ANSWERED]
    @action_params = { filters: @filter_params.except(:page), date_range: params[:date_range] }
    @start_time, @end_time = ReportsFilterService.get_report_date_range(params, current_program.created_at)
    @filter_params[:start_time], @filter_params[:end_time] = [@start_time, @end_time]
    @filter_params_to_store = params.permit(:view_id, :metric_id, filtered_group_ids: []).to_h
    @action_params.merge!(@filter_params_to_store)
  end

  def set_up_project_request_listing
    @track_publish_ga = params[:track_publish_ga].try(:to_boolean)
    @ga_src = params[:ga_src]
    initialize_back_link if params[:from_quick_link].present?
    @title = set_view_title(get_source_metric(current_program, params[:metric_id]), 'feature.project_request.header.project_requests'.translate(Mentoring_Connection: _Mentoring_Connection))
    @back_link = {:label => "feature.reports.content.dashboard".translate, :link => management_report_path} if @project_request_view
    @project_requests = ProjectRequest.get_filtered_project_requests(@filter_params, get_es_options)
    @owner_view = current_user.has_owned_groups? && to_view_filter?(@filter_params)
  end

  def get_es_options
    es_options = default_options
    es_options[:sender_id] = current_user.id if filter_by_sender?(@filter_params)
    if params[:filtered_group_ids].present?
      es_options[:group_ids] = params[:filtered_group_ids]
    elsif filter_by_group?(@filter_params)
      es_options[:group_ids] = current_user.owned_groups.pluck(:id)
    end
    es_options
  end

  def default_options
    { program: current_program }
  end

  def initialize_my_filters
    my_filters = []
    my_filters << {label: "feature.project_request.content.filters.view".translate, reset_suffix: 'view'} if @filter_params[:view].present? && @filter_params[:view].to_i != ProjectRequest::VIEW::TO
    my_filters << {label: "feature.project_request.content.filters.Status".translate, reset_suffix: 'status'} if @filter_params[:status].present? && @filter_params[:status] != "pending"
    my_filters << {label: "feature.project_request.content.filters.requestor".translate, reset_suffix: 'requestor'} if @filter_params[:requestor].present?
    my_filters << {label: _Mentoring_Connection, reset_suffix: 'project'} if @filter_params[:project].present?
    my_filters << {label: "feature.project_request.content.filters.sent_between".translate, reset_suffix: 'sent_between'} if @filter_params[:start_time].present? && @filter_params[:end_time].present?
    my_filters
  end

  def get_groups_exceeding_max_limit(requests)
    groups = []

    request_bin = requests.inject({}) do |bin, request|
      bin[request.group] ||= Hash.new(0)
      bin[request.group][request.sender_role_id] += 1
      bin
    end

    request_bin.each do |group, role_count_bin|
      role_count_bin.each do |role_id, count|
        groups << group unless group.available_roles_for_joining(role_id, additional_count: count).present?
      end
    end
    groups
  end

  def get_unavailable_groups(requests)
    requests.joins(:group).where.not(groups: { status: Group::Status::OPEN_CRITERIA })
  end

  def fetch_group_and_set_available_roles
    group_id = params[:group_id].presence || params[:project_request].try(:[], :group_id)
    @group = current_program.groups.open_connections.find_by(id: group_id)
    deny! exec: Proc.new { @group.blank? }
    @available_roles = @group.available_roles_for_user_to_join(current_user)
  end

  def fetch_requests_and_response_text
    project_request_ids = params[:project_request_ids].split(ProjectRequestsController::SEPARATOR).map(&:to_i)
    @project_requests = current_program.project_requests.active.where(id: project_request_ids).includes(group: :membership_settings)
    @project_request = @project_requests.first if @status == AbstractRequest::Status::WITHDRAWN
    @response_text = params[:project_request].try(:[], :response_text)
  end

  def fetch_status
    @status = params[:request_type].to_i
  end

  def can_user_withdraw_or_approve_requests?
    return allow_withdraw_request? if @status == AbstractRequest::Status::WITHDRAWN
    @project_requests.all? { |project_request| current_user.can_approve_project_requests?(project_request.group) }
  end

  def filter_by_sender?(filter_params)
    !current_user.project_manager_or_owner? || (from_view_filter?(filter_params) && current_user.has_owned_groups?)
  end

  def filter_by_group?(filter_params)
    !current_user.can_manage_project_requests? && current_user.owned_groups.exists? && to_view_filter?(filter_params)
  end

  def to_view_filter?(filter_params)
    filter_params.blank? || (filter_params.present? && filter_params[:view].to_i == ProjectRequest::VIEW::TO)
  end

  def from_view_filter?(filter_params)
    filter_params.present? && (filter_params[:view].to_i == ProjectRequest::VIEW::FROM)
  end

  def set_src
    @src_path = params[:src]
  end

  def set_tile_data
    project_request_ids = ProjectRequest.get_project_request_ids(@filter_params.except(:status, :page), get_es_options.merge(skip_status: true))
    @project_request_hash = { received_count: project_request_ids.size, pending_count: ProjectRequest.where(id: project_request_ids).active.count, accepted_count: ProjectRequest.where(id: project_request_ids).accepted.count, others_count: ProjectRequest.where(id: project_request_ids, status: [ProjectRequest::Status::WITHDRAWN, ProjectRequest::Status::REJECTED, ProjectRequest::Status::CLOSED]).count }
  end

  def set_filters_count
    @filters_count = [:requestor, :project].map{ |param| @filter_params.try(:[], param).present? }.count(true)
  end
end
