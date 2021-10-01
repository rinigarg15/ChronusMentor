require_relative "./../../test_helper.rb"

class SamlAuthConfigHelperTest < ActionView::TestCase

  def test_saml_sso_wizard_view
    content = saml_sso_wizard_view
    assert_equal 3, content.size
    assert_equal "Upload IDP Metadata", content[SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA][:label]
    assert_equal "Generate SP Metadata", content[SamlAuthConfigController::SamlHeaders::GENERATE_SP_METADATA][:label]
    assert_equal "Setup Auth Config", content[SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG][:label]
    assert_match "tab=#{SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA}", content[SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA][:url]
    assert_match "tab=#{SamlAuthConfigController::SamlHeaders::GENERATE_SP_METADATA}", content[SamlAuthConfigController::SamlHeaders::GENERATE_SP_METADATA][:url]
    assert_match "tab=#{SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG}", content[SamlAuthConfigController::SamlHeaders::SETUP_AUTHCONFIG][:url]
  end
end