require_relative './../../../../test_helper'
require Rails.root.to_s + "/script/lib/single_touch_deployment/build_status"

class BuildStatusTest < ActionController::TestCase
  def test_check_build_passed
    BuildStatus.any_instance.stubs(:current_build_status).returns(true)
    assert_equal [true], BuildStatus.new.check_build_passed(["develop"])
  end

  def test_current_build_status
    BuildStatus.any_instance.stubs(:retry_when_exception).returns({'lastBuildStatus' => "Success", 'activity' => "Sleeping"})
    assert_equal true, BuildStatus.new.current_build_status("develop")
  end

  def test_current_build_status_failed
    BuildStatus.any_instance.stubs(:retry_when_exception).returns(false)
    assert_equal false, BuildStatus.new.current_build_status("develop")
  end
end