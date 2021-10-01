require_relative './../test_helper.rb'

class IncomingMailsControllerTest < ActionController::TestCase
  def setup
    super
    @message_id = '<asfhemxahef-facdsajfffm-dfsac@gmail.com>'
    @token = '3ohe4aeu7q0n6zjm1b0lbmvhro1v-s0zr6t9oieqhqm0vmnfm2'
    @timestamp = '1351248513'
    @signature = '303611ee8b73ea66858ee6c248c7fbf40377e72c6702453e5486a03285e35fde'
    @credentials = { token: @token, timestamp: @timestamp, signature: @signature }
  end

	def test_save_message
    assert_difference 'ReceivedMail.count' do
      https_post :create, params: { 'Message-Id' => @message_id, 'stripped-text' => 'some text'}
    end
    assert_equal 'some text', ReceivedMail.last.stripped_text
    assert_no_difference 'ReceivedMail.count' do
      https_post :create, params: { 'Message-Id' => @message_id, 'stripped-text' => 'some new text'}
    end
    assert_false ReceivedMail.last.stripped_text == 'some new text'
  end

  def test_verify_signature_failure_no_params
    https_post :create
    assert_response 403
  end

  def test_verify_signature_failure_invalid_signature
    https_post :create, params: { :token => @token, :timestamp => @timestamp, :signature => 'greg3db602e377e217356f93u5tf3u5uu235ufe7d9ab4a4dd83e88e55fcd16e8e9'}
    assert_response 403
  end

  def test_verrify_signature_success
    https_post :create, :params => @credentials
    assert_response 200
  end

  def test_verify_receiver_failure
    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => @message_id)
    end
    assert_equal ReceivedMail::Response.invalid_receiver, ReceivedMail.last.response

    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => 'afsreew2435r243','To' => 'reply@m.chronus.com')
    end
    assert_equal ReceivedMail::Response.invalid_receiver, ReceivedMail.last.response

    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => 'afsreew2435r244','To' => 'test@gmail.com')
    end
    assert_equal ReceivedMail::Response.invalid_receiver, ReceivedMail.last.response
  end

  def test_verify_receiver_success
    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => @message_id, 'To' => 'reply-dev+2rr4t42r4+43gsaf45@m.chronus.com')
    end
    assert_false  ReceivedMail.last.response == ReceivedMail::Response.invalid_receiver
  end

  def test_verify_receiver_success_for_multiple_receiver
    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => @message_id, 'To' => 'reply-test+2rr4t42r4+43gsaf45@m.chronus.com')
    end
    assert_false  ReceivedMail.last.response == ReceivedMail::Response.invalid_receiver

    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => 'afsreew2435r244','To' => 'test@gmail.com, reply-dev+2rr4t42r4+43gsaf45@m.chronus.com')
    end
    assert_false  ReceivedMail.last.response == ReceivedMail::Response.invalid_receiver
  end

  def test_verify_receiver_failure_for_cc
    assert_difference 'ReceivedMail.count' do
      https_post :create, params: @credentials.merge('Message-Id' => 'afsreew2435r245','Cc' => 'test@gmail.com, reply-dev+2rr4t42r4+43gsaf45@m.chronus.com')
    end
    assert ReceivedMail.last.response == ReceivedMail::Response.invalid_receiver
  end

  def test_no_content_failure
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    msg_receiver = messages(:first_message).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = messages(:first_message).context_program
    user = msg_receiver.member.user_in_program(program)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: user, program: program, browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_no_difference 'Message.count' do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+messages(:first_message).message_receivers.first.api_token+
                                              '+'+ReplyViaEmail::MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.no_content, ReceivedMail.last.response
  end

  def test_invalid_obj_type
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    msg_receiver = messages(:first_message).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = messages(:first_message).context_program
    user = msg_receiver.member.user_in_program(program)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: user, program: program, browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_no_difference 'Message.count' do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'stripped-text' => 'some text',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+messages(:first_message).message_receivers.first.api_token+
                                              '+54325someJunkText3232@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.invalid_object_type, ReceivedMail.last.response
  end

  def test_invalid_api_token
    assert_nil AbstractMessageReceiver.find_by(api_token: 'faF4j5kye23')
    assert_difference 'ReceivedMail.count',1 do
      assert_no_difference 'Message.count' do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'stripped-text' => 'some text',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+faF4j5kye23+'+ReplyViaEmail::MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.invalid_api_token, ReceivedMail.last.response
  end

  def test_create_message_via_reply_to_email
    msg_receiver = messages(:first_message).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = messages(:first_message).context_program
    user = msg_receiver.member.user_in_program(program)

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).once
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: user, program: program, browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Message.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'stripped-text' => 'Reply to email content',
                                              'from' => msg_receiver.member.email,
                                              'To' => APP_CONFIG[:reply_to_email_username] +
                                              '+' + msg_receiver.api_token +
                                              '+' + ReplyViaEmail::MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert Message.last.content == 'Reply to email content'
    assert_nil Message.last.context_program_id
  end

  def test_create_message_with_program_context_via_reply_to_email
    messages(:first_message).update_attribute(:context_program_id, programs(:albers).id)
    msg_receiver = messages(:first_message).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = messages(:first_message).context_program
    user = msg_receiver.member.user_in_program(program)

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).once
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Message.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'stripped-text' => 'Reply to email content',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+messages(:first_message).message_receivers.first.api_token+
                                              '+'+ReplyViaEmail::MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert Message.last.content == 'Reply to email content'
    assert_equal programs(:albers).id, Message.last.context_program_id
  end

  def test_create_admin_message_via_reply_to_email
    msg_receiver = messages(:third_admin_message).message_receivers.first
    receiver_member = msg_receiver.member
    program = messages(:third_admin_message).context_program
    user = msg_receiver.member.user_in_program(program)
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'AdminMessage.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'stripped-text' => 'Reply to email content',
                                              'from' => msg_receiver.member.email,
                                              'To' => APP_CONFIG[:reply_to_email_username] +
                                              '+' + msg_receiver.api_token +
                                              '+' + ReplyViaEmail::ADMIN_MESSAGE + '@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert AdminMessage.last.content == 'Reply to email content'

    msg_receiver = messages(:first_admin_message).message_receivers.first
    receiver_member = msg_receiver.member
    program = messages(:third_admin_message).context_program
    user = receiver_member.user_in_program(program) if receiver_member.present?

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.try(:organization), {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.try(:organization), {user: users(:f_mentor), program: programs(:albers), browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'AdminMessage.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => 'wrefgw543634adfsrgg62srgaijfscamfgj',
                                              'stripped-text' => 'Reply to second email content',
                                              'from' => 'ram@example.com',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+messages(:first_admin_message).message_receivers.first.api_token+
                                              '+'+ReplyViaEmail::ADMIN_MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert AdminMessage.last.content == 'Reply to second email content'

    msg_receiver = messages(:second_admin_message).message_receivers.first
    receiver_member = msg_receiver.member
    program = messages(:third_admin_message).context_program
    user = msg_receiver.member.user_in_program(program) if receiver_member.present?

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.try(:organization), {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.try(:organization), {user: users(:f_mentor), program: programs(:albers), browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'AdminMessage.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => 'sgavd57643634adfsrgg62srga756camfoui',
                                              'stripped-text' => 'Reply to third email content',
                                              'from' => 'ram@example.com',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+messages(:second_admin_message).message_receivers.first.api_token+
                                              '+'+ReplyViaEmail::ADMIN_MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert AdminMessage.last.content == 'Reply to third email content'
  end

  def test_create_admin_message_via_reply_to_email_for_offline_user
    msg_receiver = messages(:reply_to_offline_user).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = messages(:reply_to_offline_user).context_program 
    user = msg_receiver.member.user_in_program(program) if msg_receiver.member.present?
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.try(:organization), {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.try(:organization), {user: users(:f_mentor), program: programs(:albers), browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'AdminMessage.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => 'awrefgw543634f635fg623f3w45',
                                              'stripped-text' => 'Reply to new email content',
                                              'from' => msg_receiver.email,
                                              'To' => APP_CONFIG[:reply_to_email_username] +
                                              '+' + msg_receiver.api_token +
                                              '+' + ReplyViaEmail::ADMIN_MESSAGE+'@m.chronus.com')
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert AdminMessage.last.content == 'Reply to new email content'
  end

   def test_signature_present_in_message_via_reply_to_email
    msg_receiver = messages(:first_message).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = messages(:first_message).context_program
    user = msg_receiver.member.user_in_program(program)

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.organization, {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).once
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.organization, {user: user, program: program, browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Message.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'stripped-text' => 'Reply to email content',
                                              'stripped-signature' => 'This is a signature',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+messages(:first_message).message_receivers.first.api_token+
                                              '+'+ReplyViaEmail::MESSAGE+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert Message.last.content.match "This is a signature"
  end

  def test_create_scrap_reply_to_email_from_connection_membership
    cm = connection_memberships(:connection_memberships_1)
    
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'ActivityLog.count',1 do
        assert_difference 'Scrap.count',1 do
          https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                                'stripped-text' => 'Reply to email content',
                                                'To' => APP_CONFIG[:reply_to_email_username]+
                                                '+'+cm.api_token+
                                                '+'+ReplyViaEmail::SCRAP+'@m.chronus.com' )
        end
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert_equal Scrap.last.receivers.count, cm.group.members.count - 1
    assert Scrap.last.content == 'Reply to email content'
    assert Scrap.last.posted_via_email
  end

  def test_create_scrap_reply_to_email
    message = messages(:mygroup_mentor_1)
    msg_receiver = messages(:mygroup_mentor_1).message_receivers.first
    receiver_member = msg_receiver.try(:member)
    program = message.context_program
    user = members(:mkr_student).user_in_program(program)
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, receiver_member, receiver_member.try(:organization), {user: user, program: program, browser: browser}).once
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, receiver_member, receiver_member.try(:organization), {:context_place => EngagementIndex::Src::ReplyUsers::EMAIL, user: user, program: program, browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'ActivityLog.count',1 do
        assert_difference 'Scrap.count',1 do
          https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                                'stripped-text' => 'Reply to email content',
                                                'To' => APP_CONFIG[:reply_to_email_username]+
                                                '+'+messages(:mygroup_mentor_1).message_receivers.first.api_token+
                                                '+'+ReplyViaEmail::MESSAGE+'@m.chronus.com' )
        end
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert Scrap.last.content == 'Reply to email content'
    assert Scrap.last.posted_via_email
  end

  def test_attachments_are_deleted
    assert_difference 'ReceivedMail.count',1 do
      https_post :create, params: { 'Message-Id' => @message_id,
                          'stripped-text' => 'some new text',
                          'attachment-1' => 'Text for attachment 1',
                          'attachment-2' => 'Text for attachment 2',
                          'attachment-count' => '2'
                        }
    end
    data_dump = ReceivedMail.last.data
    data_hash = Marshal.load(data_dump)
    assert_equal '2', data_hash['attachment-count']
    assert_nil data_hash['attachment-1']
    assert_nil data_hash['attachment-2']
  end

  def test_create_reply_to_meeting_request_accepted_calendar_email
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    meeting_request = create_meeting_request(:mentor => users(:f_mentor), :student => users(:mkr_student), :status => AbstractRequest::Status::ACCEPTED)
    api_token_string = meeting_request.meeting.member_meetings.pluck(:api_token).join('-')
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, members(:f_mentor), members(:f_mentor).organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never
    
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Scrap.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'Subject' => "Test",
                                              'stripped-text' => 'Reply to email content calendar',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+api_token_string+
                                              '+'+ReplyViaEmail::MEETING_REQUEST_ACCEPTED_CALENDAR+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert_equal 'Reply to email content calendar', Scrap.last.content
    assert_equal "Meeting", Scrap.last.ref_obj_type
    assert Scrap.last.posted_via_email
  end

  def test_create_reply_to_meeting_request_accepted_non_calendar_email
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    meeting_request = create_meeting_request(:mentor => users(:f_mentor), :student => users(:mkr_student), :status => AbstractRequest::Status::ACCEPTED)
    api_token_string = meeting_request.meeting.member_meetings.pluck(:api_token).join('-')
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, members(:f_mentor), members(:f_mentor).organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never

    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Scrap.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'Subject' => "Test",
                                              'stripped-text' => 'Reply to email content non calendar',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+api_token_string+
                                              '+'+ReplyViaEmail::MEETING_REQUEST_ACCEPTED_NON_CALENDAR+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert_equal 'Reply to email content non calendar', Scrap.last.content
    assert_equal "Meeting", Scrap.last.ref_obj_type
    assert Scrap.last.posted_via_email
  end

  def test_create_reply_to_meeting_update_notification_email
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    api_token_string = meeting.member_meetings.pluck(:api_token).join('-')
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, members(:f_mentor), members(:f_mentor).organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Scrap.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'Subject' => "Test",
                                              'stripped-text' => 'Reply to email content',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+api_token_string+
                                              '+'+ReplyViaEmail::MEETING_UPDATE_NOTIFICATION+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert_equal 'Reply to email content', Scrap.last.content
    assert_equal "Meeting", Scrap.last.ref_obj_type
    assert Scrap.last.posted_via_email
  end

  def test_create_reply_to_meeting_rsvp_notification_email
    time = 2.days.from_now
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    api_token_string = meeting.member_meetings.pluck(:api_token).join('-')
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, members(:f_mentor), members(:f_mentor).organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Scrap.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'Subject' => "Test",
                                              'stripped-text' => 'Reply to email content new',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+api_token_string+
                                              '+'+ReplyViaEmail::MEETING_RSVP_NOTIFICATION_OWNER+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert_equal 'Reply to email content new', Scrap.last.content
    assert_equal "Meeting", Scrap.last.ref_obj_type
    assert Scrap.last.posted_via_email
  end

  def test_create_reply_to_meeting_create_notification
    time = 2.days.from_now
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    #group_meeting
    meeting = create_meeting(force_non_group_meeting: false, start_time: time, end_time: time + 30.minutes, :members => [members(:f_mentor), members(:mkr_student), members(:student_2)])
    api_token_string = meeting.member_meetings.where(:member_id => [members(:f_mentor).id, members(:mkr_student).id]).pluck(:api_token).join('-')
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA, members(:f_mentor), members(:f_mentor).organization, {user: users(:f_mentor), program: programs(:albers), browser: browser}).never
    assert_difference 'ReceivedMail.count',1 do
      assert_difference 'Scrap.count',1 do
        https_post :create, params: @credentials.merge('Message-Id' => @message_id,
                                              'Subject' => "Test",
                                              'stripped-text' => 'Reply to email content new',
                                              'To' => APP_CONFIG[:reply_to_email_username]+
                                              '+'+api_token_string+
                                              '+'+ReplyViaEmail::MEETING_CREATED_NOTIFICATION+'@m.chronus.com' )
      end
    end
    assert_equal  ReceivedMail::Response.successfully_accepted, ReceivedMail.last.response
    assert_equal 'Reply to email content new', Scrap.last.content
    assert_equal "Group", Scrap.last.ref_obj_type
    assert Scrap.last.posted_via_email
  end

  private

  def get_new_browser
    Browser.new(request.headers["User-Agent"], accept_language: request.headers["Accept-Language"])
  end

end