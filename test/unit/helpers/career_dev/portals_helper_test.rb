require_relative './../../../test_helper.rb'

class CareerDev::PortalsHelperTest < ActionView::TestCase
  include CareerDevTestHelper

  def test_get_new_portal_wizard_view_headers
    @current_organization = mock
    @current_organization.stubs(:standalone?).returns(true)
    assert_equal_hash( {
      CareerDev::PortalsHelper::Headers::PORTAL_DETAILS => { label: "Track Details" },
      CareerDev::PortalsHelper::Headers::ORG_PORTAL_DETAILS => { label: "Portal Details" }
    }, get_new_portal_wizard_view_headers)

    @current_organization.stubs(:standalone?).returns(false)
    assert_equal_hash( {
      CareerDev::PortalsHelper::Headers::PORTAL_DETAILS => { label: "Track Details" }
    }, get_new_portal_wizard_view_headers)
  end

  private

  def _Program
    "Track"
  end
end