require_relative './../../../test_helper.rb'
require 'mailgun'

class FailedEventSummarizer < ActiveSupport::TestCase
  def setup
    super
    @mg_client_mock = mock
    @mg_events_mock = mock
    @events_array_mock2 = mock
    @events_array_mock = mock
    Mailgun::Client.stubs(:new).returns(@mg_client_mock)
    Mailgun::Events.stubs(:new).returns(@mg_events_mock)
  end

  def test_populate_permanently_failed_and_bounced_events_should_ignore_605_failures
    events_array = get_two_permanent_failures_with_one_code_set_to_605

    @events_array_mock2.expects(:to_h).returns("items" => [])
    @events_array_mock.expects(:to_h).returns("items" => events_array)

    @mg_events_mock.expects(:get).returns(@events_array_mock)
    @mg_events_mock.expects(:next).returns(@events_array_mock2)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    summarizer.send(:populate_permanently_failed_and_bounced_events)
    expected_hash  = {
      "failed" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test1@example.com',
        :subject    => 'Test subject 1',
        :error_code => 550,
        :error_description  => "Delivery Status 1 Message",
        :message_id => "Message 1 message-id"
      }],
      "bounced" => [],
      "complained" => []
    }
    assert_equal expected_hash, summarizer.failed_events_hash
  end

  def test_populate_permanently_failed_and_bounced_events_without_message_parameter
    events_array = get_one_permanent_failure_with_no_message_parameter

    @events_array_mock2.expects(:to_h).returns("items" => [])
    @events_array_mock.expects(:to_h).returns("items" => events_array)

    @mg_events_mock.expects(:get).returns(@events_array_mock)
    @mg_events_mock.expects(:next).returns(@events_array_mock2)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    summarizer.send(:populate_permanently_failed_and_bounced_events)

    expected_hash  = {
      "failed" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test1@example.com',
        :subject    => 'No subject available',
        :error_code => "5.1.1",
        :error_description  => "Delivery Status 1 Message",
        :message_id => "No message_id available"
      }],
      "bounced" => [],
      "complained" => []
    }

    assert_equal expected_hash, summarizer.failed_events_hash
  end

  def test_populate_permanently_failed_and_bounced_events_should_pickup_description_when_message_is_not_available
    events_array = get_two_permanent_failures_one_with_message_and_other_with_description
    @events_array_mock2.expects(:to_h).returns("items" => [])
    @events_array_mock.expects(:to_h).returns("items" => events_array)

    @mg_events_mock.expects(:get).returns(@events_array_mock)
    @mg_events_mock.expects(:next).returns(@events_array_mock2)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    summarizer.send(:populate_permanently_failed_and_bounced_events)

    expected_hash = {
      "failed" => [{
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test1@example.com',
      :subject    => 'Test subject 1',
      :error_code => 550,
      :error_description  => "Delivery Status 1 Message",
      :message_id => "Message 1 message-id"
      },{
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test2@example.com',
      :subject    => 'Test subject 2',
      :error_code => 550,
      :error_description  => "Delivery Status 2 description",
      :message_id => "Message 2 message-id"
      }],
      "bounced" => [],
      "complained" => []
    }

    assert_equal expected_hash, summarizer.failed_events_hash
  end

  def test_populate_permanently_failed_and_bounced_events_should_pickup_bounced_events
    events_array = get_one_failed_one_bounced_event
    @events_array_mock2.expects(:to_h).returns("items" => [])
    @events_array_mock.expects(:to_h).returns("items" => events_array)

    @mg_events_mock.expects(:get).returns(@events_array_mock)
    @mg_events_mock.expects(:next).returns(@events_array_mock2)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    summarizer.send(:populate_permanently_failed_and_bounced_events)

    expected_hash = {
      "failed" => [{
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test1@example.com',
      :subject    => 'Test subject 1',
      :error_code => 666,
      :error_description  => "Delivery Status 1 Message",
      :message_id => "Message 1 message-id"
      }],
      "bounced" => [{
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test2@example.com',
      :subject    => 'Test subject 3',
      :error_code => 550,
      :error_description  => "Delivery Status 3 description",
      :message_id => "Message 3 message-id"
      }],
      "complained" => []
    }

    assert_equal expected_hash, summarizer.failed_events_hash
  end

  def test_populate_spammed_events_should_populate_spammed_events
    events_array = get_one_spammed_event
    @events_array_mock2.expects(:to_h).returns("items" => [])
    @events_array_mock.expects(:to_h).returns("items" => events_array)

    @mg_events_mock.expects(:get).returns(@events_array_mock)
    @mg_events_mock.expects(:next).returns(@events_array_mock2)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    summarizer.send(:populate_spammed_events)

    expected_hash = {
      "failed" => [],
      "bounced" => [],
      "complained" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test2@example.com',
        :subject    => 'Test subject 2',
        :error_code => 0,
        :error_description  => "No description available",
        :message_id => "Message 2 message-id"
      }]
    }

    assert_equal expected_hash, summarizer.failed_events_hash
  end

  def test_populate_all_failed_events_should_populate_all_events_as_expected
    events_array = get_two_permanent_failures_with_one_code_set_to_605
    @events_array_mock2.expects(:to_h).returns("items" => [])
    @events_array_mock.expects(:to_h).returns("items" => events_array)

    @mg_events_mock.expects(:get).returns(@events_array_mock)
    @mg_events_mock.expects(:next).returns(@events_array_mock2)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    summarizer.send(:populate_all_failed_events)

    expected_hash = {
      550 => {
        :count => 1,
        :timestamp => "2014-08-06 14:06:17 +0530",
        :error_description => "Delivery Status 1 Message",
        :recipients => ["test1@example.com"]
        },
      605 => {
        :count => 1,
        :timestamp => "2014-08-06 14:06:17 +0530",
        :error_description => "Delivery Status 2 Message",
        :recipients => ["test2@example.com"]
        }
    }

    assert_equal expected_hash, summarizer.all_failed_events
  end

  def test_summarize_should_collect_all_events_and_call_internal_mailer
    permanently_failed_events = get_one_failed_one_bounced_event
    spammed_events_array = get_one_spammed_event

    @events_array_mock2.expects(:to_h).times(3).returns("items" => [])
    # @events_array_mock.expects(:to_h).times(3).returns(
    #   ,
    #   "items" => spammed_events_array,
    #   "items" => permanently_failed_events + spammed_events_array
    # )

    mock1 = mock
    mock2 = mock
    mock3 = mock

    mock1.expects(:to_h).returns("items" => permanently_failed_events)
    mock2.expects(:to_h).returns("items" => spammed_events_array)
    mock3.expects(:to_h).returns("items" => permanently_failed_events + spammed_events_array)


    @mg_events_mock.expects(:get).times(3).returns(mock1, mock2, mock3)
    @mg_events_mock.expects(:next).returns(@events_array_mock2).times(3)

    summarizer = ChronusMentorMailgun::FailedEventSummarizer.new
    internal_mailer_mock = mock
    internal_mailer_mock.expects(:deliver_now).returns

    expected_failed_events_hash = {
      "failed" => [{
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test1@example.com',
      :subject    => 'Test subject 1',
      :error_code => 666,
      :error_description  => "Delivery Status 1 Message",
      :message_id => "Message 1 message-id"
      }],
      "bounced" => [{
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test2@example.com',
      :subject    => 'Test subject 3',
      :error_code => 550,
      :error_description  => "Delivery Status 3 description",
      :message_id => "Message 3 message-id"
      }],
      "complained" => [{
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :recipient  => 'test2@example.com',
        :subject    => 'Test subject 2',
        :error_code => 0,
        :error_description  => "No description available",
        :message_id => "Message 2 message-id"
      }]
    }

    expected_all_events_hash = {
      550 => {
        :count => 1,
        :timestamp => "2014-08-06 14:06:17 +0530",
        :error_description => "Delivery Status 3 description",
        :recipients => ["test2@example.com"]
        },
      666 => {
        :count => 1,
        :timestamp => "2014-08-06 14:06:17 +0530",
        :error_description => "Delivery Status 1 Message",
        :recipients => ["test1@example.com"]
        },
      0 => {
        :count => 1,
        :timestamp  => "2014-08-06 14:06:17 +0530",
        :error_description => "No description available",
        :recipients => ["test2@example.com"]
        },

      }


    InternalMailer.expects(:mailgun_failed_summary_notification).with(expected_failed_events_hash,expected_all_events_hash).returns(internal_mailer_mock)

    summarizer.summarize

    assert_equal expected_failed_events_hash, summarizer.failed_events_hash
    assert_equal expected_all_events_hash, summarizer.all_failed_events

  end




  def test_is_bounced_event_should_return_true_if_the_reason_is_bounce_and_error_code_is_550
    assert ChronusMentorMailgun::FailedEventSummarizer.send(:is_bounced_event?, 550, "bounce")
    assert_false ChronusMentorMailgun::FailedEventSummarizer.send(:is_bounced_event?, 550, "other reason")
    assert_false ChronusMentorMailgun::FailedEventSummarizer.send(:is_bounced_event?, 605, "bounce")
  end

  def test_get_error_code_and_description_should_return_error_code_and_description
    item = get_two_permanent_failures_with_one_code_set_to_605[0]
    assert_equal [550, "Delivery Status 1 Message"], ChronusMentorMailgun::FailedEventSummarizer.send(:get_error_code_and_description, item)
  end

  def test_get_error_code_and_description_should_return_empty_string_for_spammed_events
    item = get_one_spammed_event[0]
    assert_equal [0, "No description available"], ChronusMentorMailgun::FailedEventSummarizer.send(:get_error_code_and_description, item)
  end

  def test_make_hash_of_mailgun_item_should_make_hash_as_expected
    item = get_two_permanent_failures_with_one_code_set_to_605[0]
    expected_hash = {
      :timestamp  => "2014-08-06 14:06:17 +0530",
      :recipient  => 'test1@example.com',
      :subject    => 'Test subject 1',
      :error_code => 550,
      :error_description  => "Delivery Status 1 Message",
      :message_id => "Message 1 message-id"
    }
    assert_equal expected_hash, ChronusMentorMailgun::FailedEventSummarizer.send(:make_hash_of_mailgun_item, item)
  end


  private

  def get_two_permanent_failures_with_one_code_set_to_605
    return [
      {
        "event" => "failed",
        "severity" => "permanent",
        "timestamp" => "1407314177.8627763",
        "recipient" => 'test1@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 1",
            "message-id" => "Message 1 message-id"
          }
        },
        "delivery-status" => {
          "message" => "Delivery Status 1 Message",
          "description" => "Delivery Status 1 description",
          "code"  => 550
        }
      },
      {
        "event" => "failed",
        "severity" => "permanent",
        "timestamp" => "1407314177.8627768",
        "recipient" => 'test2@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 2",
            "message-id" => "Message 2 message-id"
          }
        },
        "delivery-status" => {
          "message" => "Delivery Status 2 Message",
          "description" => "Delivery Status 2 description",
          "code"  => 605
        }
      }
    ]
  end

  def get_one_permanent_failure_with_no_message_parameter
    return [
      {
        "severity" => "permanent",
        "timestamp" => 1407314177.8627768,
        "delivery-status" => {
          "message" => "Delivery Status 1 Message",
          "code" => "5.1.1",
          "description" => "Delivery Status 1 description"
        },
        "recipient" => "test1@example.com",
        "event" => "failed"
      }
    ]
  end

  def get_two_permanent_failures_one_with_message_and_other_with_description
    return [
      {
        "event" => "failed",
        "severity" => "permanent",
        "timestamp" => "1407314177.8627763",
        "recipient" => 'test1@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 1",
            "message-id" => "Message 1 message-id"
          }
        },
        "delivery-status" => {
          "message" => "Delivery Status 1 Message",
          "description" => "Delivery Status 1 description",
          "code"  => 550
        }
      },
      {
        "event" => "failed",
        "severity" => "permanent",
        "timestamp" => "1407314177.8627768",
        "recipient" => 'test2@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 2",
            "message-id" => "Message 2 message-id"
          }
        },
        "delivery-status" => {
          "description" => "Delivery Status 2 description",
          "code"  => 550
        }
      }
    ]
  end

  def get_one_spammed_event
    return [
      {
        "event" => "complained",
        "timestamp" => "1407314177.8627768",
        "recipient" => 'test2@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 2",
            "message-id" => "Message 2 message-id"
          }
        }
      }
    ]
  end

  def get_one_failed_one_bounced_event
    return [
      {
        "event" => "failed",
        "severity" => "permanent",
        "timestamp" => "1407314177.8627763",
        "recipient" => 'test1@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 1",
            "message-id" => "Message 1 message-id"
          }
        },
        "delivery-status" => {
          "message" => "Delivery Status 1 Message",
          "description" => "Delivery Status 1 description",
          "code"  => 666
        }
      },
      {
        "event" => "failed",
        "severity" => "permanent",
        "timestamp" => "1407314177.8627778",
        "recipient" => 'test2@example.com',
        "message" => {
          "headers" => {
            "subject" => "Test subject 3",
            "message-id" => "Message 3 message-id"
          }
        },
        "delivery-status" => {
          "description" => "Delivery Status 3 description",
          "code"  => 550
        },
        "reason" => "bounce"
      }
    ]
  end
end



