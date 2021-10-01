require_relative './../../test_helper.rb'

class GlobalReportsControllerCommonTest < ActiveSupport::TestCase
  include GlobalReportsControllerCommon

  def test_can_access_global_reports
    assert_false can_access_global_reports?

    organization = programs(:org_primary)
    @current_organization = organization
    self.stubs(:super_console?)
    self.stubs(:wob_member)

    organization.stubs(:global_reports_v3_applicable?).returns(false)
    assert_false can_access_global_reports?

    organization.stubs(:global_reports_v3_applicable?).returns(true)
    assert can_access_global_reports?
  end
end