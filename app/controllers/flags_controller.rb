class FlagsController < ApplicationController
  include Report::MetricsUtils

  allow user: :is_admin?, :except => [:new, :create]
  helper_method :unresolved_tab?, :resolved_tab?

  def new
    @content_type = params[:content_type]
    @content_id = params[:content_id]
    @content = params[:content_type].constantize_only(Flag.flaggable_content_types).find_by(id: params[:content_id]) if params[:content_id] && params[:content_type]
    @flag = @current_program.flags.new(user: current_user, content_type: @content_type, content_id: @content_id)
    render partial: "flags/new_flag_popup.html"
  end

  def create
    user = current_user
    program = current_program
    @content = params[:flag][:content_type].constantize_only(Flag.flaggable_content_types).find_by(id: params[:flag][:content_id]) if params[:flag][:content_id] && params[:flag][:content_type]
    allow! exec: Proc.new{ !Flag.content_owner_is_user?(@content, user) }
    @flag = current_program.flags.create!(flag_params(:create).merge(status: Flag::Status::UNRESOLVED, user_id: user.id, program_id: program.id))
    flash[:notice] = !@flag.id.nil? ? "flash_message.flag.created_successfully".translate : "flash_message.flag.creation_failed".translate
    redirect_back(fallback_location: root_path)
  end

  def index
    @metric = get_source_metric(current_program, params[:metric_id])
    @src_path = params[:src]
    @params_with_filter = get_filter_params
    page = @params_with_filter[:page] || 1
    @scope = @current_program
    @unresolved_flags_count = @scope.unresolved_flagged_content_count
    update_tab_from_filter
    @tab = @params_with_filter[:tab] ? @params_with_filter[:tab].to_i : (@tab_from_filter || Flag::Tabs::UNRESOLVED)
    filter = case @tab
    when Flag::Tabs::RESOLVED
      {resolved: true}
    when Flag::Tabs::UNRESOLVED
      {unresolved: true}
    end
    @flags = Flag.get_flags(@scope, {filter: filter}).ordered.paginate(:page => page, :per_page => PER_PAGE)
    @pagination_required = (Flag.get_flags(@scope, {filter: filter}).count > @flags.size)
  end

  def update
    @flag = @current_program.flags.find(params[:id])
    if params[:allow] == true.to_s
      @flag.update_attributes({status: Flag::Status::ALLOWED, resolver_id: current_user.id, resolved_at: Time.now})
      flash[:notice] = "flash_message.flag.ignored".translate
    elsif params[:allow_all] == true.to_s
      Flag.ignore_all_flags(@flag.content, current_user, Time.now)
      flash[:notice] = "flash_message.flag.all_ignored".translate
    end
    redirect_back(fallback_location: root_path)
  end

  def content_related
    @content = ( (params[:content_type] && params[:content_id]) ? params[:content_type].constantize_only(Flag.flaggable_content_types).find_by(id: params[:content_id]) : nil )
    @flags = @content.flags.in_program(@current_program).unresolved
    render partial: "flags/content_related.html"
  end

  def resolved_tab?
    @tab == Flag::Tabs::RESOLVED
  end

  def unresolved_tab?
    @tab == Flag::Tabs::UNRESOLVED
  end

  private

  def flag_params(action)
    params[:flag].present? ? params[:flag].permit(Flag::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def get_filter_params
    if params[:abstract_view_id] && (@flag_view = @current_program.abstract_views.find_by(id: params[:abstract_view_id]))
      @flag_view.filter_params_hash.reverse_merge(params)
    else
      params
    end
  end

  def update_tab_from_filter
    @tab_from_filter = Flag::Tabs::UNRESOLVED if @params_with_filter[:unresolved]
    @tab_from_filter = Flag::Tabs::RESOLVED if @params_with_filter[:resolved]
  end
end