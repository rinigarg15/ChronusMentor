require_relative './../../test_helper.rb'

class InternalMailerTest < ActionMailer::TestCase

  def setup
    super
    helper_setup
  end

  include Rails.application.routes.url_helpers

  def default_url_options
    ActionMailer::Base.default_url_options
  end

  def test_saml_sso_expire
    email = InternalMailer.saml_sso_expire("test organization", "September 30, 2013").deliver_now
    assert_equal ["no-reply@chronus.com"], email.from
    assert_equal "no-reply@chronus.com", email.sender
    assert_match("SAML SSO certificate for 'test organization' is about to expire on September 30, 2013 EOM", email.subject)
    assert email.body.empty?
  end

  def test_notify_account_monitoring_status_if_violated
    email = InternalMailer.notify_account_monitoring_status_if_violated(["monitor@chronus.com"], "subject").deliver_now
    assert_equal ["monitor@chronus.com"], email.from
    assert_equal "monitor@chronus.com", email.sender
    assert_match("#{Rails.env}: subject", email.subject)
    assert email.body.empty?
  end

  def test_notify_untranslated_strings
    email = InternalMailer.notify_untranslated_strings({"fr-CA" => ["fr-CA.key_1", "fr-CA.key_2"], "de" => ["de.key_1"]}).deliver_now

    assert_equal ["no-reply@chronus.com"], email.from
    assert_match("#{Rails.env} - Untranslated String in some locales", email.subject)
    assert_match "fr-CA - 2", email.body.to_s
    assert_match "de - 1", email.body.to_s
    assert_match "fr-CA - fr-CA.key_1, fr-CA.key_2", email.body.to_s
    assert_match "de - de.key_1", email.body.to_s
  end

  def test_notify_unused_keys
    email = InternalMailer.notify_unused_keys(["feature.test.key"]).deliver_now
    assert_equal ["no-reply@chronus.com"], email.from
    assert_match "Unused keys present in codebase", email.subject
    assert_select_helper_function "li", email.body.to_s, text: "feature.test.key"
  end

  def test_notify_corrupted_translations
    email = InternalMailer.notify_corrupted_translations({
      problematic_interpolation_keys: [
        {key: "key.one", en: "one en version", other: "one fr-CA version", locale: "fr-CA"},
        {key: "key.two", en: "two en version", other: "two fr-CA version", locale: "fr-CA"},
      ],
      problematic_html_keys: [ {key: "key.three", en: "three en version", other: "three fr-CA version", locale: "fr-CA"} ],
      warning_html_keys: [ {key: "key.four", en: "four en version", other: "four fr-CA version", locale: "fr-CA"} ]
    }).deliver_now

    assert_equal ["no-reply@chronus.com"], email.from
    assert_match("#{Rails.env} - 4 incorrect translated strings", email.subject)
    assert_match "en_version: two en version", email.body.to_s
    assert_match "fr-CA_version: two fr-CA version", email.body.to_s
    assert_match "en_version: three en version", email.body.to_s
    assert_match "fr-CA_version: three fr-CA version", email.body.to_s
    assert_match "en_version: four en version", email.body.to_s
    assert_match "fr-CA_version: four fr-CA version", email.body.to_s
    assert_match "The following translations from phraseapp have interpolation errors", email.body.to_s
    assert_match "phraseapp have <b>HTML</b> errors", email.body.to_s
    assert_match "phraseapp <b>may</b> have <b>HTML</b> errors", email.body.to_s

    email = InternalMailer.notify_corrupted_translations({
      problematic_interpolation_keys: [],
      problematic_html_keys: [ {key: "key.two", en: "two en version", other: "two fr-CA version", locale: "fr-CA"} ],
      warning_html_keys: []
    }).deliver_now

    assert_equal ["no-reply@chronus.com"], email.from
    assert_equal "no-reply@chronus.com", email.sender
    assert_match("#{Rails.env} - 1 incorrect translated strings", email.subject)
    assert_match "en_version: two en version", email.body.to_s
    assert_match "fr-CA_version: two fr-CA version", email.body.to_s
    assert_not_match "The following translations from phraseapp have interpolation errors", email.body.to_s, true
    assert_match "phraseapp have <b>HTML</b> errors", email.body.to_s
    assert_not_match "phraseapp <b>may</b> have <b>HTML</b> errors", email.body.to_s, true
  end

  def test_deactivate_organization_notification
    email = InternalMailer.deactivate_organization_notification("test organization", "Test Account Name", "test.chronus.com").deliver_now
    assert_equal ["no-reply@chronus.com"], email.from
    assert_equal "no-reply@chronus.com", email.sender
    assert_equal_unordered ["cs@chronus.com", "cseng@chronus.com"], email.to
    assert_equal "Test Account Name has been deactivated", email.subject
    assert_match("test organization", email.body.to_s)
    assert_match("Test Account Name", email.body.to_s)
    assert_match("test.chronus.com", email.body.to_s)
  end

  def test_data_feed_migration_status_notification_to_chronus
    # Refer feed_miragtor_test.rb for test involving params and mail content
    Timecop.freeze(Time.now) do
      migration_status = {}
      email = InternalMailer.data_feed_migration_status_notification_to_chronus(migration_status).deliver_now
      assert_equal "Customer Feed Migration Status Report", email.subject
      assert_equal ["tester@chronus.com"], FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS
      assert_equal ["no-reply@chronus.com"], email.from
      assert_equal "no-reply@chronus.com", email.sender
      assert_equal FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS, email.to
      assert_equal DateTime.now.to_s, email.date.to_s
    end
  end

  def test_sales_demo_organization_creation_status_notification_to_chronus
    Timecop.freeze(Time.now) do
      email = InternalMailer.sales_demo_organization_creation_status_notification_to_chronus(true, organization_name: "Test Organization", organization_subdomain: "subdomain.demo").deliver_now
      assert_equal "Sales Demo Organization Creation Status", email.subject
      assert_equal ["tester@chronus.com"], SALES_DEMO_ORGANIZATION_CREATION_STATUS_NOTIFICATION_RECIPIENTS
      assert_equal ["no-reply@chronus.com"], email.from
      assert_equal "no-reply@chronus.com", email.sender
      assert_equal SALES_DEMO_ORGANIZATION_CREATION_STATUS_NOTIFICATION_RECIPIENTS, email.to
      assert_match "Test Organization", email.body.to_s
      assert_match "Success", email.body.to_s

      email = InternalMailer.sales_demo_organization_creation_status_notification_to_chronus(false, organization_name: "Test Organization", organization_subdomain: "subdomain.demo").deliver_now
      assert_equal ["no-reply@chronus.com"], email.from
      assert_equal "no-reply@chronus.com", email.sender
      assert_equal SALES_DEMO_ORGANIZATION_CREATION_STATUS_NOTIFICATION_RECIPIENTS, email.to
      assert_match "Test Organization (subdomain: subdomain.demo) Account", email.body.to_s
      assert_match "Failed", email.body.to_s
    end
  end

  def test_notify_dj_status
    email = InternalMailer.notify_dj_status(DjNotifier.new).deliver_now
    assert_equal "test - Delayed Job - Non Empty Queue", email.subject
    assert_equal ["no-reply@chronus.com"], email.from
    assert_equal "no-reply@chronus.com", email.sender
    assert_equal APP_CONFIG[:monit_mailing_list].split(COMMA_SEPARATOR), email.to
  end

  def test_mailgun_failed_summary
    failed_events = {
      "failed" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test1@example.com',
        :subject    => 'Test subject 1',
        :error_code => 550,
        :error_description  => "Delivery Status 1 Message",
        :message_id => "Message 1 message-id"
      }],
      "bounced" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test1@example.com',
        :subject    => 'Test subject 1',
        :error_code => 550,
        :error_description  => "Delivery Status 1 Message",
        :message_id => "Message 1 message-id"
      }],
      "complained" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test1@example.com',
        :subject    => 'Test subject 1',
        :error_code => 550,
        :error_description  => "Delivery Status 1 Message",
        :message_id => "Message 1 message-id"
      }]
      }
     all_events = {
      "550" => {
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :error_description  => "550 Blocked",
        :count => 125,
        :recipients=>["test1@example.com", "test2@example.com"]
      },
      "605" => {
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :error_description  => "Not delivering to previously bounced address",
        :count => 200,
        :recipients=>["test1@example.com", "test2@example.com"]
      },
      "607" => {
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :error_description  => "Not delivering to a user who marked your messages as spam",
        :count => 100,
        :recipients=>["test1@example.com", "test2@example.com"]
      }
    }

    email = InternalMailer.mailgun_failed_summary_notification(failed_events, all_events).deliver_now
    assert_equal "test - Mailgun Failed Events (3)", email.subject
    assert_equal ["no-reply@chronus.com"], email.from
    assert_equal "no-reply@chronus.com", email.sender
    assert_equal_unordered ["monitor@chronus.com"], email.to

    assert_match /Timestamp/, email.body.to_s
    assert_match /Recipient/, email.body.to_s
    assert_match /Subject/, email.body.to_s
    assert_match /Message-Id/, email.body.to_s

    assert_match /Delivery Status 1 Message/, email.body.to_s
    assert_match /Message 1 message-id/, email.body.to_s

    assert_match /Error Code/, email.body.to_s
    assert_match /Error Description/, email.body.to_s
    assert_match /Occurrence/, email.body.to_s
    assert_match /Recipients/, email.body.to_s

    assert_match /Aug 06 14:06/, email.body.to_s
    assert_match /Not delivering to a user who marked your messages as spam/, email.body.to_s
    assert_match /test1@example.com, test2@example.com/, email.body.to_s
    assert_match /Aug 06 14:06/, email.body.to_s
    assert_match /Aug 06 14:06/, email.body.to_s
  end

  def test_data_feed_failure_notification_to_mentor_support
    # Refer feed_miragtor_test.rb for test involving params and mail content
    Timecop.freeze(Time.now) do
      migration_status = {}
      email = InternalMailer.data_feed_migration_status_notification_to_chronus(migration_status, false).deliver_now
      assert_equal "Customer Feed Migration Status Report", email.subject
      assert_equal ["tester@chronus.com"], FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS
      assert_equal ["no-reply@chronus.com"], email.from
      assert_equal "no-reply@chronus.com", email.sender
      assert_equal FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS + FEED_MIGRATION_FAILURE_NOTIFICATION_CHRONUS_RECIPIENTS, email.to
      assert_equal DateTime.now.to_s, email.date.to_s
    end
  end

  def test_bounced_mail_notification
    email1 = InternalMailer.bounced_mail_notification('some_email@test.com', {:error_message => 'This is the error message'}, {:name => 'A Campaign Name'}, {:organization => "org", :state => "active"}).deliver_now
    assert_equal "The email address some_email@test.com has been added to the bounced list", email1.subject
    assert_equal ["no-reply@chronus.com"], email1.from
    assert_equal "no-reply@chronus.com", email1.sender
    assert_equal BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS, email1.to
    assert_match /Reason for bounce:/, email1.body.to_s
    assert_match /This is the error message/, email1.body.to_s
    assert_match /Campaign Information:/, email1.body.to_s
    assert_match /A Campaign Name/, email1.body.to_s
    assert_match /Organization Url :/, email1.body.to_s
    assert_match /Member state :/, email1.body.to_s

    email2 = InternalMailer.bounced_mail_notification('some_email@test.com', {}, {}, {}).deliver_now
    assert_no_match(/Reason for bounce:/, email2.body.to_s)
    assert_no_match(/Campaign Information/, email2.body.to_s)
    assert_no_match(/Member Information:/, email2.body.to_s)
  end

  def test_marked_as_spam_notification
    email1 = InternalMailer.marked_as_spam_notification('some_email@test.com', {:name => 'A Campaign Name'}, {:organization => "org", :state => "active"}).deliver_now
    assert_equal "User with email address some_email@test.com has marked our email as spam", email1.subject
    assert_equal ["no-reply@chronus.com"], email1.from
    assert_equal "no-reply@chronus.com", email1.sender
    assert_equal BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS, email1.to
    assert_match /Campaign Information:/, email1.body.to_s
    assert_match /A Campaign Name/, email1.body.to_s

    email2 = InternalMailer.marked_as_spam_notification('some_email@test.com', {}, {}).deliver_now
    assert_no_match(/Campaign Information/, email2.body.to_s)
  end

  def test_notify_active_admins
    email = InternalMailer.notify_active_admins("#{Rails.root}/test/fixtures/files/some_file.txt")
    assert_equal ["no-reply@chronus.com"], email.from
    assert_equal "no-reply@chronus.com", email.sender
    assert_equal "#{Rails.env} - Active Admins", email.subject
    assert_equal "some_file.txt", email.attachments.first.filename
  end
end
