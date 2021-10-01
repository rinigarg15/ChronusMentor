class OrganizationLanguagesController < ApplicationController

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  before_action :fetch_organization_languages, only: [:index, :edit, :update_status]

  allow exec: :check_admin_access

  helper_method :can_show_enabled_programs_list?

  def index
    @languages = Language.ordered.enabled
  end

  def new
    @language = Language.find(params[:language_id])
    @organization_language = @current_organization.organization_languages.new(language_id: @language.id)
    render partial: "organization_languages/form_popup"
  end

  def edit
    @organization_language = @organization_languages.find(params[:id])
    @language = @organization_language.language
    render partial: "organization_languages/form_popup"
  end

  def update_status
    organization_language_params = organization_language_params(:update_status)
    organization_language = @organization_languages.find_or_initialize_by(language_id: organization_language_params[:language_id])
    organization_language.program_ids_to_enable = get_program_ids_to_enable
    organization_language.update_attributes!(organization_language_params)

    redirect_to organization_languages_path, notice: "flash_message.organization_languages.updated".translate
  end

  private

  def fetch_organization_languages
    @organization_languages = OrganizationLanguage.unscoped.where(organization_id: @current_organization.id)
  end

  def organization_language_params(action)
    params[:organization_language].permit(OrganizationLanguage::MASS_UPDATE_ATTRIBUTES[action])
  end

  def check_admin_access
    wob_member.admin?
  end

  def can_show_enabled_programs_list?
    super_console? && !@current_organization.standalone?
  end

  def get_program_ids_to_enable
    if can_show_enabled_programs_list?
      (params[:organization_language][:enabled_program_ids] || []).map(&:to_i)
    else
      @current_organization.program_ids
    end
  end
end