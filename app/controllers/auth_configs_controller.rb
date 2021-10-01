class AuthConfigsController < ApplicationController
  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  before_action :fetch_auth_config, only: [:edit, :update, :destroy, :toggle, :edit_password_policy, :update_password_policy]

  allow exec: :authorize_member
  allow exec: :super_console?, only: [:new, :edit_password_policy, :update_password_policy]
  allow exec: :check_default_auth_config, only: [:toggle]
  allow exec: :check_custom_auth_config, only: [:edit, :update]
  allow exec: :check_indigenous_auth_config, only: [:edit_password_policy, :update_password_policy]
  allow exec: :check_deletion, only: [:destroy]

  def index
    @auth_configs = AuthConfig.classify(@current_organization.auth_configs(true))
  end

  def edit
  end

  def update
    @auth_config.update_attributes!(permitted_params(:update))
    if params[:persist_logo] == "false" && params[:auth_config][:logo].blank?
      @auth_config.remove_logo!
    end

    flash[:notice] = "flash_message.auth_config.update_success".translate(title: auth_config_title)
    redirect_to auth_configs_path
  rescue VirusError
    handle_virus_error
  end

  def destroy
    title = auth_config_title
    @auth_config.destroy

    flash[:notice] = "flash_message.auth_config.destroy_success".translate(title: title)
    redirect_to auth_configs_path
  end

  def toggle
    flash[:notice] =
      if params[:enable].present?
        @auth_config.enable!
         "flash_message.auth_config.enable_success".translate(title: auth_config_title)
      else
        allow! exec: Proc.new { @auth_config.can_be_disabled? }
        @auth_config.disable!
        "flash_message.auth_config.disable_success".translate(title: auth_config_title)
      end
    redirect_to auth_configs_path
  end

  def edit_password_policy
  end

  def update_password_policy
    @auth_config.update_attributes!(permitted_params(:update_password_policy))

    flash[:notice] = "flash_message.auth_config.update_password_policy_success".translate(title: auth_config_title)
    redirect_to auth_configs_path
  end

  private

  def permitted_params(action)
    params[:auth_config].permit(AuthConfig::MASS_UPDATE_ATTRIBUTES[action])
  end

  def authorize_member
    wob_member.admin?
  end

  def fetch_auth_config
    @auth_config = @current_organization.auth_configs(true).find_by(id: params[:id])
  end

  def check_default_auth_config
    @auth_config.default?
  end

  def check_custom_auth_config
    @auth_config.custom?
  end

  def check_indigenous_auth_config
    @auth_config.indigenous?
  end

  def check_deletion
    @auth_config.can_be_deleted?
  end

  def auth_config_title
    h(@auth_config.title)
  end

  def handle_virus_error
    flash[:error] = "flash_message.message_flash.virus_present".translate
    redirect_to auth_configs_path
  end
end