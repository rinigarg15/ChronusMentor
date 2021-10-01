require_relative './../../../test_helper.rb'
class GoogleApiTest < ActiveSupport::TestCase

  def test_new
    Calendar::GoogleApi.expects(:get_calendar_service).returns("")
    Calendar::GoogleApi.new("schedulingtest@chronus.com")
  end

  def test_get_service_authorizer
    authorizer = Calendar::GoogleApi.get_service_authorizer("schedulingtest@chronus.com")
    client_id = authorizer.instance_eval("@client_id").instance_eval("@id")
    secret = authorizer.instance_eval("@client_id").instance_eval("@secret")
    assert_equal "340.apps.googleusercontent.com", client_id
    assert_equal "pIRd", secret
  end

  def test_get_authorization_credentials
    credentials = Calendar::GoogleApi.get_authorization_credentials("schedulingtest@chronus.com")
    assert_equal "340.apps.googleusercontent.com", credentials.client_id
    assert_equal "pIRd", credentials.client_secret
    assert_equal ["https://www.googleapis.com/auth/calendar"], credentials.scope
    assert_equal "ya29.Glt9BCeHZH9V", credentials.access_token
    assert_equal "1/6R2Z3gvk", credentials.refresh_token
  end

  def test_get_calendar_service
    service = Calendar::GoogleApi.get_calendar_service("schedulingtest@chronus.com")
    client_options = service.client_options
    authorization_options = service.request_options.authorization
    assert_equal "Google Calendar API Mentor", client_options.application_name
    assert_equal "340.apps.googleusercontent.com", authorization_options.client_id
    assert_equal "pIRd", authorization_options.client_secret
    assert_equal ["https://www.googleapis.com/auth/calendar"], authorization_options.scope
    assert_equal "ya29.Glt9BCeHZH9V", authorization_options.access_token
    assert_equal "1/6R2Z3gvk", authorization_options.refresh_token
  end

  def test_get_client_secret_path
    path = File.join(Rails.root, "test/fixtures/files/calendar_sync/calendar_api_client_secret.json")
    assert_equal path, Calendar::GoogleApi.get_client_secret_path
  end

  def test_get_api_credentials_path
    path = File.join(Rails.root, "test/fixtures/files/calendar_sync/calendar_api_credentials.yaml")
    assert_equal path, Calendar::GoogleApi.get_api_credentials_path
  end


  def test_remove_calendar_event
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id")

    options = meeting.get_calendar_event_options

    service = Calendar::GoogleApi.get_calendar_service("schedulingtest@chronus.com")
    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:delete_event).returns("Event Deleted")

    assert_equal "Event Deleted", Calendar::GoogleApi.new("schedulingtest@chronus.com").remove_calendar_event(options)

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:delete_event).raises(->{StandardError.new("Some error")})

    Google::Apis::CalendarV3::CalendarService.any_instance.expects(:delete_event).raises(->{StandardError.new("Some error")}).times(3)

    Airbrake.expects(:notify).once

    assert_difference 'CalendarSyncErrorCases.count', 1 do
      Calendar::GoogleApi.new("schedulingtest@chronus.com").remove_calendar_event(options)
    end

    error_case = CalendarSyncErrorCases.last
    assert_equal CalendarSyncErrorCases::ScenarioType::EVENT_DELETE, error_case.scenario
  end

  def test_update_calendar_event
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: Time.now, end_time: Time.now + 30.minutes, calendar_event_id: "calendar_event_id")

    options = meeting.get_calendar_event_options

    service = Calendar::GoogleApi.get_calendar_service("schedulingtest@chronus.com")
    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:get_event).returns(get_calendar_event_resource)
    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:update_event).returns(get_calendar_event_resource)

    assert_equal_hash get_calendar_event_resource, Calendar::GoogleApi.new("schedulingtest@chronus.com").update_calendar_event(options, "event_id")

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:update_event).raises(->{StandardError.new("Some error")})

    Google::Apis::CalendarV3::CalendarService.any_instance.expects(:update_event).raises(->{StandardError.new("Some error")}).times(3)

    Airbrake.expects(:notify).once
    Calendar::GoogleApi.new("schedulingtest@chronus.com").update_calendar_event(options, "event_id")

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:update_event).returns("Event Updated")
    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:get_event).raises(->{StandardError.new("Some error")})
    Google::Apis::CalendarV3::CalendarService.any_instance.expects(:get_event).raises(->{StandardError.new("Some error")}).times(3)

    Airbrake.expects(:notify).once

    assert_difference 'CalendarSyncErrorCases.count', 1 do
      Calendar::GoogleApi.new("schedulingtest@chronus.com").update_calendar_event(options, "event_id")
    end

    error_case = CalendarSyncErrorCases.last
    assert_equal CalendarSyncErrorCases::ScenarioType::EVENT_UPDATE, error_case.scenario
  end

  def test_perform_rsvp_sync
    current_time = Time.now
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: current_time, end_time: current_time + 30.minutes, calendar_event_id: "calendar_event_id")

    scheduling_account = scheduling_accounts(:scheduling_account_1)
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: current_time, last_sync_token: "sync_token", scheduling_account_id: scheduling_account.id)

    event = get_calendar_event_resource

    response = {:items => [event], :next_sync_token => "new_sync_token"}
    response = OpenStruct.new response

    service = Calendar::GoogleApi.get_calendar_service("schedulingtest@chronus.com")
    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:list_events).with("primary", {single_events: true, sync_token: "sync_token"}).returns(response)

    Meeting.expects(:perform_rsvp_sync_from_calendar_to_app).with([event], scheduling_account.email).once
    assert_nil channel.last_sync_time

    CalendarSyncRsvpLogs.expects(:create_rsvp_sync_log).times(3)

    Calendar::GoogleApi.new("schedulingtest@chronus.com").perform_rsvp_sync(current_time, channel)

    assert_equal "new_sync_token", channel.reload.last_sync_token
    assert_not_nil channel.last_sync_time

    response1 = {:items => [event], :next_page_token => "next_page_token"}
    response1 = OpenStruct.new response1

    response.next_sync_token = "latest_sync_token"

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:list_events).with("primary", {single_events: true, sync_token: "new_sync_token"}).returns(response1)
    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:list_events).with("primary", {single_events: true, sync_token: "new_sync_token", page_token: "next_page_token"}).returns(response)

    response2 = {:items => [event], :next_sync_token => "last_sync_token"}
    response2 = OpenStruct.new response2

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:list_events).with("primary", {single_events: true, sync_token: "latest_sync_token"}).returns(response2)

    response3 = {:items => [], :next_sync_token => "end_sync_token"}
    response3 = OpenStruct.new response3

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:list_events).with("primary", {single_events: true, sync_token: "last_sync_token"}).returns(response3)

    Meeting.expects(:perform_rsvp_sync_from_calendar_to_app).with([event, event], scheduling_account.email).once
    Meeting.expects(:perform_rsvp_sync_from_calendar_to_app).with([event], scheduling_account.email).once

    channel.update_attribute(:last_notification_received_on, current_time + 10.seconds)

    Time.stubs(:now).returns(current_time + 20.seconds)


    Calendar::GoogleApi.new("schedulingtest@chronus.com").perform_rsvp_sync(current_time, channel)

    assert_equal "last_sync_token", channel.reload.last_sync_token

    channel.update_attribute(:last_notification_received_on, current_time)

    Google::Apis::CalendarV3::CalendarService.any_instance.stubs(:list_events).raises(->{StandardError.new("Some error")})
    Google::Apis::CalendarV3::CalendarService.any_instance.expects(:list_events).raises(->{StandardError.new("Some error")}).times(3)

    Airbrake.expects(:notify).once

    assert_difference 'CalendarSyncErrorCases.count', 1 do
      Calendar::GoogleApi.new("schedulingtest@chronus.com").perform_rsvp_sync(current_time, channel)
    end

    error_case = CalendarSyncErrorCases.last
    assert_equal CalendarSyncErrorCases::ScenarioType::RSVP_SYNC, error_case.scenario

    assert_nil channel.reload.last_sync_token
  end

end