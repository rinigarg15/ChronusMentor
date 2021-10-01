require_relative './../test_helper.rb'

class MailgunWebhookHandlersControllerTest < ActionController::TestCase
  def setup
    super
    @token = '3ohe4aeu7q0n6zjm1b0lbmvhro1v-s0zr6t9oieqhqm0vmnfm2'
    @timestamp = '1351248513'
    @signature = '303611ee8b73ea66858ee6c248c7fbf40377e72c6702453e5486a03285e35fde'
    @credentials = {:token => @token,:timestamp => @timestamp,:signature => @signature}
  end

  def test_verrify_signature_failure_no_params
    https_post :handle_events
    assert_response HttpConstants::FORBIDDEN
  end

  def test_verrify_signature_failure_invalid_signature
    https_post :handle_events, params: { :token => @token, :timestamp => @timestamp, :signature => 'somejunk'}
    assert_response HttpConstants::FORBIDDEN
  end

  def test_verrify_signature_success
    https_post :handle_events, params: @credentials

    assert_no_emails do
      assert_response HttpConstants::SUCCESS
    end
  end

  def test_bounce_event_with_valid_email
    assert_emails 1 do
      https_post :handle_events, params: @credentials.merge(:event => ChronusMentorMailgun::Event::BOUNCED, :recipient => 'ram@example.com', :error => 'error message', "campaign-name" => 'Campaign Name')
      assert_response HttpConstants::SUCCESS
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "The email address ram@example.com has been added to the bounced list", email.subject
    email_body = email.body.to_s
    assert_match /error message/, email_body
    assert_match /Campaign Name/, email_body
    assert_match /Organization Url/, email_body
    assert_match /Member state : Active/, email_body
  end

  def test_bounce_event_with_invalid_email
    https_post :handle_events, params: @credentials.merge(:event => ChronusMentorMailgun::Event::BOUNCED, :recipient => 'invalid_email@example.com', :error => 'error message', "campaign-name" => 'Campaign Name')
    email = ActionMailer::Base.deliveries.last
    email_body = email.body.to_s
    assert_no_match(/Member Information/, email_body)
  end

  def test_spam_event
    assert_emails 1 do
      https_post :handle_events, params: @credentials.merge(:event => ChronusMentorMailgun::Event::SPAMMED, :recipient => 'dormant@example.com', :error => 'error message', "campaign-name" => 'Campaign Name')
      assert_response HttpConstants::SUCCESS
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal "User with email address dormant@example.com has marked our email as spam", email.subject
    email_body = email.body.to_s
    assert_no_match(/error message/, email_body)
    assert_match /Campaign Name/, email_body
    assert_match /Organization Url/, email_body
    assert_match /Member state : Dormant/, email_body
  end
end