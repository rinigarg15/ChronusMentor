require_relative './../../../test_helper.rb'

class DummyMailForTest < ActionMailer::Base
  def dummy_mail_for_test(options = {})
    mail(options)
  end
end

class SandboxEmailInterceptorTest < ActiveSupport::TestCase

  def test_mails_should_go_to_chronus_domain
    message = DummyMailForTest.dummy_mail_for_test(:to => ["abc@chronus.com", "def@chronus.com"], :subject => "Test subject", :from => "abc@example.com", :body => "")
    Interceptors::SandboxEmailInterceptor.delivering_email(message)
    assert message.perform_deliveries
  end

  def test_airbrake_should_be_raised_when_mail_is_being_sent_to_non_chronus_domain
    message = DummyMailForTest.dummy_mail_for_test(:to => ["abc@chronus.com", "def@example.com"], :subject => "Test subject", :from => "abc@example.com", :body => "")

    Interceptors::SandboxEmailInterceptor.delivering_email(message)
    assert_false message.perform_deliveries

    message = DummyMailForTest.dummy_mail_for_test(:to => ["gautam.chandra@chronus.com"], :cc => ["abc@chronus.com", "def@example.com"], :subject => "Test subject", :from => "abc@example.com", :body => "")

    Interceptors::SandboxEmailInterceptor.delivering_email(message)
    assert_false message.perform_deliveries

    message = DummyMailForTest.dummy_mail_for_test(:to => ["gautam.chandra@chronus.com"], :bcc => ["abc@chronus.com", "def@example.com"], :subject => "Test subject", :from => "abc@example.com", :body => "")

    Interceptors::SandboxEmailInterceptor.delivering_email(message)
    assert_false message.perform_deliveries

  end

end
