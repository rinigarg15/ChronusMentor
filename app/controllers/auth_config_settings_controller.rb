class AuthConfigSettingsController < ApplicationController
  include AuthConfigSettingsHelper

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  before_action :fetch_auth_config_setting

  allow exec: :authorize_member

  def index
    @section = params[:section].to_i
    @is_position_configurable = is_position_configurable
  end

  def update
    @auth_config_setting.update_attributes!(permitted_params(:update))

    title = get_auth_config_section_title(params[:section].to_i)
    flash[:notice] = "flash_message.auth_config_setting.update_success".translate(title: title)
    redirect_to auth_configs_path
  end

  private

  def fetch_auth_config_setting
    @auth_config_setting = @current_organization.auth_config_setting
  end

  def authorize_member
    wob_member.admin?
  end

  def permitted_params(action)
    params[:auth_config_setting].permit(AuthConfigSetting::MASS_UPDATE_ATTRIBUTES[action])
  end

  def is_position_configurable
    auth_configs = AuthConfig.classify(@current_organization.auth_configs)
    auth_configs[:default].present? && auth_configs[:custom].present?
  end
end