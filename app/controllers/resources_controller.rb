class ResourcesController < ApplicationController
  include ApplicationHelper

  POSITION = 'position'
  SUBTAB_COUNT = 5
  allow :exec => :check_resources_enabled?
  skip_before_action :require_program, :login_required_in_program, :except => [:reorder]
  before_action :login_required_in_organization
  before_action :get_resource, :only => [:edit, :update, :destroy]
  before_action :check_management_access, only: [:index, :show]
  before_action :check_not_management_access, only: [:rate, :show_question]
  before_action :get_accessible_resource, only: [:rate, :show_question]
  before_action :set_sort_params, only: [:index]

  allow :exec => :check_management_access, :except => [:show, :index, :rate, :show_question]

  def index
    if @search_query.present?
      @resources = Resource.get_es_resources(QueryHelper::EsUtils.sanitize_es_query(@search_query), make_search_options(@sort_field, @sort_order, params[:page]))
      @resources = ordered_resources(@resources, {sort_field: POSITION}).paginate(:per_page => PER_PAGE, :page => params[:page] || 1) if sort_field == POSITION
      resource_and_program_roles if (@admin_view && program_view?)
    elsif @admin_view
      handle_resources_admin_view
    elsif !current_user
      require_user
    elsif program_view?
      @resources = current_user.accessible_resources(sort_field: @sort_field, sort_order: @sort_order).paginate(:per_page => PER_PAGE, :page => params[:page] || 1)
      track_activity_for_ei(EngagementIndex::Activity::VIEW_RESOURCE_LIST)
    else
      require_program
    end
  end

  def show
    if @admin_view
      if program_view?
        @resources = current_user.accessible_resources(admin_view: true).includes(:ratings)
        resource_and_program_roles
      else
        @resources = @current_organization.resources.includes(:ratings)
      end
      get_resource
      track_activity_for_ei(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: @resource.title}) if @resource.present?
    elsif program_view?
      get_accessible_resource
      @resource.hit!(false) if @resource.present?
      track_activity_for_ei(EngagementIndex::Activity::VIEW_RESOURCE, {context_object: @resource.title}) if @resource.present?
    else
      require_program
    end
  end

  def rate
    return if @resource.blank?
    rating = params[:rating]
    @resource.create_rating(rating, wob_member)
    @admin_message = @current_program.admin_messages.build(sender: wob_member)  if rating == Resource::RatingType::UNHELPFUL 
    @resource = current_user.accessible_resources.find(params[:id])
  end

  def show_question
    return if @resource.blank?
    @admin_message = @current_program.admin_messages.build(sender: wob_member)
  end

  def new
    @resource = (@current_program || @current_organization).resources.new
    ProgramsListingService.fetch_programs self, @current_organization do |all_programs|
      all_programs.ordered.includes(:roles)
    end
  end

  def create
    program_ids, program_roles_hash = resource_program_roles
    @resource = nil

    ActiveRecord::Base.transaction do
      @resource = (@current_program || @current_organization).resources.new(resource_params(:create))
      assign_user_and_sanitization_version(@resource)
      @resource.save!
      setup_resource_publications!(@resource, program_ids)
      @resource.resource_publications.find_by!(program_id: current_program.id).update_attributes!(resource_publication_params(:create)) if program_view?
      setup_role_resources!(@resource, program_roles_hash)
    end
    flash[:notice] = "flash_message.resource_flash.create_success_v1_html".translate(resource: _resource, click_here: view_context.link_to("display_string.Click_here".translate, resource_path(@resource)))
    redirect_to resources_path(:resource_id => @resource.id)
  end

  def edit
    ProgramsListingService.fetch_programs self, @current_organization do |all_programs|
      all_programs.ordered.includes(:roles)
    end
  end

  def update
    program_ids, program_roles_hash = resource_program_roles
    assign_user_and_sanitization_version(@resource)

    ActiveRecord::Base.transaction do
      @resource.update_attributes!(resource_params(:update)) unless program_view? && view_context.can_access_resource?(@resource)
      unless program_view?
        setup_resource_publications!(@resource, program_ids)
      else
        # This is added to update show_in_quick_links in program_view.
        @resource.resource_publications.find_by!(program_id: current_program.id).update_attributes!(resource_publication_params(:update))
      end
      setup_role_resources!(@resource, program_roles_hash)
    end

    flash[:notice] = "flash_message.resource_flash.update_success_v1_html".translate(resource: _resource, click_here: view_context.link_to("display_string.Click_here".translate, resource_path(@resource)))
    redirect_to resources_path(:resource_id => @resource.id)
  end

  def destroy
    @resource.destroy
    redirect_to resources_path, :notice => "flash_message.resource_flash.delete_success".translate(resource: _resource)
  end

  def reorder
    resource_publication_by_resource_id = @current_program.resource_publications.index_by(&:resource_id)
    ResourcePublication.transaction do
      params[:new_order].collect(&:to_i).each_with_index do |id, index|
        resource_publication = resource_publication_by_resource_id[id]
        resource_publication.position = index + 1
        resource_publication.save!
      end
    end
    head :ok
  end

  protected

  def make_search_options(sort_field, sort_order, page_no)
    filter_options = {"resource_publications.program_id" => @current_program.id}
    sort_field = param_to_sort_field_map(sort_field)
    sort_options = {sort_field => sort_order}
    sort_options = {} if sort_field == POSITION
    {
      filter: filter_options,
      sort:  sort_options,
      admin_view_check: current_user.is_admin?,
      current_user_role_ids: global_search_current_user_role_ids,
      page: page_no || 1,
      per_page: Resource.per_page   
    }
  end

  def ordered_resources(resources, options = {})
    ordered_resource_ids = current_user.get_orderded_resource_ids(current_program.resource_publications, options)
    ordered_resource_ids = ordered_resource_ids & resources.collect(&:id)
    resource_ids_string = ordered_resource_ids.join(",")
    Resource.where(id: ordered_resource_ids).order(resource_ids_string.present? ? "field(id,#{resource_ids_string})" : "")
  end

  private

  def check_resources_enabled?
    program_view? ? @current_program.resources_enabled? : @current_organization.resources_enabled_any?
  end

  def set_sort_params
    @sort_field = sort_field
    @sort_order = sort_order
    @search_query = params[:search] 
  end

  def check_management_access
    @admin_view = (program_view? ? (current_user && current_user.is_admin?) : wob_member.try(:admin?))
  end

  def check_not_management_access
    !(program_view? ? (current_user && current_user.is_only_admin?) : wob_member.is_only_admin?)
  end

  def get_resource
    @resource = program_view? ? @current_program.resource_publications.find_by(resource_id: params[:id]).try(:resource) : @current_organization.resources.find_by(id: params[:id])
    handle_invalid_case("common_text.error_msg.page_not_found") if @resource.nil?
  end

  def get_accessible_resource
    resource = @current_program.resource_publications.find_by(resource_id: params[:id]).try(:resource)
    if resource.nil?
      handle_invalid_case("common_text.error_msg.page_not_found")
    elsif current_user.blank? || (current_user.roles & resource.roles).empty?
      handle_invalid_case("common_text.error_msg.permission_denied")
    else
      @resource = current_user.accessible_resources.find(params[:id])
    end
  end

  def handle_resources_admin_view
    if program_view?
      @reorder_view = params[:reorder].present?
      @resources = @reorder_view ? current_user.accessible_resources(admin_view: true).includes(:translations, :ratings) : current_user.accessible_resources(sort_field: @sort_field, sort_order: @sort_order, admin_view: true).paginate(:per_page => PER_PAGE, :page => params[:page] || 1).includes(:translations, :resource_publications, :ratings)
      resource_and_program_roles
    else
      @resources = @current_organization.sorted_resources(@sort_field, @sort_order).paginate(:per_page => PER_PAGE, :page => params[:page] || 1)
    end
    track_activity_for_ei(EngagementIndex::Activity::VIEW_RESOURCE_LIST)
  end

  def resource_params(action)
    params.require(:resource).permit(Resource::MASS_UPDATE_ATTRIBUTES[action])
  end

  def resource_publication_params(action)
    params[:resource][:resource_publications][:admin_view_id] = nil if params[:resource][:resource_publications].present? && params[:resource][:resource_publications][:show_in_quick_links].present?
    params[:resource] && params[:resource][:resource_publications] && params[:resource][:resource_publications].permit(ResourcePublication::MASS_UPDATE_ATTRIBUTES[action]) || {}
  end

  def sort_field
    program_view? ? (%w{position title}.include?(params[:sort]) ? params[:sort] : POSITION) : 'title'
  end

  def sort_order
    %w{asc desc}.include?(params[:order]) ? params[:order] : 'asc'
  end

  def resource_program_roles
    if params[:resource][:program_ids].present?
      program_ids = @current_organization.programs.where(id: params[:resource][:program_ids]).pluck(:id)
      program_hash = Hash[program_ids.collect {|id| [id, []]}]
      program_roles = Role.where(program_id: program_ids)
      if params[:resource][:role_ids].present?
        program_roles = program_roles.where(id: params[:resource][:role_ids])
        [program_ids, program_hash.merge(program_roles.group_by(&:program_id))]
      else
        [program_ids, program_hash]
      end
    else
      [[], {}]
    end
  end

  def param_to_sort_field_map(sort_param)
    case sort_param
    when POSITION
      POSITION
    when 'title'
      'title.sort'
    else
      sort_param
    end  
  end

  ## The whole below operation can be substituted with something like,
  ## resource.program_ids = or resource.programs = []
  ## But, the resource_publications have **position** column which needs to be set, currently this is done
  ## using callbacks but the resource.program_ids = [] will skip it.
  def setup_resource_publications!(resource, program_ids)
    resource_publications = resource.resource_publications
    if program_ids.present?
      resource_publications.where("program_id NOT IN (?)", program_ids).destroy_all
      eligible_programs(program_ids, resource_publications).each do |program_id|
        resource.resource_publications.build(program_id: program_id)
      end
      resource.save!
    else
      resource_publications.destroy_all
    end
  end

  def setup_role_resources!(resource, program_roles_hash)
    if program_view?
      resource.resource_publications.find_by(program_id: @current_program.id).role_ids = program_roles_hash[@current_program.id].collect(&:id)
    else
      resource.resource_publications.each do |resource_publication|
        resource_publication.role_ids = program_roles_hash[resource_publication.program_id].collect(&:id)
      end
    end
  end

  def eligible_programs(program_ids, resource_publications)
    program_ids.select do |program_id|
      resource_publications.find{|resource_publication| resource_publication.program_id == program_id }.blank?
    end
  end

  def handle_invalid_case(error_message_key)
    flash[:error] = error_message_key.translate
    redirect_to program_view? ? resources_path : resources_path(organization_level: true)
  end

  def resource_and_program_roles
    resources_arel = @resources.includes(:roles)
    @resource_roles = {}
    resources_arel.each do |resource|
      @resource_roles[resource.id] = resource.roles.select{|role| role.program_id == @current_program.id }.collect(&:name)
    end
    @program_role_names = RoleConstants.program_roles_mapping(@current_program)
  end
end
