require_relative './../../../../test_helper'
require Rails.root.to_s + "/script/lib/single_touch_deployment/deployment_helper"

class DeploymentHelperTest < ActionController::TestCase
  def test_my_system_cmd
    DeploymentHelper.stubs(:send_developer_email).returns(true)
    DeploymentHelper.expects(:popen3_cmd).with("ls /tmp/", "default").returns([1, "testing"])
    assert_equal 1, DeploymentHelper.my_system_cmd("ls /tmp/", "default", false)
  end

  def test_my_system_cmd_with_failure
    DeploymentHelper.stubs(:send_developer_email).returns(true)
    DeploymentHelper.expects(:popen3_cmd).with("ls /tmp/", "default").returns([0, "testing"])
    DeploymentHelper.stubs(:abort).returns(true)
    assert_equal 0, DeploymentHelper.my_system_cmd("ls /tmp/", "default", true)
  end

  def test_popen3_cmd
    assert_equal [1, "Finished: echo 'hello'"], DeploymentHelper.popen3_cmd("echo 'hello'")
    status, failure_backtrace_log = DeploymentHelper.popen3_cmd("raise 'exception testing'")
    assert_equal 0, status
    assert_equal true, failure_backtrace_log.start_with?('Error: FAILED !!!')
  end

  def test_run_cap_deploy
    DeploymentHelper.expects(:my_system_cmd).with("cap default deploy:migrations ABC=true", "default", true, "deployment-default-5.log")
    DeploymentHelper.run_cap_deploy("default", "ABC=true", 5, true)
  end

  def test_run_cap_deploy
    DeploymentHelper.expects(:my_system_cmd).with("cap default deploy:migrations ABC=true", "default", false, "deployment-default-5.log").returns(1)
    StepChecker.expects(:update_file).with(:completed_deployment, "default")
    assert_equal 1, DeploymentHelper.run_cap_deploy("default", "ABC=true", "5", false)
  end

  def test_run_deployment_rake
    DeploymentHelper.expects(:my_system_cmd).with("cap default deploy:run_rake_tasks_from_db", "default", false, "rake-default-1.log").returns(1)
    StepChecker.expects(:update_file).with(:completed_rake_tasks, "default")
    assert_equal 1, DeploymentHelper.run_deployment_rake("default", "1", false)
  end

  def test_run_recovery_setup
    DeploymentHelper.expects(:my_system_cmd).with("cap default deploy:perform_recovery_setup", "default", false).returns(1)
    StepChecker.expects(:update_file).with(:perform_recovery_setup, "default")
    assert_equal 1, DeploymentHelper.run_recovery_setup("default", false)
  end

  def test_check_web_status
    DeploymentHelper.stubs(:website_status).returns(false)
    DeploymentHelper.stubs(:stop_service_maintenance).returns(true)
    DeploymentHelper.expects(:send_developer_email).with("Deployment Error: default is down", "Check website manually")
    DeploymentHelper.check_web_status(["default"])
  end

  def test_diff_present_check
    DeploymentHelper.stubs(:git_diff_present).returns(false)
    DeploymentHelper.expects(:send_developer_email).once
    DeploymentHelper.stubs(:abort).returns(true)
    assert_equal [], DeploymentHelper.diff_present_check(["nch_develop"])
  end

  def test_get_log_path
    assert_equal "/tmp/deployment-default-timestamp.log", DeploymentHelper.get_log_path("default", "timestamp", "deployment")
  end
end