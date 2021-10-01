require_relative './../../test_helper.rb'

class GlobalMemberSearchTest < ActiveSupport::TestCase

  def test_send_request
    APP_CONFIG[:global_member_search_api_key] = "some_key"
    request = Net::HTTP::Post.new(URI("http://primary.test.host"), 'Content-Type' => 'application/json')
    Net::HTTP::Post.expects(:new).with(URI("http://primary.test.host"), 'Content-Type' => 'application/json').returns(request)
    Net::HTTP.any_instance.expects(:request).with(request).returns("response")
    assert_equal "response", GlobalMemberSearch.send_request("http://primary.test.host", "iitm@chronus.com", "uniq_token")
  end

  def test_search
    success_response = Net::HTTPResponse.new("V1", "200", "message")
    failure_response = Net::HTTPResponse.new("V1", "404", "message")
    success_response_with_no_content = Net::HTTPResponse.new("V1", "204", "message")

    members(:f_student).update_attributes!(email: "some_email@example.com")
    GlobalMemberSearch.expects(:send_request).with("http://mentor.test.host/mobile_v2/home/validate_member", "some_email@example.com", "uniq_token").returns(success_response)
    GlobalMemberSearch.expects(:configure_login_token_and_email).with(Member.where(email: "some_email@example.com"), "uniq_token").once
    Airbrake.expects(:notify).never
    GlobalMemberSearch.search("some_email@example.com", "uniq_token")

    GlobalMemberSearch.expects(:send_request).with("http://mentor.test.host/mobile_v2/home/validate_member", "some_email@example.com", "uniq_token").returns("")
    GlobalMemberSearch.expects(:configure_login_token_and_email).with(Member.where(email: "some_email@example.com"), "uniq_token").once
    Airbrake.expects(:notify)
    GlobalMemberSearch.search("some_email@example.com", "uniq_token")

    members(:f_student).update_attributes!(email: "some_email2@example.com")
    members(:f_student).reload
    GlobalMemberSearch.expects(:send_request).with("http://mentor.test.host/mobile_v2/home/validate_member", "some_email@example.com", "uniq_token").returns(failure_response)
    Airbrake.expects(:notify)
    member = Member.where(email: "some_email@example.com")
    GlobalMemberSearch.expects(:configure_login_token_and_email).with(member, "uniq_token").once
    Member.any_instance.expects(:create_login_token_and_send_email).with("uniq_token").never
    GlobalMemberSearch.search("some_email@example.com", "uniq_token")

    GlobalMemberSearch.expects(:send_request).with("http://mentor.test.host/mobile_v2/home/validate_member", "some_email@example.com", "uniq_token").returns(success_response_with_no_content)
    Airbrake.expects(:notify).never
    member = Member.where(email: "some_email@example.com")
    GlobalMemberSearch.expects(:configure_login_token_and_email).with(member, "uniq_token").once
    Member.any_instance.expects(:create_login_token_and_send_email).with("uniq_token").never
    GlobalMemberSearch.search("some_email@example.com", "uniq_token")
  end

  def test_configure_login_token_and_email
    members(:f_student).expects(:create_login_token_and_send_email).with("uniq_token").once
    members(:f_mentor).expects(:create_login_token_and_send_email).once
    GlobalMemberSearch.configure_login_token_and_email([members(:f_student), members(:f_mentor)], "uniq_token")

    Member.any_instance.expects(:create_login_token_and_send_email).with("uniq_token").never
    GlobalMemberSearch.configure_login_token_and_email([], "uniq_token")
  end

end