class ThemesController < ApplicationController
  include ChronusS3Utils
  # Only super user can add or edit themes.
  skip_before_action :login_required_in_program, :require_program
  skip_before_action :load_current_organization, :load_current_root, :require_organization, :load_current_program, :configure_program_tabs, :configure_mobile_tabs, only: [:new_theme, :build_new]
  before_action :require_super_user, except: [:index, :update, :global_confirm_popup]
  before_action :login_required_in_organization, :get_program_in_subprograms_context, except: [:build_new, :upload_gradients_to_s3, :new_theme]

  # Check permission for all actions.
  allow exec: :check_access, except: [:build_new, :new_theme]

  def index
    @themes = @current_program_or_organization.private_themes
    @current_theme = (@current_program && @current_program.active_theme) || @current_organization.active_theme
  end

  def new
    @theme = Theme.new(program_id: @current_program_or_organization.id)
  end

  def create
    @theme = Theme.new(theme_params(:create))
    @theme.program_id = @current_program_or_organization.id if params[:scope] == "private"

    unless params[:theme]["css"]
      flash.now[:error] = 'flash_message.themes_flash.css_file_blank'.translate
      render action: :new and return
    end

    @theme.temp_path = params[:theme]["css"].path
    if @theme.save
      redirect_to themes_path
    else
      render action: :new
    end
  end

  def edit
    @theme = Theme.available_themes(@current_program_or_organization).find(params[:id])
  end

  def update
    @theme = Theme.available_themes(@current_program_or_organization).find_by(id: params[:id])
    if !params[:theme].blank? && super_console?
      # Theme update
      update_theme(params)
    elsif params[:deactivate] == "true" && @current_program_or_organization.is_a?(Program)
      @current_program_or_organization.activate_theme(nil)
      expire_theme_cache_fragements
      redirect_to themes_path
    elsif params[:activate] == "true"
      # Activation of theme
      activate_theme(params)
      expire_theme_cache_fragements
      redirect_to themes_path
    else
      redirect_to themes_path
    end
  end

  def destroy
    @theme = Theme.available_themes(@current_program_or_organization).find(params[:id])
    @theme.destroy
    redirect_to themes_path
  end

  def build_new
    theme_colors_map = params[:theme].slice(*ThemeBuilder::THEME_VARIABLES.keys)
    theme_file_path = ThemeUtils.generate_theme(theme_colors_map)
    begin
      File.open(theme_file_path, 'r') do |f|
        send_data f.read, type: "text/css", filename: "theme.css"
      end
    rescue => e
      raise e
    ensure
      File.delete(theme_file_path) if File.exist?(theme_file_path)
    end
  end

  def new_theme
    @theme = Theme.new
  end

  def global_confirm_popup
    @theme = Theme.available_themes(@current_program_or_organization).find(params[:id])
    render partial: "global_confirm_popup", layout: false
  end

private
  def activate_theme(theme_param)
    @current_program_or_organization.activate_theme(@theme)
    if (!program_view? && theme_param[:program].present?) || @current_organization.standalone?
      @current_program_or_organization.programs.each do |program|
        program.activate_theme(@theme)
      end
    end
  end

  def update_theme(params)
    unless params[:theme]["css"]
      flash.now[:error] = 'flash_message.themes_flash.css_file_blank'.translate
      render action: :edit and return
    end
    @theme.temp_path = params[:theme]["css"].path
    if @theme.update_attributes(theme_params(:update))
      expire_theme_cache_fragements if @current_program_or_organization.active_theme == @theme
      redirect_to themes_path
    else
      render action: :edit
    end
  end

  def theme_params(action)
    params.require(:theme).permit(Theme::MASS_UPDATE_ATTRIBUTES[action])
  end

  def check_access
    @is_themes_sub_program_view ? current_user.is_admin? : wob_member.admin?
  end

  def get_program_in_subprograms_context
    @is_themes_sub_program_view = program_view? && !@current_organization.standalone?
    @current_program_or_organization = @is_themes_sub_program_view ? @current_program : @current_organization
  end

  def expire_theme_cache_fragements
    if @current_program_or_organization.is_a?(Program)
      expire_fragment(CacheConstants::Programs::THEME_STYLESHEET.call(@current_program_or_organization.id))
    else
      expire_fragment(CacheConstants::Programs::THEME_STYLESHEET.call(@current_program_or_organization.id))
      @current_program_or_organization.programs.each do |prog|
        expire_fragment(CacheConstants::Programs::THEME_STYLESHEET.call(prog.id))
      end
    end
  end
end