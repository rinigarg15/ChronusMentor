class SamlAuthConfigController < AuthConfigsController

  module SamlHeaders
    UPLOAD_IDP_METADATA = 1
    GENERATE_SP_METADATA = 2
    SETUP_AUTHCONFIG = 3
  end

  before_action :set_current_tab
  before_action :check_saml_auth_presence, only: [:download_idp_metadata, :update_certificate, :download_idp_certificate]

  allow exec: :super_console?

  def saml_sso
    file_regexes =
      if @saml_tab == SamlHeaders::SETUP_AUTHCONFIG
        [SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE]
      elsif @saml_tab == SamlHeaders::UPLOAD_IDP_METADATA
        [SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE]
      end
    @files_present = SamlAutomatorUtils::SamlFileUtils.check_if_files_present_in_s3(@current_organization.id, file_regexes) if file_regexes.present?
    @idp_certificate_present = SamlAutomatorUtils.get_saml_idp_certificate(@current_organization).present?
  end

  def generate_sp_metadata
    begin
      sp_metadata_file = SamlAutomatorUtils::SamlFileUtils.copy_file_from_s3(@current_organization.id, SamlAutomatorUtils::RegexPatterns::SP_METADATA_FILE)
      sp_metadata_file ||= SamlAutomatorUtils.generate_sp_metadata_file(@current_organization)
      File.open(sp_metadata_file, 'r') do |f|
        send_data f.read, type: "application/xml", filename: "chronus_sp_metadata.xml"
      end
    ensure
      FileUtils.rm_rf(File.dirname(sp_metadata_file)) if sp_metadata_file.present?
    end
  end

  def upload_idp_metadata
    saml_tab = SamlHeaders::UPLOAD_IDP_METADATA
    uploaded_file = params[:file]
    if uploaded_file.present?
      if AuthConfig::SAML_METADATA_FILE_FORMATS.include? uploaded_file.content_type
        local_file = SamlAutomatorUtils::SamlFileUtils.write_file_to_local(uploaded_file, s3_file: false, file_name_suffix: "IDP_Metadata.xml")
        SamlAutomatorUtils::SamlFileUtils.transfer_files_to_s3([local_file], @current_organization.id, file_name: File.basename(local_file))
        flash[:notice] = "flash_message.organization_flash.saml.upload_success".translate
        saml_tab = SamlHeaders::GENERATE_SP_METADATA
      else
        flash[:error] = "flash_message.organization_flash.saml.upload_wrong".translate
      end
    else
      flash[:error] = "flash_message.organization_flash.saml.upload_failed".translate
    end
    redirect_to saml_auth_config_saml_sso_path(tab: saml_tab)
  end

  def setup_authconfig
    saml_auth_success = SamlAutomatorUtils.setup_saml_auth_config(@current_organization)
    flash_options = {
      success_message: "flash_message.organization_flash.saml.auth_creation_success".translate,
      failure_message: "flash_message.organization_flash.saml.auth_creation_fail".translate
    }
    perform_redirection(saml_auth_success, flash_options)
  end

  def download_idp_metadata
    idp_metadata_file = SamlAutomatorUtils::SamlFileUtils.copy_file_from_s3(@current_organization.id, SamlAutomatorUtils::RegexPatterns::IDP_METADATA_FILE)
    content_type = MIME::Types.type_for(idp_metadata_file)[0].content_type
    File.open(idp_metadata_file, 'r') do |f|
      send_data f.read, type: content_type, filename: "backup-idp_metadata.xml"
    end
  end

  def update_certificate
    options = { update_certificate_only: true }
    options[:idp_certificate] = params[:idp_certificate].read if params[:idp_certificate].present?
    update_success = SamlAutomatorUtils.setup_saml_auth_config(@current_organization, options)
    flash_options = {
      success_message: "flash_message.organization_flash.saml.certificate_update_success".translate,
      failure_message: "flash_message.organization_flash.saml.certificate_update_fail".translate
    }
    perform_redirection(update_success, flash_options)
  end

  def download_idp_certificate
    idp_certificate = SamlAutomatorUtils.get_saml_idp_certificate(@current_organization)
    if idp_certificate.present?
      current_time = DateTime.localize(Time.current, format: :full_date_full_time).to_s.gsub(' ', '_')
      send_data idp_certificate, type: "text/plain", filename: "backup_idp_certificate_#{current_time}.pem"
    else
      flash_options = {
        failure_message: "flash_message.organization_flash.saml.certificate_download_fail".translate
      }
      perform_redirection(false, flash_options)
    end
  end

  private

  def perform_redirection(is_success, options)
    if is_success
      flash[:notice] = options[:success_message]
      redirect_to manage_organization_path
    else
      flash[:error] = options[:failure_message]
      redirect_to saml_auth_config_saml_sso_path(tab: SamlHeaders::SETUP_AUTHCONFIG)
    end
  end

  def check_saml_auth_presence
    saml_auth = @current_organization.saml_auth
    redirect_to manage_organization_path unless saml_auth.present?
  end

  def set_current_tab
    @saml_tab = (params[:tab] || SamlHeaders::UPLOAD_IDP_METADATA).to_i
  end
end