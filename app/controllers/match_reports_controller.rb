class MatchReportsController < ApplicationController
  include MatchAdminViewUtils
  include AdminViewsPreviewUtils
  TOP_DISCREPANCY = 3
  before_action :set_section, only: [:match_report_async_loading, :edit_section_settings, :update_section_settings, :index]
  before_action :set_edit_section_and_admin_view, only: [:index]
  allow user: :can_view_match_report?

  def index
    @match_report = MatchReport.new(@current_program)
  end

  def match_report_async_loading
    @update_settings = params[:update_settings].to_s.to_boolean
    @partial = MatchReport::Sections::Partials[@section][:partial]
    @element_id = MatchReport::Sections::Partials[@section][:element_id]
    get_mentor_and_mentee_views
    set_admin_view_users
    set_section_data
    @skip_hiding_loader = true
    set_match_config_question_texts_hash if mentor_distribution_section?
  end

  def edit_section_settings
    redirect_to match_reports_path(edit_section: true, section: @section, admin_view_id: params[:admin_view_id]) and return unless request.xhr?
    fetch_admin_views_for_matching
    get_mentor_and_mentee_views
    fetch_mentee_and_mentor_views(@mentee_view, @mentor_view, params[:admin_view_id], {src: MatchReport::SettingsSrc::MATCH_REPORT})
  end

  def update_section_settings
    if mentor_distribution_section?
      set_match_report_view(RoleConstants::MENTOR_NAME, params[:mentor_view_id])
      @current_program.create_default_match_config_discrepancy_cache
    end
    set_match_report_view(RoleConstants::STUDENT_NAME, params[:mentee_view_id])
    redirect_to match_report_async_loading_path(remote: true, section: @section, update_settings: true)
  end

  def preview_view_details
    set_preview_view_details({src: MatchReport::SettingsSrc::MATCH_REPORT})
  end

  def show_discrepancy_graph_or_table
    match_config, mentor_distribution = set_match_config_and_mentor_distribution
    show_graph = params[:show_graph].to_s.to_boolean

    if show_graph
      render_discrepancy_graph(match_config, mentor_distribution)
    else
      render partial: "match_reports/mentor_distribution/show_discrepancy_table", locals: {match_config: match_config}
    end
  end

  def get_discrepancy_table_data
    _match_config, mentor_distribution = set_match_config_and_mentor_distribution
    discrepancy_data = mentor_distribution.calculate_data_discrepancy
    page = params[:page] || 1
    per_page = (params["pageSize"] || MatchReport::MenteeActions::FILTERS_POPUP_LISTING_LIMIT).to_i
    @discrepancy_data = discrepancy_data.paginate(page: page, per_page: per_page)
    @total_count = discrepancy_data.count
    render "match_reports/mentor_distribution/get_discrepancy_table_data"
  end

  def refresh_top_mentor_recommendations
    match_config = @current_program.match_configs.find(params[:match_config_id])
    match_config.refresh_match_config_discrepancy_cache
    set_match_config_question_texts_hash
  end

  private

  def set_match_config_and_mentor_distribution
    match_config = @current_program.match_configs.find(params[:match_config_id])
    mentor_distribution = MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.new(@current_program, {match_config: match_config})
    [match_config, mentor_distribution]
  end

  def render_discrepancy_graph(match_config, mentor_distribution)
    categories, series_data, remaining_categories_size, maximum_discrepancy = mentor_distribution.get_discrepancy_graph_series_data
    json_objects = { categories: categories, series_data: series_data, remaining_categories_size: remaining_categories_size, match_config_id: match_config.id, maximum_discrepancy: maximum_discrepancy}
    render :json => json_objects.to_json.html_safe
  end

  def set_section
    @section = params[:section].to_s.html_safe
  end

  def set_edit_section_and_admin_view
    @edit_section = params[:edit_section].to_s.to_boolean
    @admin_view_id = params[:admin_view_id]
  end

  def get_mentor_and_mentee_views
    @mentor_view = @current_program.get_match_report_admin_view(@section, RoleConstants::MENTOR_NAME).admin_view if mentor_distribution_section?
    @mentee_view = @current_program.get_match_report_admin_view(@section, RoleConstants::STUDENT_NAME).admin_view
    set_match_report_admin_views if @mentor_view.blank? && @mentee_view.blank?
  end

  def set_section_data
    @section_data = MatchReport::Sections::SectionClasses[@section].constantize.new(program, {mentee_view_user_ids: @mentee_view_users}).get_section_data
  end

  def set_match_report_admin_views
    @mentor_view = set_match_report_view(RoleConstants::MENTOR_NAME) if mentor_distribution_section?
    @mentee_view = set_match_report_view(RoleConstants::STUDENT_NAME)
  end

  def set_match_report_view(role_type, admin_view_id=nil)
    default_admin_view = MatchReport::Sections::SectionClasses[@section].constantize.fetch_default_admin_view(@current_program, role_type) if admin_view_id.blank?
    admin_view_id = admin_view_id || default_admin_view.id
    match_report_admin_view = @current_program.match_report_admin_views.find_or_initialize_by({section_type: @section, role_type: role_type}) 
    match_report_admin_view.update_attributes!(admin_view_id: admin_view_id)
    match_report_admin_view.admin_view
  end

  def set_admin_view_users
    @mentee_view_users = @mentee_view.get_user_ids_for_match_report
    @mentor_view_users = @mentor_view.get_user_ids_for_match_report if mentor_distribution_section?
  end

  def mentor_distribution_section?
    @section == MatchReport::Sections::MentorDistribution
  end

  def set_match_config_question_texts_hash
    match_configs = @current_program.match_configs.order("weight DESC").includes(mentor_question: [:profile_question], student_question: [:profile_question]).select(&:questions_choice_based?)
    @match_config_question_texts_hash = Hash[match_configs.map{|config| [config.id, config.mentor_question.profile_question.question_text]}]
    get_top_discrepancies(match_configs)
  end

  def get_top_discrepancies(match_configs)
    @top_match_configs = []
    match_configs.each do |config|
      @top_match_configs << config.match_config_discrepancy_cache.top_discrepancy
    end
    @top_match_configs = @top_match_configs.flatten.sort_by{|d| d[:discrepancy]}.reverse.first(TOP_DISCREPANCY)
  end
end