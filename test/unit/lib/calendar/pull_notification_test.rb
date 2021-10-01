require_relative './../../../test_helper.rb'
class PullNotificationTest < ActiveSupport::TestCase
  def test_update_meetings_with_calendars_diff_meetings
    current_time =Time.now
    Timecop.freeze(current_time) do
      mg_events_mock = mock()
      mg_events_response = mock()
      empty_response = mock()
      empty_response.expects(:to_h).returns({})
      m1 = meetings(:upcoming_calendar_meeting)
      m2 = meetings(:f_mentor_mkr_student_daily_meeting)
      Meeting.any_instance.stubs(:can_be_synced?).returns(true)
      mg_events_response.expects(:to_h).returns(JSON.parse("{\n  \"items\": [{\"tags\":[],\"timestamp\":1513774719.463357,\"storage\":{\"url\":\"https://sw.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1234\",\"key\":\"1234\"},\"log-level\":\"info\",\"id\":\"YpILJPtbQOSVF9HA-F1Nog\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a114b55e24698480560c524ff@google.com\",\"from\":\"Arun Kumar N <robert@example.com>\",\"subject\":\"Accepted: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com\"],\"size\":15799},\"event\":\"stored\"},{\"tags\":[],\"timestamp\":1513774419.683437,\"storage\":{\"url\":\"https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235\",\"key\":\"1235\"},\"log-level\":\"info\",\"id\":\"nw4VFduMQi-UGrm7pYAE3w\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a113caf86721ce90560c5120e@google.com\",\"from\":\"Arun Kumar N <mkr@example.com>\",\"subject\":\"Declined: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}@testmg.realizegoal.com\"],\"size\":15801},\"event\":\"stored\"}],\n  \"paging\": {\n    \"next\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123456\",\n    \"last\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12346\",\n    \"first\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123\",\n    \"previous\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12345\"\n  }\n}"))
      mg_events_mock.expects(:get).with(limit: 100, begin: (current_time - 1.day).utc.to_i, end: current_time.utc.to_i, ascending: "yes", event: "stored").returns(mg_events_response)
        mg_events_mock.expects(:next).returns(empty_response)
      Mailgun::Events.expects(:new).returns(mg_events_mock)
      Mailgun::Client.expects(:new).returns(mock())

      rest_client_mock1 = mock()
      rest_mock_response1 = mock()
      rest_mock_response1.expects(:body).returns({"To"=>"Apollo Services\t<calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>", "body-calendar" => "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"}.to_json.to_s)
      rest_client_mock1.expects(:get).returns(rest_mock_response1)
      RestClient::Resource.expects(:new).with("https://sw.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1234", user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}").returns(rest_client_mock1)


      rest_client_mock2 = mock()
      rest_mock_response2 = mock()
      rest_mock_response2.expects(:body).returns({"To"=>"Apollo Services\t<calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}@testmg.realizegoal.com>", "body-calendar" => "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m2.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m2.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m2.id)}\n @testmg.realizegoal.com\nRECURRENCE-ID;TZID=Asia/Calcutta:#{DateTime.localize(m2.reload.occurrences[2].utc, format: :ics_full_time)}\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m2.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m2.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"}.to_json.to_s)
      rest_client_mock2.expects(:get).returns(rest_mock_response2)
      RestClient::Resource.expects(:new).with("https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235", user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}").returns(rest_client_mock2)

      mm1 = member_meetings(:member_meetings_13)
      mm2 = member_meetings(:member_meetings_11)

      assert_equal MemberMeeting::ATTENDING::YES, mm1.attending
      assert_equal [MemberMeeting::ATTENDING::YES, MemberMeeting::ATTENDING::NO], mm2.member_meeting_responses.pluck(:attending).uniq
      assert_equal MemberMeeting::ATTENDING::YES, mm2.attending

      Calendar::PullNotification.new().update_meetings_and_program_events_with_calendars
      assert_equal MemberMeeting::ATTENDING::NO, mm1.reload.attending
      assert_equal [MemberMeeting::ATTENDING::YES, MemberMeeting::ATTENDING::NO], mm2.member_meeting_responses.pluck(:attending).uniq
      assert_equal MemberMeeting::ATTENDING::YES, mm2.attending
    end
  end

  def test_update_meetings_with_calendars_same_meeting_diff_users
    current_time =Time.now
    Timecop.freeze(current_time) do
      mg_events_mock = mock()
      mg_events_response = mock()
      empty_response = mock()
      empty_response.expects(:to_h).returns({})
      m1 = meetings(:upcoming_calendar_meeting)
      Meeting.any_instance.stubs(:can_be_synced?).returns(true)
      mg_events_response.expects(:to_h).returns(JSON.parse("{\n  \"items\": [{\"tags\":[],\"timestamp\":1513774719.463357,\"storage\":{\"url\":\"https://sw.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1234\",\"key\":\"1234\"},\"log-level\":\"info\",\"id\":\"YpILJPtbQOSVF9HA-F1Nog\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a114b55e24698480560c524ff@google.com\",\"from\":\"Arun Kumar N <robert@example.com>\",\"subject\":\"Accepted: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com\"],\"size\":15799},\"event\":\"stored\"},{\"tags\":[],\"timestamp\":1513774419.683437,\"storage\":{\"url\":\"https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235\",\"key\":\"1235\"},\"log-level\":\"info\",\"id\":\"nw4VFduMQi-UGrm7pYAE3w\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a113caf86721ce90560c5120e@google.com\",\"from\":\"Arun Kumar N <mkr@example.com>\",\"subject\":\"Declined: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com\"],\"size\":15801},\"event\":\"stored\"}],\n  \"paging\": {\n    \"next\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123456\",\n    \"last\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12346\",\n    \"first\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123\",\n    \"previous\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12345\"\n  }\n}"))
      mg_events_mock.expects(:get).with(limit: 100, begin: (current_time - 1.day).utc.to_i, end: current_time.utc.to_i, ascending: "yes", event: "stored").returns(mg_events_response)
        mg_events_mock.expects(:next).returns(empty_response)
      Mailgun::Events.expects(:new).returns(mg_events_mock)
      Mailgun::Client.expects(:new).returns(mock())

      rest_client_mock1 = mock()
      rest_mock_response1 = mock()
      rest_mock_response1.expects(:body).returns({"To"=>"Apollo Services\t<calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>", "body-calendar" => "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"}.to_json)
      rest_client_mock1.expects(:get).returns(rest_mock_response1)
      RestClient::Resource.expects(:new).with("https://sw.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1234", user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}").returns(rest_client_mock1)


      rest_client_mock2 = mock()
      rest_mock_response2 = mock()
      rest_mock_response2.expects(:body).returns({"To"=>"Apollo Services\t<calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>", "body-calendar" => "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:mkr@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"}.to_json.to_s)
      rest_client_mock2.expects(:get).returns(rest_mock_response2)
      RestClient::Resource.expects(:new).with("https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235", user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}").returns(rest_client_mock2)

      mm1 = member_meetings(:member_meetings_13)
      mm2 = member_meetings(:member_meetings_14)

      assert_equal MemberMeeting::ATTENDING::YES, mm1.attending
      assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, mm2.attending

      Calendar::PullNotification.new().update_meetings_and_program_events_with_calendars
      assert_equal MemberMeeting::ATTENDING::NO, mm1.reload.attending
      assert_equal MemberMeeting::ATTENDING::NO, mm2.reload.attending
    end
  end

  def test_update_meetings_with_calendars_same_meeting_same_users
    current_time =Time.now
    Timecop.freeze(current_time) do
      mg_events_mock = mock()
      mg_events_response = mock()
      empty_response = mock()
      empty_response.expects(:to_h).returns({})
      m1 = meetings(:upcoming_calendar_meeting)
      Meeting.any_instance.stubs(:can_be_synced?).returns(true)
      mg_events_response.expects(:to_h).returns(JSON.parse("{\n  \"items\": [{\"tags\":[],\"timestamp\":1513774719.463357,\"storage\":{\"url\":\"https://sw.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1234\",\"key\":\"1234\"},\"log-level\":\"info\",\"id\":\"YpILJPtbQOSVF9HA-F1Nog\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a114b55e24698480560c524ff@google.com\",\"from\":\"Arun Kumar N <robert@example.com>\",\"subject\":\"Accepted: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com\"],\"size\":15799},\"event\":\"stored\"},{\"tags\":[],\"timestamp\":1513774419.683437,\"storage\":{\"url\":\"https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235\",\"key\":\"1235\"},\"log-level\":\"info\",\"id\":\"nw4VFduMQi-UGrm7pYAE3w\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a113caf86721ce90560c5120e@google.com\",\"from\":\"Arun Kumar N <robert@example.com>\",\"subject\":\"Declined: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com\"],\"size\":15801},\"event\":\"stored\"}],\n  \"paging\": {\n    \"next\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123456\",\n    \"last\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12346\",\n    \"first\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123\",\n    \"previous\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12345\"\n  }\n}"))
      mg_events_mock.expects(:get).with(limit: 100, begin: (current_time - 1.day).utc.to_i, end: current_time.utc.to_i, ascending: "yes", event: "stored").returns(mg_events_response)
        mg_events_mock.expects(:next).returns(empty_response)
      Mailgun::Events.expects(:new).returns(mg_events_mock)
      Mailgun::Client.expects(:new).returns(mock())

      rest_client_mock1 = mock()
      rest_mock_response1 = mock()
      rest_mock_response1.expects(:body).returns({"To"=>"Apollo Services\t<calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>", "body-calendar" => "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"}.to_json.to_s)
      rest_client_mock1.expects(:get).returns(rest_mock_response1)
      RestClient::Resource.expects(:new).with("https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235", user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}").returns(rest_client_mock1)


      mm1 = member_meetings(:member_meetings_13)

      assert_equal MemberMeeting::ATTENDING::YES, mm1.attending

      Calendar::PullNotification.new().update_meetings_and_program_events_with_calendars
      assert_equal MemberMeeting::ATTENDING::NO, mm1.reload.attending # RestClient::Resource is called only once with the second URL(https://SE.api...) in the events list
    end
  end

  def test_update_program_event_with_calendar
    current_time =Time.now
    Timecop.freeze(current_time) do
      mg_events_mock = mock()
      mg_events_response = mock()
      empty_response = mock()
      empty_response.expects(:to_h).returns({})
      program_event = program_events(:birthday_party)
      ProgramEvent.any_instance.stubs(:can_be_synced?).returns(true)
      mg_events_response.expects(:to_h).returns(JSON.parse("{\n  \"items\": [{\"tags\":[],\"timestamp\":1513774719.463357,\"storage\":{\"url\":\"https://sw.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1234\",\"key\":\"1234\"},\"log-level\":\"info\",\"id\":\"YpILJPtbQOSVF9HA-F1Nog\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(program_event.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a114b55e24698480560c524ff@google.com\",\"from\":\"Arun Kumar N <robert@example.com>\",\"subject\":\"Accepted: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(program_event.id)}@testmg.realizegoal.com\"],\"size\":15799},\"event\":\"stored\"},{\"tags\":[],\"timestamp\":1513774419.683437,\"storage\":{\"url\":\"https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235\",\"key\":\"1235\"},\"log-level\":\"info\",\"id\":\"nw4VFduMQi-UGrm7pYAE3w\",\"campaigns\":[],\"user-variables\":{},\"flags\":{\"is-test-mode\":false},\"message\":{\"headers\":{\"to\":\"Apollo Services <event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(program_event.id)}@testmg.realizegoal.com>\",\"message-id\":\"001a113caf86721ce90560c5120e@google.com\",\"from\":\"Arun Kumar N <robert@example.com>\",\"subject\":\"Declined: as @ Fri Dec 22, 2017 1am - 1:30am (IST) (Apollo Services)\"},\"attachments\":[{\"size\":1537,\"content-type\":\"application/ics\",\"filename\":\"invite.ics\"}],\"recipients\":[\"event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(program_event.id)}@testmg.realizegoal.com\"],\"size\":15801},\"event\":\"stored\"}],\n  \"paging\": {\n    \"next\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123456\",\n    \"last\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12346\",\n    \"first\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/123\",\n    \"previous\": \"https://api.mailgun.net/v3/developmentmg.realizegoal.com/events/12345\"\n  }\n}"))
      mg_events_mock.expects(:get).with(limit: 100, begin: (current_time - 1.day).utc.to_i, end: current_time.utc.to_i, ascending: "yes", event: "stored").returns(mg_events_response)
        mg_events_mock.expects(:next).returns(empty_response)
      Mailgun::Events.expects(:new).returns(mg_events_mock)
      Mailgun::Client.expects(:new).returns(mock())

      rest_client_mock1 = mock()
      rest_mock_response1 = mock()
      rest_mock_response1.expects(:body).returns({"To"=>"Apollo Services\t<event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(program_event.id)}@testmg.realizegoal.com>", "body-calendar" => "BEGIN:VCALENDAR\r\nPRODID;X-RICAL-TZSOURCE=TZINFO:-//com.denhaven2/NONSGML ri_cal gem//EN\r\nCALSCALE:GREGORIAN\r\nVERSION:2.0\r\nMETHOD:REQUEST\r\nBEGIN:VEVENT\r\nCREATED:#{DateTime.localize(program_event.created_at.utc, format: :ics_full_time)}\r\nSTATUS:CONFIRMED\r\nDTSTART:#{DateTime.localize(program_event.start_time.utc, format: :ics_full_time)}\r\nTRANSP:OPAQUE\r\nDTSTAMP:#{DateTime.localize(program_event.created_at.utc, format: :ics_full_time)}\r\nLAST-MODIFIED:#{DateTime.localize(program_event.updated_at.utc, format: :ics_full_time)}\r\nATTENDEE;CN=student example;CUTYPE=INDIVIDUAL;PARTSTAT=ACCEPTED;ROLE=REQ-PARTICIPANT:mailto:rahim@example.com\r\nUID:program_event_#{DateTime.localize(program_event.created_at.utc, format: :ics_full_time)}@chronus.com\r\nDESCRIPTION:Message description:\nmail gun response\n\n\r\nSUMMARY:Test event mg\r\nORGANIZER;CN=Apollo Services:mailto:event-calendar-assistant-dev+#{ProgramEvent.send(:encryptor).encrypt(program_event.id)}@testmg.realizegoal.com\r\nLOCATION:CHENNAI\r\nEND:VEVENT\r\nEND:VCALENDAR"}.to_json.to_s)
      rest_client_mock1.expects(:get).returns(rest_mock_response1)
      RestClient::Resource.expects(:new).with("https://se.api.mailgun.net/v3/domains/testmg.realizegoal.com/messages/1235", user: 'api', password: APP_CONFIG[:mailgun_api_key], user_agent: "mailgun-sdk-ruby/#{Mailgun::VERSION}").returns(rest_client_mock1)
      assert_empty program_event.event_invites

      Calendar::PullNotification.new().update_meetings_and_program_events_with_calendars

      assert_equal 1, program_event.event_invites.count
      assert_equal 1, program_event.event_invites.count
      event_invite = program_event.event_invites.first
      assert_equal EventInvite::Status::YES, event_invite.status
      assert_equal users(:f_student), event_invite.user
    end
  end
end