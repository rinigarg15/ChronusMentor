module SamlAuthConfigHelper

  def saml_sso_wizard_view
    saml_headers = ActiveSupport::OrderedHash.new
    saml_headers[SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA] = { label: "feature.program.label.upload_idp".translate, url: saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA) }
    saml_headers[SamlAuthConfigController::SamlHeaders::GENERATE_SP_METADATA] = { label: "feature.program.label.generate_sp".translate, url: saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::GENERATE_SP_METADATA) }
    saml_headers[SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG] = { label: "feature.program.label.setup_authconfig".translate, url: saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG) }
    saml_headers
  end
end