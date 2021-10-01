class PagesController < ApplicationController
  include ApplicationHelper
  skip_before_action  :back_mark_pages,
    :login_required_in_program,
    :require_program

  before_action :fetch_pages
  before_action :fetch_page, only: [:show, :edit, :update, :publish, :destroy]
  before_action :check_program_listing_visibility, only: [:programs]
  before_action :set_layout_variables
  before_action :login_required_at_current_level, :except => [:show, :index, :programs, :mobile_prompt]
  before_action :check_login_required_at_current_level, :only => [:mobile_prompt]
  before_action :set_page_title_and_actions, :only => [:show, :index, :programs]
  before_action :set_login_mode, only: [:index]
  before_action :get_return_to_url, only: [:mobile_prompt]
  skip_before_action :show_mobile_prompt, :handle_terms_and_conditions_acceptance, :handle_pending_profile_or_unanswered_required_qs, :only => [:mobile_prompt]

  allow :exec => :has_management_access?, :except => [:show, :index, :programs, :mobile_prompt]
  allow :exec => :check_organization_admin_access, :only => [:programs_reordering, :reorder_programs]
  allow :exec => :check_mobile_browser?, :only => [:mobile_prompt]
  newrelic_ignore_apdex :only => [:show, :index]

  def show
    @no_wrapper_padding = true
    back_mark_pages if logged_in_program?
  end

  def programs
    @only_login = true
    fetch_programs
  end

  def index
    @no_wrapper_padding = true
    @page = @pages.first

    back_mark_pages if logged_in_program?
    render :action => 'show'
  end

  def mobile_prompt
    @return_to_url ||= session[:return_to_url] || program_root_url(get_root_url_options)
    @single_page_layout = true
    @mobile_prompt = true
  end

  def edit
  end

  def new
    @page = program_context.pages.new
    render :action => 'edit'
  end

  def update
    assign_user_and_sanitization_version(@page)
    if @page.update_attributes(page_params(:update))
      redirect_to page_path(@page)
    else
      render :action => 'edit'
    end
  end

  def publish
    @page.publish!
    redirect_to page_path(@page)
  end

  def create
    # In case of organization view or if the organization/program is standalone,
    # add the new page to the organization.
    if organization_view? || @current_organization.standalone?
      @page = @current_organization.pages.new(page_params(:create))
    else
      @page = @current_program.pages.new(page_params(:create))
    end

    assign_user_and_sanitization_version(@page)
    if @page.save
      redirect_to page_path(@page)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @page.destroy
    redirect_to pages_path
  end

  def sort
    params[:new_order].each_with_index do |id, index|
      @pages.find{|m| m.id == id.to_i}.update_attribute(:position, index+1)
    end
    head :ok
  end

  def programs_reordering
    @programs = @current_organization.tracks.published_programs.select([:id, :root, :parent_id]).ordered
  end

  def reorder_programs
    @current_organization.reorder_programs(params[:new_order])
    head :ok
  end


  # The sublayout for this controller
  def sub_layout
    "pages"
  end

  protected

  def fetch_programs
    ProgramsListingService.fetch_programs self, @current_organization do |all_programs|
      all_programs.published_programs.select(:id, :root, :parent_id).ordered.includes(:translations)
    end
  end

  def fetch_pages
    @admin_view = has_management_access?
    @base_pages_scope = Page.where(program_id: [@current_organization.id] + @current_organization.program_ids)
    @pages = program_context.standalone? ? @current_organization.pages : program_context.pages
    @pages = @pages.published unless @admin_view
    @pages = @pages.for_not_logged_in_users if program_context.logged_in_pages_enabled? && !logged_in_at_current_level?
  end

  def fetch_page
    @page = @base_pages_scope.find_by(id: params[:id])
    handle_invalid_cases
  end

  def set_layout_variables
    @single_page_layout = logged_in_at_current_level? && (params[:src] == "tab")
    @title = @page.try(:title) if @single_page_layout
    @title_description = "flash_message.pages.pages_description_v1".translate(program: _program) if @admin_view
  end

  def has_management_access?
    organization_view? ? (wob_member && wob_member.admin?) :
      (current_user && current_user.can_manage_custom_pages?)
  end

  # TODO maybe make sense to unify it and move to ApplicationController
  # Returns whether the current member is an organization admin.
  def check_organization_admin_access
    wob_member && wob_member.admin?
  end

  def set_page_title_and_actions
    @title = "feature.page.action.program_overview_pages".translate(:program => _Program)
    drop_down_array = [{label: "app_layout.label.add_new_page".translate, url: new_page_path, class: 'add_new_page_button btn btn-primary btn-large waves-effect'}]
    drop_down_array << [{label: "app_layout.label.reorder_programs".translate(programs: _Programs), url: programs_reordering_pages_path, class: 'reorder_programs'}] if params[:action] == 'programs'
    @page_action = drop_down_array if @admin_view
  end

  def get_root_url_options
    options = {subdomain: @current_organization.subdomain, host: @current_organization.domain}
    options.merge!({root: @current_program.root}) if @current_program.present?
    return options
  end

private

  def page_params(action)
    params.require(:page).permit(Page::MASS_UPDATE_ATTRIBUTES[action])
  end

  def check_login_required_at_current_level
    return true if params[:mobile_app_login].present?
    login_required_at_current_level
  end

  def get_return_to_url
    @mobile_app_login = params[:mobile_app_login].to_s.to_boolean
    return unless @mobile_app_login
    token_code = params[:token_code]
    auth_config_id = params[:auth_config_id]
    uniq_token = params[:uniq_token]
    @return_to_url = new_session_url(token_code: token_code, auth_config_id: auth_config_id, uniq_token: uniq_token)
  end

  def check_mobile_browser?
    is_mobile_browser = mobile_browser?
    redirect_to new_session_url if !is_mobile_browser && params[:mobile_app_login].present?
    return true if params[:mobile_app_login].present?
    is_mobile_browser
  end

  def handle_invalid_cases
    error_message, redirect_path =
      if @page.blank?
        ["flash_message.pages.pages_not_found".translate, about_path]
      elsif !@page.publicly_accessible? && !logged_in_organization?
        back_mark_pages(force_mark: request.get?)
        ["flash_message.pages.pages_login_required_to_view_page".translate, login_path]
      elsif !@pages.include?(@page)
        if program_view? && @page.program == @current_organization && !params[:redirected]
          [nil, page_url(params[:id], organization_level: true, redirected: true)]
        else
          ["flash_message.pages.pages_not_found".translate, root_path]
        end
      end
    flash[:error] = error_message.presence
    redirect_to redirect_path and return if redirect_path.present?
  end

  def check_program_listing_visibility
    unless can_view_programs_listing_page?
      flash[:error] = "flash_message.pages.pages_not_found".translate
      redirect_to about_path
    end
  end
end
