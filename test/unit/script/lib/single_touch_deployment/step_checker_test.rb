require_relative './../../../../test_helper'
require Rails.root.to_s + "/script/lib/single_touch_deployment/step_checker"

class StepCheckerTest < ActionController::TestCase
  def test_new_dictionary_value
    assert_equal StepChecker.new_dictionary_value, {
      :timestamp => "",
      :send_mail => false,
      :verify_build_check => false,
      :diff_master_develop => false,
      :diff_present_checker => [],
      :create_review => false,
      :start_maintenance => [],
      :completed_deployment => [],
      :completed_rake_tasks => [],
      :store_logs => [],
      :perform_recovery_setup => []
    }
  end

  def test_get_value
    StepChecker.stubs(:get_hash_from_file).returns({:a => 1})
    assert_equal 1, StepChecker.get_value(:a)
  end

  def test_update_file_with_array1
    StepChecker.stubs(:get_hash_from_file).returns({:a => []})
    StepChecker.expects(:write_retry_file).with(:a => ["testing"])
    StepChecker.update_file(:a, ["testing"])
  end

  def test_update_file_with_array2
    StepChecker.stubs(:get_hash_from_file).returns({:a => []})
    StepChecker.expects(:write_retry_file).with(:a => ["testing"])
    StepChecker.update_file(:a, "testing")
  end

  def test_update_file_with_string
    StepChecker.stubs(:get_hash_from_file).returns({:a => ""})
    StepChecker.expects(:write_retry_file).with(:a => "testing")
    StepChecker.update_file(:a, "testing")
  end
end