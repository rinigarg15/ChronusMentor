require_relative './../../test_helper'

class DeploymentRakeRunnerTest < ActionController::TestCase
  def test_strip_inverted_commas
    assert_equal "hello world", DeploymentRakeRunner.strip_inverted_commas("'hello world'")
    assert_equal "hello world", DeploymentRakeRunner.strip_inverted_commas("\"hello world\"")
  end

  def test_get_env_variables
    assert_equal "hello testing", DeploymentRakeRunner.get_env_variables("DOMAIN_TEST='hello testing' DOMAIN='test2'")["DOMAIN_TEST"]
  end
end