class AdminViewsController < ApplicationController
  include ChronusS3Utils
  include AdminViewsHelper
  include DateProfileFilter

  DEFAULT_PER_PAGE = 25
  LOCATION_AUTOCOMPLETE_LIMIT = 100
  SEPARATOR = ", "
  MULTI_TRACK_ADMIN_ACCESSIBLE_ACTIONS = [:show, :bulk_confirmation_view, :get_invite_to_program_roles, :invite_to_program, :get_add_to_program_roles, :add_to_program, :export_csv, :select_all_ids]

  skip_before_action :back_mark_pages, :except => [:show, :bulk_confirmation_view]
  skip_before_action :login_required_in_program
  skip_before_action :require_program, :only => [:new, :locations_autocomplete, :create, :edit, :update, :destroy, :show, :invite_to_program, :bulk_confirmation_view, :select_all_ids, :add_to_program, :get_invite_to_program_roles, :get_add_to_program_roles, :export_csv, :suspend_member_membership, :reactivate_member_membership, :remove_member, :toggle_favourite]

  before_action :set_bulk_dj_priority, only: [:bulk_confirmation_view, :remove_user, :remove_member, :suspend_membership, :reactivate_membership, :add_role, :add_or_remove_tags, :add_to_program, :invite_to_program]
  before_action :login_required_in_organization
  allow :exec => :logged_in_at_current_level?
  allow exec: :check_is_admin?, except: MULTI_TRACK_ADMIN_ACCESSIBLE_ACTIONS

  before_action :get_admin_view, :except => [:new, :locations_autocomplete, :create, :get_add_to_program_roles, :auto_complete_for_name, :preview_view_details, :fetch_survey_questions, :bulk_add_users_to_project]
  allow :exec => :is_editable?, :only => [:destroy]
  allow exec: :check_is_admin_or_multi_track_admin?, only: MULTI_TRACK_ADMIN_ACCESSIBLE_ACTIONS

  before_action :fetch_user_or_members_from_params, :only => [:remove_user, :suspend_membership, :reactivate_membership,
    :add_or_remove_tags, :invite_to_program, :add_to_program, :resend_signup_instructions, :suspend_member_membership, :reactivate_member_membership, :remove_member]
  before_action :fetch_source_info, :only => [:show, :new, :edit, :create, :update, :fetch_admin_view_details, :preview_view_details]

  before_action :set_default_dynamic_params, only: MULTI_TRACK_ADMIN_ACCESSIBLE_ACTIONS

  before_action :redirect_if_bulk_remove_limit_exceeded, only: [:remove_user, :remove_member]
  before_action :get_users_for_removal_or_suspension, only: [:suspend_membership, :remove_user]
  before_action :get_members_for_removal_or_suspension, only: [:suspend_member_membership, :remove_member]

  module REFERER
    ADMIN_VIEW = "admin_view"
    MEMBER_PATH = "members_path"
  end

  def show
    @src_path = params[:src]
    @my_filters = []
    is_program_view = @admin_view.is_program_view?
    @all_admin_views = is_program_view ? @current_program.admin_views.defaults_first : @current_organization.admin_views.defaults_first
    @other_admin_views = @all_admin_views - [@admin_view]
    @other_admin_views = AdminView.get_admin_views_ordered(@other_admin_views)
    @admin_view_result = []
    @other_admin_views.each do |admin_view|
      admin_view_hash = generate_hash(admin_view, false)
      @admin_view_result << admin_view_hash
    end

    @admin_view_result = @admin_view_result.to_json
    @items_per_page = (params["pageSize"] || AdminViewsController::DEFAULT_PER_PAGE).to_i
    @sort_param = params[:sort].present? ? params[:sort].values.first["field"] : AdminView::DEFAULT_SORT_PARAM
    @sort_order = params[:sort].present? ? params[:sort].values.first["dir"] : AdminView::DEFAULT_SORT_ORDER
    dynamic_filters = dynamic_filter_params
    initialize_date_range_filter(dynamic_filters[:meeting_request_fields], dynamic_filters[:mentoring_requests_fields]) if dynamic_filters[:meeting_request_fields].present? || dynamic_filters[:mentoring_requests_fields].present?
    @alert = @admin_view.alerts.find_by(id: params[:alert_id])
    @objects = @admin_view.generate_view(@sort_param, @sort_order, true, {:page => params[:page] || 1, :per_page => @items_per_page}, dynamic_filters, @alert, @date_ranges)
    object_ids = is_program_view ? @objects.collect(&:member_id) : @objects.collect(&:id)
    @profile_answers_hash = Member.prepare_answer_hash(object_ids, @admin_view.admin_view_columns.custom.pluck(:profile_question_id))
    @member_program_and_roles = MemberProgramAndRoleInfoService.new(@current_organization).fetch_member_roles_hash(object_ids) unless is_program_view
    @admin_view_columns = get_admin_view_columns_for_display(@admin_view, is_program_view)
    handle_dynamic_filter_params
    #set_remove_users_warning
    render :json => {:results => render_to_string("admin_views/_admin_view_result.html", :layout => false), :total => @objects.total_entries, :field => @sort_param, :dir => @sort_order, :perPage => @items_per_page, :filters => params[:filter], :dateRanges => @date_ranges_csv || {}} if params[:default]
  end

  def new
    if params[:is_program_view].present?
      @all_admin_views = params[:is_program_view] == "true" ? @current_program.admin_views : @current_organization.admin_views
    else
      @all_admin_views = current_program_or_organization.admin_views
    end

    @admin_view = @all_admin_views.new
    @all_tags_list = @current_program.get_all_tags if @admin_view.is_program_view? && @current_organization.has_feature?(FeatureName::MEMBER_TAGGING)
    fetch_profile_questions_and_programs
    @role = @current_program.roles.find(params[:role]) if params[:role]
  end

  def locations_autocomplete
    scope = AdminView::LocationScope.valid_values.include?(params[:scope]) ? params[:scope] : AdminView::LocationScope::COUNTRY
    selected_columns = get_selected_columns_for_locations_autocomplete(scope)
    locations_arel = Location.arel_table
    locations = []
    ["#{params[:search]}%", "%#{params[:search]}%"].each do |query|
      locations.concat(Location.distinct.order(selected_columns).where(locations_arel[scope].matches(query)).limit(LOCATION_AUTOCOMPLETE_LIMIT).select(selected_columns))
    end
    list = get_list_for_locations_autocomplete(locations, selected_columns)
    render json: list.to_json
  end

  def create
    save_admin_view
    @role = current_program.roles.find(params[:admin_view][:role]) if params[:admin_view] && params[:admin_view][:role]
    respond_to do |format|
      format.html {
        flash[:notice] = "flash_message.admin_view_flash.action_success".translate(:view_title => h(@admin_view.title), :action => "display_string.created".translate)
        redirect_view_path
      }
      format.js
    end
  end

  def edit
    is_program_view = @admin_view.is_program_view?
    @all_admin_views = is_program_view ? @current_program.admin_views : @current_organization.admin_views
    if @admin_view.editable? || params[:editable]
      @filter_params = @admin_view.filter_params_hash
      @all_tags_list = @current_program.get_all_tags if is_program_view && @current_organization.has_feature?(FeatureName::MEMBER_TAGGING)
    else
      @applied_filters = is_program_view ? @admin_view.get_applied_filters : @admin_view.get_org_applied_filters(:program_customized_term => _program)
    end
    fetch_profile_questions_and_programs
    @admin_view_columns = get_admin_view_columns_for_display(@admin_view, is_program_view)
    @role = current_program.roles.find(params[:role]) if params[:role]
    render :action => :new
  end

  def update
    save_admin_view
    respond_to do |format|
      format.html {
        flash[:notice] = "flash_message.admin_view_flash.action_success".translate(:view_title => @admin_view.title, :action => "display_string.updated".translate)
        redirect_view_path
      }
      format.js
    end
  end

  def destroy
    @admin_view.destroy
    flash[:notice] = "flash_message.admin_view_flash.action_success".translate(:view_title => @admin_view.title, :action => "display_string.deleted".translate)
    redirect_to @admin_view.is_program_view? ? admin_view_all_users_path : admin_view_all_members_path
  end


  ####################################
  ### Custom Rest Actions
  ####################################

  def select_all_ids
    user_ids = @admin_view.generate_view(AdminView::DEFAULT_SORT_PARAM, AdminView::DEFAULT_SORT_ORDER, true, {}, dynamic_filter_params)
    render :json => user_ids.collect{|user_id| user_id.to_s }.to_json
  end

  def add_role
    user_ids = params[:admin_view][:users].split(",")
    role_names_to_add = (params[:admin_view][:role_names] || [])
    if user_ids.blank?
      flash[:error] = "flash_message.admin_view_flash.no_user_or_member_selected".translate(:element => "display_string.User".translate)
    else
      roles_added = User.promote_to_roles(@current_program, user_ids, role_names_to_add, current_user, params[:admin_view][:reason])
      flash[:notice] = "flash_message.admin_view_flash.add_role_success".translate if roles_added
    end
    redirect_to admin_view_path(@admin_view)
  end

  def add_or_remove_tags
    allow! :exec => :check_member_tagging_enabled?
    method_name = params[:remove_tags].to_s.to_boolean ? :remove_tags : :add_tags
    AdminView.send_later(method_name, @users.collect(&:id), params[:admin_view][:tag_list])
    flash[:notice] = "feature.admin_view.content.#{method_name}_notice_flash_html".translate(tags: params[:admin_view][:tag_list].gsub(",", ", "))
    redirect_to admin_view_path(@admin_view)
  end

  def remove_user
    remove_user = RemoveUser.new(@users_for_removal_or_suspension, @user_ids_ignored_for_removal_or_suspension, current_user: current_user)
    remove_user.delay(queue: DjQueues::HIGH_PRIORITY).remove_users_background
    @progress = remove_user.progress
    render "remove_user.js.erb"
  end

  def on_remove_user_completion
    invalid_users = User.find(params[:invalid_user_ids]) if params[:invalid_user_ids]
    if invalid_users.present?
      flash[:error] = "flash_message.admin_view_flash.remove_user_failure".translate(count: invalid_users.size, users: invalid_users.map{|u| u.name(:name_only => true)}.join(', '))
    else
      flash[:notice] = "flash_message.admin_view_flash.remove_user_success".translate
    end
    redirect_to admin_view_path(@admin_view)
  end

  def suspend_membership
    suspended = User.suspend_users_by_ids(@users_for_removal_or_suspension.pluck(:id), current_user, params[:admin_view][:reason])
    flash[:notice] = "flash_message.admin_view_flash.suspend_success_v1".translate(program: _program) if suspended
    redirect_to admin_view_path(@admin_view)
  end

  def reactivate_membership
    reactivated = User.activate_users_by_ids(@users.pluck(:id), current_user)
    flash[:notice] = "flash_message.admin_view_flash.reactivate_success".translate(program: _program) if reactivated
    redirect_to admin_view_path(@admin_view)
  end

  def invite_to_program
    if params[:role].blank? || (role_names = params[params[:role]]).blank?
      flash[:error] = "flash_message.program_invitation_flash.roles_empty".translate
      redirect_to admin_view_path(@admin_view) and return
    end
    role_type = ProgramInvitation::RoleType::STRING_TO_TYPE[params[:role]] || ProgramInvitation::RoleType::ASSIGN_ROLE
    @program = @current_organization.programs.find(params[:admin_view][:program_id])
    @message = params[:admin_view][:message]
    invitor = wob_member.user_in_program(@program)
    Program.delay(:queue => DjQueues::HIGH_PRIORITY).delayed_sending_of_program_invitations(@program.id, params[:admin_view][:members].split(',').map(&:to_i), @message, invitor.id, role_names, role_type, locale: current_locale, is_sender_admin: true)
    click_here = view_context.link_to("flash_message.program_invitation_flash.click_here".translate, program_invitations_path(:root => @program.root))
    flash[:notice] = get_safe_string + "flash_message.admin_view_flash.invite_to_program_success_v3".translate(:program => @program.name) + " " + "flash_message.program_invitation.click_here_to_view_invitations_v1_html".translate(:click_here => click_here) + "flash_message.program_invitation.note_to_user".translate
    redirect_to admin_view_path(@admin_view)
  end

  def add_to_program
    program = @current_organization.programs.find(params[:admin_view][:program_id])
    roles = params[:admin_view][:role_names]
    invitor = wob_member.user_in_program(program)

    added = false
    @members.each do |member|
      member_added = program.build_and_save_user!({:created_by => invitor }, roles, member, {send_email: true, admin: invitor})
      added ||= member_added
    end
    create_add_to_program_flash(@members, roles, program) if added
    redirect_to appropriate_referrer_path(params[:from], @admin_view, @members.first)
  end

  def export_csv
    @tmp_file_name = S3Helper.embed_timestamp("#{@admin_view.title.to_html_id}.csv")
    respond_to do |format|
      format.csv { render_csv_stream }
    end
  end

  def resend_signup_instructions
    unless @current_program.email_template_disabled_for_activity?(ResendSignupInstructions)
      User.delay(:queue => DjQueues::HIGH_PRIORITY).resend_instructions_email(@current_program, @users.collect(&:id), JobLog.generate_uuid)
      flash[:notice] = "flash_message.admin_view_flash.resend_instructions_success".translate(:count => @users.size)
    end
    redirect_to appropriate_referrer_path(params[:from], @admin_view, @users.first.member)
  end

  def bulk_confirmation_view
    @bulk_action_title = params[:bulk_action_confirmation][:title]
    @bulk_action_type = params[:bulk_action_confirmation][:type].to_i
    user_or_member_id_array = params[:bulk_action_confirmation][:users]

    if @admin_view.is_program_view?
      @users = @current_program.all_users.select(:id, :member_id, :program_id).includes(:member).where(id: user_or_member_id_array)
      get_users_for_removal_or_suspension
    else
      update_program_listing_service_scoped_programs
      @members = @current_organization.members.select(:id, :first_name, :last_name, :admin, :organization_id).where(id: user_or_member_id_array)
    end
    render partial: "admin_views/bulk_action_confirmation.html"
  end

  def bulk_add_users_to_project
    @group = current_program.groups.find(params[:group_id].to_i)
    @group_roles = current_program.roles.for_mentoring.includes(:permissions, customized_term: :translations)
    @users = current_program.users.where(id: params[:user_ids].map(&:to_i)) if params[:user_ids].present?
  end

  def get_invite_to_program_roles
    @program = @current_organization.programs.find(params[:program_id])
    @user = wob_member.user_in_program(@program)
  end

  def get_add_to_program_roles
    @program = @current_organization.programs.find(params[:program_id])
  end

  def suspend_member_membership
    Member.delay.suspend_members(@members_for_removal_or_suspension.pluck(:id), wob_member, params[:admin_view][:reason], JobLog.generate_uuid)
    if @members_ignored_for_removal_or_suspension.any?
      flash[:error] = "flash_message.admin_view_flash.suspend_member_failure".translate(count: @members_ignored_for_removal_or_suspension.size, members: @members_ignored_for_removal_or_suspension.map { |m| m.name(name_only: true) }.join(COMMON_SEPARATOR))
    else
      flash[:notice] = "flash_message.admin_view_flash.suspend_member_success".translate(organization_name: @current_organization.name)
    end
    redirect_to admin_view_path(@admin_view)
  end

  def reactivate_member_membership
    Member.delay.reactivate_members(@members.collect(&:id), wob_member, JobLog.generate_uuid)
    flash[:notice] = "flash_message.admin_view_flash.reactivate_member_success".translate(organization_name: @current_organization.name)
    redirect_to admin_view_path(@admin_view)
  end

  def remove_member
    @members_for_removal_or_suspension.map(&:destroy)
    if @members_ignored_for_removal_or_suspension.any?
      flash[:error] = "flash_message.admin_view_flash.remove_member_failure".translate(count: @members_ignored_for_removal_or_suspension.size, members: @members_ignored_for_removal_or_suspension.map { |m| m.name(name_only: true) }.join(COMMON_SEPARATOR))
    else
      flash[:notice] = "flash_message.admin_view_flash.remove_member_success".translate(organization_name: @current_organization.name)
    end
    redirect_to admin_view_path(@admin_view)
  end

  def auto_complete_for_name
    @admin_views = current_program.admin_views.select([:id, :title, :favourite, :created_at, :description, :favourited_at])
    @admin_views = @admin_views.where("title LIKE ?", "%#{params[:search]}%") if params[:search].present?
    admin_view_result = []
    list_admin_views = AdminView.get_admin_views_ordered(@admin_views)
    list_admin_views.try(:each) do |admin_view|
      admin_view_hash = generate_hash(admin_view)
      admin_view_result << admin_view_hash
    end
    @admin_views = @admin_views.pluck(:title) if @admin_views.present?
    respond_to do |format|
      format.json do
        render :json => admin_view_result.to_json
      end
    end
  end

  def fetch_admin_view_details
    @admin_view_count = @admin_view.generate_view("", "", false).size
    @admin_view_filters = @admin_view.get_applied_filters
    @campaign = params[:campaign_id].blank? ? nil : current_program.user_campaigns.find(params[:campaign_id])
  end

  def preview_view_details
    @admin_view = @current_program.admin_views.find(params[:admin_view_id])
    @admin_view_filters = @admin_view.get_applied_filters
    @admin_view_users_count = @admin_view.generate_view("", "", false).size
    render :template => 'admin_views/preview_view_details', :formats => [:js]
  end

  def toggle_favourite
    @admin_view.favourite ? @admin_view.unset_favourite! : @admin_view.set_favourite!
  end

  def fetch_survey_questions
    @survey = program.surveys.find(params[:survey_id]) if params[:survey_id].present?
    @survey_questions = @survey.get_questions_in_order_for_report_filters if @survey
    @prefix_id = params[:prefix_id].to_i
    @rows_size = params[:rows_size].to_i
  end

  private

  def fetch_profile_questions_and_programs
    if @admin_view.is_program_view?
      @profile_questions = @current_program.profile_questions_for(@current_program.roles_without_admin_role.collect(&:name), {default: false, skype: @current_organization.skype_enabled?, fetch_all: true, all_role_questions: true})
    else
      update_program_listing_service_scoped_programs
      @profile_questions = @current_organization.role_questions.collect(&:profile_question).uniq
    end
  end

  def render_csv_stream
    @user_ids = (params[:admin_view] || {})[:users].to_s.split(',')
    CSVStreamService.new(response).setup!(@tmp_file_name, self) do |stream|
      @admin_view.report_to_stream(stream, @user_ids, get_admin_view_columns_for_display(@admin_view, @admin_view.is_program_view?), params[:date_ranges])
    end
  end

  def get_selected_columns_for_locations_autocomplete(scope)
    selected_columns = [AdminView::LocationScope::COUNTRY]
    selected_columns.unshift(AdminView::LocationScope::STATE) if scope == AdminView::LocationScope::STATE || scope == AdminView::LocationScope::CITY
    selected_columns.unshift(AdminView::LocationScope::CITY) if scope == AdminView::LocationScope::CITY
    selected_columns
  end

  def get_list_for_locations_autocomplete(locations, selected_columns)
    locations.map do |location|
      ret = [location.country]
      ret.unshift(location.state) if selected_columns.include?(AdminView::LocationScope::STATE)
      ret.unshift(location.city)  if selected_columns.include?(AdminView::LocationScope::CITY)
      ret.compact.join(AdminView::LOCATION_SCOPE_SPLITTER)
    end.uniq
  end

  def prepare_json_objects(s3_link)
    if @s3_link
      {
        success: true,
        s3Link: view_context.link_to(params[:filename], @s3_link, target: "_blank"),
        flash: "flash_message.admin_view_flash.export_csv_success_v2".translate
      }
    else
      {success: false}
    end
  end

  def save_admin_view
    if params[:is_program_view].present?
      new_admin_view = (params[:is_program_view] == "true" ? @current_program : @current_organization).admin_views.new
    elsif params[:is_org_view]
      new_admin_view = @current_organization.admin_views.new
    else
      new_admin_view = current_program_or_organization.admin_views.new
    end
    @admin_view = @admin_view || new_admin_view
    columns_array = params[:admin_view].delete(:admin_view_columns)
    @admin_view.title = params[:admin_view].delete(:title)
    @admin_view.description = params[:admin_view].delete(:description)
    set_default_program_role_state_filter_to_params(@admin_view)
    if params[:admin_view][:role]
      @admin_view.role_id = params[:admin_view][:role]
      role = Role.find(@admin_view.role_id)
      unless params[:admin_view]["#{role.name}_eligibility_message"].nil?
        role.eligibility_message =  params[:admin_view]["#{role.name}_eligibility_message"]
        role.save!
      end
    end
    # The fields below cannot be edited/updated for default views
    if @admin_view.editable? || params[:admin_view][:allow_filter_update]
      @admin_view.filter_params = AdminView.convert_to_yaml(admin_view_filter_params)
    end
    @admin_view.default_view = params[:admin_view][:default_view] if params[:admin_view][:default_view]
    ActiveRecord::Base.transaction do
      @admin_view.save!
      @admin_view.save_admin_view_columns!(columns_array) if columns_array
      @admin_view.create_default_columns if params[:admin_view][:create_default_columns] && @admin_view.admin_view_columns.count.zero?
      # creating default all_members admin view columns if no columns associated.
    end
  end

  def update_program_listing_service_scoped_programs(options = {})
    member = options[:member] || wob_member
    base = options[:base] || @current_organization
    scope = options[:scope] || self
    ProgramsListingService.fetch_programs scope, base do |all_programs|
      programs_scope = all_programs
      programs_scope = programs_scope.where(id: member.managing_programs(ids_only: true)) if member&.admin_only_at_track_level?
      programs_scope.ordered.includes(:roles)
    end
  end

  def admin_view_filter_params
    filter_params = @admin_view.filter_names.inject({}) do |filter_params, filter_name|
      value = params[:admin_view][filter_name]
      filter_params[filter_name] = value.is_a?(ActionController::Parameters) ? value.to_unsafe_h : value if value
      filter_params
    end

    filter_params[:profile] = handle_profile_related_filter_params(filter_params) if params[:admin_view][:profile]
    if params[:admin_view][:connection_status].present? && params[:admin_view][:connection_status][:advanced_options].present?
      filter_params[:connection_status][:advanced_options] = handle_advanced_options_choices(filter_params)
    end
    (filter_params[:program_role_state] ||= @default_program_role_state_hash) if @admin_view.is_organization_view?
    filter_params[:program_role_state][:filter_conditions] = format_program_role_state_hash(filter_params[:program_role_state][:filter_conditions]) if format_program_role_state_hash?(params, @admin_view)
    filter_params
  end

  def fetch_user_or_members_from_params
    @admin_view.is_program_view? ? fetch_user_from_params : fetch_members_from_params
  end

  def fetch_user_from_params
    user_ids = params[:admin_view][:users].split(",")
    @users = @current_program.all_users.where(id: user_ids)
    if @users.blank?
      flash[:error] = "flash_message.admin_view_flash.no_user_or_member_selected".translate(element: "display_string.User".translate)
      redirect_to admin_view_path(@admin_view)
    end
  end

  def fetch_members_from_params
    member_ids = params[:admin_view][:members].split(",")
    @members = @current_organization.members.where(id: member_ids)
    if @members.blank?
      flash[:error] = "flash_message.admin_view_flash.no_user_or_member_selected".translate(element: 'activerecord.models.member'.translate)
      redirect_to admin_view_path(@admin_view)
    end
  end

  def redirect_if_bulk_remove_limit_exceeded
    users_or_members = @admin_view.is_program_view? ? @users : @members
    if users_or_members.size > AdminView::BULK_LIMIT
      flash[:error] = "feature.admin_view.content.bulk_delete_limit_exceeded".translate(count: AdminView::BULK_LIMIT)
      redirect_to admin_view_path(@admin_view)
    end
  end

  def get_admin_view
    if @current_organization.standalone?
      program_options = {:program_id => [@current_organization.id, @current_program.id]}
      if params[:default_view].present?
        @admin_view = AdminView.find_by!({:default_view => params[:default_view]}.merge(program_options))
      else
        @admin_view = AdminView.find_by!({:id => params[:id]}.merge(program_options))
      end
    else
      current_program_or_organization = @current_organization if params[:is_org_view].present?
      current_program_or_organization ||= program_view? ? @current_program : @current_organization
      if params[:default_view].present?
        @admin_view = current_program_or_organization.admin_views.find_by!(default_view: params[:default_view])
      else
        @admin_view = current_program_or_organization.admin_views.find_by!(id: params[:id])
      end
    end
  end

  def check_member_tagging_enabled?
    @current_organization.has_feature?(FeatureName::MEMBER_TAGGING)
  end

  def set_remove_users_warning
    # Sets a warning flash message if there is any background job running to remove users.
    djs = DJExtension.get_running_djs("RemoveUser", "remove_user")
    count = 0
    djs.each do |dj|
      progress = YAML.load(dj.handler).object.progress
      count+= progress.maximum if progress.ref_obj.program == current_program
    end
    flash.now[:warning] = "feature.admin_view.content.remove_user_warning".translate(:count => count, :user => "feature.admin_view.content.user".translate(:count => count), :admin => _admins, :program => _program) if count > 0
  end

  def is_editable?
    @admin_view.editable?
  end

  def fetch_source_info
    @source_info = params[:source_info].try(:permit, [:controller, :action, :id, :category, :section])
    @used_as_filter = @source_info.present?
  end

  def redirect_view_path
    redirect_to_path = @source_info ? url_for(@source_info.merge(only_path: true, admin_view_id: @admin_view.id)) : admin_view_path(@admin_view)
    redirect_to redirect_to_path
  end

  def create_add_to_program_flash(members, roles, program)
    if members.count > 1
      role_str = roles.collect{|role| RoleConstants.to_program_role_names(program, [role])[0].pluralize}.join(', ')
      flash[:notice] = "flash_message.user_flash.multiple_user_add_to_program_success".translate(role: role_str, program: _program)
    else
      role_str = roles.collect{|role| RoleConstants.to_program_role_names(program, [role])[0]}.join(', ')
      flash[:notice] = "flash_message.user_flash.single_user_add_to_program_success".translate(:role => role_str, :program => _program)
    end
  end

  def appropriate_referrer_path(referrer, admin_view, member_user_object)
    (referrer == AdminViewsController::REFERER::MEMBER_PATH) ? member_path(member_user_object) : admin_view_path(admin_view)
  end

  def get_admin_view_columns_for_display(admin_view, is_program_view)
    columns = admin_view.admin_view_columns.includes(:profile_question => :translations)
    columns = columns.where("column_key IS NULL OR column_key != '#{AdminViewColumn::Columns::Key::LANGUAGE}'") if admin_view.language_columns_exists? && (!admin_view.languages_filter_enabled?)
    if is_program_view
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::ProgramDefaults.meeting_request_defaults.keys) unless @current_program.calendar_enabled?
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::ProgramDefaults.mentoring_mode_column) unless @current_program.consider_mentoring_mode?
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::ProgramDefaults.ongoing_mentoring_dependent_columns) unless @current_program.ongoing_mentoring_enabled?
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::ProgramDefaults.mentoring_request_for_mentors_defaults.keys) unless @current_program.ongoing_mentoring_enabled? && @current_program.matching_by_mentee_alone?
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::ProgramDefaults.mentoring_request_for_mentees_defaults.keys) unless @current_program.ongoing_mentoring_enabled? && (@current_program.matching_by_mentee_alone? || @current_program.matching_by_mentee_and_admin?)
    else
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::ProgramDefaults.mentoring_mode_column)
      columns = columns.where("column_key IS NULL OR column_key NOT IN (?)", AdminViewColumn::Columns::OrganizationDefaults.engagement_columns.keys) unless admin_view.program.ongoing_enabled_programs_present?
    end
    columns
  end

  def initialize_date_range_filter(meeting_requests_filters, mentoring_requests_filters)
    date_range_filters = (meeting_requests_filters||[]) + (mentoring_requests_filters||[])
    @date_ranges = {}
    @date_ranges_csv = {:date_ranges => {}}
    date_range_filters.group_by{|f| f["field"]}.each do |field, filter|
      value = filter[0]['value']
      start_time = @admin_view.convert_to_date(value.strip)
      end_time = filter.count > 1 ?  @admin_view.convert_to_date(filter[1]["value"].strip) : start_time
      end_time = end_time.end_of_day
      @date_ranges[field] = (start_time..end_time)
      @date_ranges_csv[:date_ranges][field] = {:start_time => start_time, :end_time => end_time}
    end
  end

  def get_users_for_removal_or_suspension
    @users_for_removal_or_suspension = User.removal_or_suspension_scope(@users, @current_program, wob_member.id)
    @user_ids_ignored_for_removal_or_suspension = @users.pluck(:id) - @users_for_removal_or_suspension.pluck(:id)
  end

  def get_members_for_removal_or_suspension
    @members_for_removal_or_suspension = Member.removal_or_suspension_scope(@members, @current_organization, wob_member.id)
    @members_ignored_for_removal_or_suspension = @members.where.not(id: @members_for_removal_or_suspension.pluck(:id))
  end

  def dynamic_filter_params
    # Structure of params[:filter]:
    # "filter"=>{"logic"=>"and", "filters"=>{
    # "0"=>{"field"=>"meeting_requests_accepted", "operator"=>"eq", "value"=>"8/4/2014"}, "1"=>{"field"=>"meeting_requests_accepted", "operator"=>"eq", "value"=>"8/5/2014"},
    # "2"=>{"logic"=>"and",
    #       "filters"=>{"0"=>{"field"=>"meeting_requests_pending", "operator"=>"eq", "value"=>"8/4/2014"},
    #                   "1"=>{"field"=>"meeting_requests_pending", "operator"=>"eq", "value"=>"8/5/2014"}
    #                  }
    # },
    # "3"=>{"field"=>"groups", "operator"=>"eq", "value"=>"6"}}}
    if params[:filter].present? && params[:filter] != "null"
      filter_values = params[:filter][:filters].values.delete_if{|filter| filter["filters"].present?}
      filter_values += params[:filter][:filters].values.map{|filter| filter["filters"].try(:values)}.flatten.compact

      member_id = filter_values.select { |v| v["field"] == AdminViewColumn::Columns::Key::MEMBER_ID }
      first_name = filter_values.select{|v| v["field"] == AdminViewColumn::Columns::Key::FIRST_NAME}
      last_name = filter_values.select{|v| v["field"] == AdminViewColumn::Columns::Key::LAST_NAME}
      email = filter_values.select{|v| v["field"] == AdminViewColumn::Columns::Key::EMAIL}
      role_names = filter_values.select{|v| v["field"] == AdminViewColumn::Columns::Key::ROLES}
      non_profile_fields = filter_values.select{|v| AdminViewColumn::Columns.all.include?(v["field"])}
      profile_fields = filter_values.select{|v| v["field"] =~ /column/}
      meeting_request_fields = filter_values.select{|v| AdminViewColumn::Columns::ProgramDefaults.meeting_request_defaults.keys.include?(v["field"])}
      mentoring_requests_fields = filter_values.select{|v| AdminViewColumn::Columns::ProgramDefaults.mentoring_request_for_mentors_defaults.keys.include?(v["field"]) || AdminViewColumn::Columns::ProgramDefaults.mentoring_request_for_mentees_defaults.keys.include?(v["field"])}
    end
    filter_params = Hash.new
    filter_params[:role_names] = role_names.first["value"].split(ProfileQuestion::SEPERATOR) if role_names.present?
    filter_params[:member_id] = member_id.first["value"] if member_id.present?
    filter_params[:first_name] = first_name.first["value"] if first_name.present?
    filter_params[:last_name] = last_name.first["value"] if last_name.present?
    filter_params[:email] = email.first["value"] if email.present?
    filter_params[:profile_field_filters] = profile_fields if profile_fields.present?
    filter_params[:non_profile_field_filters] = non_profile_fields if non_profile_fields.present?
    filter_params[:meeting_request_fields] = meeting_request_fields if meeting_request_fields.present?
    filter_params[:mentoring_requests_fields] = mentoring_requests_fields if mentoring_requests_fields.present?
    filter_params
  end

  def generate_hash(admin_view, with_source = true)
    admin_view_hash = Hash.new
    admin_view_hash["title"] = h(admin_view.title)
    admin_view_hash["description"] = h(admin_view.description)
    admin_view_hash["id"] = admin_view.id
    admin_view_hash["url"] = with_source ? admin_view_path_with_source(:show, admin_view: admin_view) : admin_view_path(admin_view)
    admin_view_hash["icon"] = admin_view.favourite_image_path
    admin_view_hash
  end

  def handle_profile_related_filter_params(filter_params)
    profile_filters = strip_choices(filter_params)
    handle_profile_filters_for_date_question(profile_filters)
  end

  def strip_choices(filter_params)
    profile_filters = filter_params[:profile]

    if profile_filters.is_a?(Hash)
      profile_filters[:questions].values.each do |prof_ques|
        profile_question = ProfileQuestion.where(id: prof_ques[:question]).first
        next if profile_question && (profile_question.location? || profile_question.date?)

        if prof_ques[:operator].present? && [AdminViewsHelper::QuestionType::IN.to_s, AdminViewsHelper::QuestionType::NOT_IN.to_s, AdminViewsHelper::QuestionType::MATCHES.to_s].include?(prof_ques[:operator])
          choices_string = prof_ques[:value].gsub(/\n|\r\n?/, " ")
          choices  = choices_string.split(",", -1).map(&:strip)
          prof_ques[:value] = choices.join(',')
        end
      end
    end
    profile_filters
  end

  def handle_profile_filters_for_date_question(profile_filters)
    if profile_filters.is_a?(Hash)
      profile_filters[:questions].values.each do |profile_question_details|
        profile_question = ProfileQuestion.where(id: profile_question_details[:question]).first

        if profile_question&.date?
          profile_question_details["operator"] = get_operator_for_date_profile_question(profile_question_details)
        end
      end
    end
    profile_filters
  end

  def handle_advanced_options_choices(filter_params)
    advanced_options_filters = filter_params[:connection_status][:advanced_options]

    if advanced_options_filters.is_a?(Hash)
      advanced_options_filters.each do |request_type, request_type_hash|
        request_type_hash.each do |role_type, role_type_hash|
          role_type_hash.each do |key, val|
            advanced_options_filters[request_type][role_type][key] = val.strip
            is_valid_input = true
            case key.to_i
            when AdminView::AdvancedOptionsType::LAST_X_DAYS
              is_valid_input = false if !/\A\d+\z/.match(val.strip)
            when AdminView::AdvancedOptionsType::AFTER
              is_valid_input = false unless valid_date_string?(val.strip)
            when AdminView::AdvancedOptionsType::BEFORE
              is_valid_input = false unless valid_date_string?(val.strip)
            end

            advanced_options_filters[request_type][role_type][key] = "" if advanced_options_filters[request_type][role_type][:request_duration] != key && key != "request_duration"

            unless is_valid_input
              advanced_options_filters[request_type][role_type][key] = ""
              advanced_options_filters[request_type][role_type][:request_duration] = AdminView::AdvancedOptionsType::EVER.to_s if advanced_options_filters[request_type][role_type][:request_duration] == key
            end
          end
        end
      end
    end
    advanced_options_filters
  end

  def valid_date_string?(date_string)
    begin
      Date.strptime(date_string, "date.formats.date_range".translate)
      return true
    rescue
      return false
    end
  end

  def handle_dynamic_filter_params
    @dynamic_filter_params = params[:dynamic_filters]
    missing_dynamic_filter_columns = check_dynamic_filter_params_if_columns_not_present(@dynamic_filter_params, @admin_view_columns.collect(&:column_key))
    if missing_dynamic_filter_columns.any?
      @dynamic_filter_params = {}
      flash.now[:error] = get_missing_dynamic_filter_columns_text(missing_dynamic_filter_columns, view_context.link_to("display_string.Click_here".translate, edit_admin_view_path(@admin_view)))
    end
  end

  def format_program_role_state_hash(program_role_state_hash)
    program_role_state_hash.values.each {|parent_row| parent_row.values.each {|child_row| child_row.each {|key, value| child_row[key] = value.reject(&:blank?)}}}
    program_role_state_hash
  end

  def format_program_role_state_hash?(params_hash, admin_view)
    admin_view.is_organization_view? && params_hash[:admin_view][:program_role_state].try(:[], :filter_conditions).present?
  end

  def set_default_program_role_state_filter_to_params(admin_view)
    return unless admin_view.is_organization_view?
    @default_program_role_state_hash = {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true, AdminView::ProgramRoleStateFilterObjectKey::INCLUSION => AdminView::ProgramRoleStateFilterObjectKey::INCLUDE}
  end

  def set_default_dynamic_params
    return unless wob_member.admin_only_at_track_level?
    params[:dynamic_filters] ||= {}
    params[:dynamic_filters].reverse_merge!(multi_track_admin: true)
  end

  def check_is_admin_or_multi_track_admin?
    check_is_admin? || (wob_member.admin_only_at_track_level? && track_level_admin_allowed_views?)
  end

  def track_level_admin_allowed_views?
    @admin_view.nil? || is_active_license_view?(@admin_view)
  end

  def is_active_license_view?(admin_view)
    admin_view.default_view == AbstractView::DefaultType::LICENSE_COUNT
  end

  def get_operator_for_date_profile_question(profile_question_details)
    operator = AdminView::ProfileQuestionDateType.get_mapping(profile_question_details["date_operator"])
    [AdminViewsHelper::QuestionType::ANSWERED.to_s, AdminViewsHelper::QuestionType::NOT_ANSWERED.to_s].include?(operator) ? operator : AdminViewsHelper::QuestionType::DATE_TYPE.to_s
  end
end
