require_relative './../../test_helper.rb'

class PendoTest < ActiveSupport::TestCase
  def test_reset_pendo_data_url
    assert_equal "https://app.pendo.io/api/v1/guide/all/visitor/random_string/reset", Pendo::RESET_PENDO_DATA_URL.call("random_string")
  end

  def test_can_reset_pendo_guide_seen_data
    global_admin = members(:f_admin)
    mentor_user = users(:f_mentor)

    Pendo.stubs(:pendo_integration_enabled?).returns(false)
    assert_false Pendo.can_reset_pendo_guide_seen_data?(global_admin, mentor_user)

    Pendo.stubs(:pendo_integration_enabled?).returns(true)
    assert_false Pendo.can_reset_pendo_guide_seen_data?(nil, mentor_user)

    assert Pendo.can_reset_pendo_guide_seen_data?(global_admin, mentor_user)

    assert_false Pendo.can_reset_pendo_guide_seen_data?(mentor_user.member, mentor_user)
    mentor_user.roles << programs(:albers).roles.with_name(RoleConstants::ADMIN_NAME)

    assert Pendo.can_reset_pendo_guide_seen_data?(mentor_user.member, mentor_user)

    assert_false Pendo.can_reset_pendo_guide_seen_data?(mentor_user.member, nil)
  end

  def test_send_request
    APP_CONFIG[:pendo_integration_key] = "some_key"
    Net::HTTP::Post.expects(:new).with(URI("some_url"), 'Content-Type' => 'application/json', 'x-pendo-integration-key' => "some_key").returns("request")
    Net::HTTP.any_instance.expects(:request).with("request").returns("response")
    assert_equal "response", Pendo.send_request("some_url")
  end

  def test_reset_pendo_guide_seen_data
    member = members(:f_admin)
    success_response = Net::HTTPResponse.new("V1", "200", "message")
    failure_response = Net::HTTPResponse.new("V1", "404", "message")

    Pendo.expects(:can_reset_pendo_guide_seen_data?).returns(false)
    Pendo.expects(:send_request).never
    Pendo.reset_pendo_guide_seen_data(member, nil)

    Pendo.expects(:can_reset_pendo_guide_seen_data?).at_least(1).returns(true)
    Pendo::RESET_PENDO_DATA_URL.expects(:call).with("ram@example.com").at_least(1).returns("some_url")

    Pendo.expects(:send_request).with("some_url").returns(success_response)
    Airbrake.expects(:notify).never
    Pendo.reset_pendo_guide_seen_data(member, nil)

    Pendo.expects(:send_request).with("some_url").returns("")
    Airbrake.expects(:notify)
    Pendo.reset_pendo_guide_seen_data(member, nil)

    Pendo.expects(:send_request).with("some_url").returns(failure_response)
    Airbrake.expects(:notify)
    Pendo.reset_pendo_guide_seen_data(member, nil)
  end
end