require_relative './../../../test_helper'

class CronTasks::SamlCertExpiryNotifierTest < ActiveSupport::TestCase

  def test_perform
    Notify.expects(:admin_weekly_saml_sso_check)
    CronTasks::SamlCertExpiryNotifier.new.perform
  end
end