class ContactAdminSettingsController < ApplicationController

  before_action :require_super_user

  def index
    @contact_admin_setting = @current_program.contact_admin_setting || ContactAdminSetting.new
  end

  def create
    build_and_save_contact_admin_setting
    flash[:notice] = "flash_message.admin_message.setting_succeeded".translate
    redirect_to contact_admin_settings_path
  end

  def update
    build_and_save_contact_admin_setting
    flash[:notice] = "flash_message.admin_message.setting_succeeded".translate
    redirect_to contact_admin_settings_path
  end

  private

  def build_and_save_contact_admin_setting
    contact_admin_setting_params = contact_admin_setting_params(self.action_name.to_sym)
    params[:contact_link] == "0" ? contact_admin_setting_params.merge!(content: nil) : contact_admin_setting_params.merge!(contact_url: nil)
    contact_admin_setting = @current_program.contact_admin_setting || @current_program.build_contact_admin_setting
    contact_admin_setting.update_attributes!(contact_admin_setting_params)
    if params[:contact_link] == "0"
      contact_admin_setting.translations.each{|translation| translation.update_attribute(:content, nil)}
    end
  end

  def contact_admin_setting_params(action)
    params[:contact_admin_setting].present? ? params[:contact_admin_setting].permit(ContactAdminSetting::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end
end
