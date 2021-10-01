require_relative './../test_helper.rb'

class MessagesControllerTest < ActionController::TestCase

  ### Message gets converted to Scrap when exchanged between members part of the same connection ###

  def test_new_message
    current_member_is :f_mentor
    get :new, params: { receiver_id: members(:f_student).id}
    assert_response :success
    assert_template "new"
    assert_equal members(:f_mentor), assigns(:message).sender
    assert_equal members(:f_student), assigns(:receiver)
    assert_nil assigns(:message).parent
    assert_equal programs(:org_primary), assigns(:message).organization
    assert_select "input#message_receiver_ids[type=\"hidden\"]"
  end

  def test_send_msg_to_member_by_popup
    current_user_is :f_admin
    member = members(:f_mentor)
    get :new, xhr: true, params: { popup: true, receiver_id: member.id}
    assert_response :success
    assert_select "div", class: "modal-header no-padding clearfix "
    assert_select "input#message_receiver_ids[type=\"hidden\"][value=\"#{member.id.to_s}\"]"
    assert_select "input#message_subject"
    assert_select "textarea#message_content"
  end

  def test_create
    current_member_is :f_mentor
    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).once
    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {receiver_ids: members(:mentor_1).id.to_s, subject: "Test", content: "Content", src: src, sender_id: members(:f_mentor).id,
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
      end
    end
    m = Message.last
    assert_redirected_to program_root_path
    assert_equal members(:f_mentor), m.sender
    assert_equal [members(:mentor_1)], m.receivers
    assert_nil m.parent
    assert_equal programs(:org_primary), m.organization
    assert_equal "SOMEspecialcharacters123_test.txt", m.attachment_file_name
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal "Test", m.subject
    assert_equal "Content", m.content
    assert_nil m.context_program
  end

  def test_create_reply_at_org_level
    current_member_is :f_mentor

    m = messages(:first_message)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).once
    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {parent_id: m.id, content: "Content",
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
      end
    end
    assert_nil Message.last.context_program_id

    m.update_attribute(:context_program_id, programs(:albers).id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).once
    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {parent_id: m.id, content: "Content",
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
      end
    end
    assert_equal programs(:albers).id, Message.last.context_program_id
  end

  def test_create_at_program_level
    current_program_is :albers
    current_user_is :f_mentor

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).once

    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {receiver_ids: members(:mentor_1).id.to_s, subject: "Test", src: src, content: "Content", sender_id: members(:f_mentor).id,
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
      end
    end
    m = Message.last
    assert_equal members(:f_mentor), m.sender
    assert_equal [members(:mentor_1)], m.receivers
    assert_nil m.parent
    assert_equal programs(:org_primary), m.organization
    assert_equal programs(:org_primary), m.program
    assert_equal "SOMEspecialcharacters123_test.txt", m.attachment_file_name
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal "Test", m.subject
    assert_equal "Content", m.content
    assert_equal programs(:albers).id, m.context_program_id
  end

  def test_create_reply_at_program_level
    current_program_is :albers
    current_user_is :f_mentor

    src = EngagementIndex::Src::ReplyUsers::INBOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: src}).once

    m = messages(:first_message)
    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {parent_id: m.id, content: "Content",
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
      end
    end
    assert_nil Message.last.context_program_id


    m.update_attribute(:context_program_id, programs(:albers).id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: src}).once
    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {parent_id: m.id, content: "Content",
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
      end
    end
    assert_equal programs(:albers).id, Message.last.context_program_id
  end

  def test_create_failure_with_invalid_attachment
    current_member_is :f_mentor

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).never

    assert_no_difference "Message.count" do
      post :create, params: { message: {receiver_ids: members(:mentor_1).id.to_s, subject: "Test", content: "Content", src: src, sender_id: members(:f_mentor).id,
        attachment:  fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')}
      }
    end
    assert_equal flash[:error], "Attachment content type is restricted and Attachment file name is invalid"
  end

  def test_create_failure_with_attachment_too_big
    current_member_is :f_mentor

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).never

    assert_no_difference "Message.count" do
      post :create, params: {message: {receiver_ids: members(:mentor_1).id.to_s, src: src, subject: "Test", content: "Content", sender_id: members(:f_mentor).id,
        attachment:  fixture_file_upload(File.join('files', 'TEST.JPG'), 'image/jpeg') }
      }
    end
    assert_equal flash[:error], "Attachment file size should be within #{AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE} MB"
  end

  def test_create_failure
    current_member_is :f_mentor

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).never

    assert_no_difference "Message.count" do
      post :create, params: { message: {receiver_ids: members(:mentor_1).id.to_s, src: src}}
    end
    assert_template :new
    assert_equal members(:mentor_1), assigns(:receiver)
    assert_equal "Problems posting the message. Please try again", flash[:error]
  end

  def test_create_only_receiver_can_reply
    assert_equal [members(:f_mentor)], messages(:first_message).receivers

    current_member_is :f_student

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).never

    assert_permission_denied do
      post :create, params: { message: {parent_id: messages(:first_message).id, content: "Content", src: src}}
    end
  end

  def test_allowed_to_send_message_false_trying_to_send_message
    current_user_is :f_mentor
    program = programs(:albers)
    program.update_attributes!(allow_user_to_send_message_outside_mentoring_area: false)
    users(:f_mentor).reload
    assert_false users(:f_mentor).allowed_to_send_message?(users(:mentor_1))

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).never

    assert_permission_denied do
      post :create, params: { message: {receiver_ids: members(:mentor_1).id.to_s, subject: "Test", content: "Content", src: src, sender_id: members(:f_mentor).id,
          attachment:  fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}
        }
    end
  end

  def test_create_reply
    current_member_is :f_mentor

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).once
    assert_emails 1 do
      assert_difference "Message.count" do
        post :create, params: { message: {parent_id: messages(:first_message).id, src: src, content: "Content",
          attachment:  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
        }
      end
    end
    m = Message.last
    assert_redirected_to message_path(messages(:first_message).root)
    assert_equal members(:f_mentor), m.sender
    assert_equal [members(:f_mentor_student)], m.receivers
    assert_equal messages(:first_message), m.parent
    assert_equal programs(:org_primary), m.organization
    assert_equal "test_pic.png", m.attachment_file_name
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal "Content", m.content
  end

  def test_create_reply_failure
    current_member_is :f_mentor

    src = EngagementIndex::Src::MessageUsers::MENTOR_REQUEST_LISTING_PAGE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::MESSAGE_USERS, {context_place: src}).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_USERS, {context_place: EngagementIndex::Src::ReplyUsers::INBOX}).never

    assert_no_difference "Message.count" do
      post :create, params: { message: {parent_id: messages(:first_message).id, src: src}}
    end
    assert_redirected_to message_path(messages(:first_message))
    assert_equal "Problems posting the message. Please try again", flash[:error]
  end

  def test_index
    message_ids_1 = messages(:first_message, :mygroup_student_1, :mygroup_student_2, :meeting_scrap).map(&:id)
    message_ids_2 = messages(:second_message, :mygroup_mentor_1, :mygroup_mentor_2, :mygroup_mentor_3, :mygroup_mentor_4).map(&:id)
    [message_ids_1, message_ids_2].each do |message_ids|
      AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, message_ids).returns(
        AbstractMessage.where(id: message_ids).order("FIELD(id, #{message_ids.reverse.join(',')})").paginate(page: 1, per_page: AbstractMessage::PER_PAGE))
    end

    current_member_is :f_mentor
    get :index
    assert_response :success
    presenter = assigns(:messages_presenter)
    assert presenter.fetch_data_for_all_tabs
    assert assigns(:messages_presenter).instance_of?(Messages::MessagesPresenter)
    assert assigns(:my_filters)
  end

  def test_index_format
    message_ids = messages(:first_message, :mygroup_student_1, :mygroup_student_2, :meeting_scrap).map(&:id)
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(2, message_ids).returns(
      AbstractMessage.where(id: message_ids).order("FIELD(id, #{message_ids.join(',')})").paginate(page: 1, per_page: AbstractMessage::PER_PAGE))

    current_member_is :f_mentor
    get :index, xhr: true, params: { format: :js, page: 2}
    assert_response :success
    presenter = assigns(:messages_presenter)
    assert_false presenter.fetch_data_for_all_tabs
  end

  def test_show_auth
    current_member_is :f_mentor
    msg = create_message(sender: members(:f_student), receiver: members(:f_mentor_student))
    assert_permission_denied do
      get :show, params: { id: msg.id}
    end
  end

  def test_show
    message = messages(:first_message)
    receiver = members(:f_mentor)
    assert message.unread?(receiver)
    filters_params = { search_filters: {
      sender: members(:f_mentor_student).name_with_email,
      receiver: receiver.name_with_email,
      status: { unread: 1 }
    } }

    current_member_is receiver
    get :show, params: { is_inbox: true, id: message.id, filters_params: filters_params }
    assert_response :success
    assert message.reload.read?(receiver)
    assert_equal message, assigns(:message)
    assert_equal messages_path( { tab: MessageConstants::Tabs::INBOX }.merge(filters_params)), assigns(:back_link)[:link]
    assert_select "div.cjs_preview_active", count: 1
  end

  def test_show_multiple_messages
    current_member_is :f_admin
    get :show, params: { id: messages(:third_admin_message).id}
    assert_select ".cjs_preview_active", count: 2
  end

  def test_show_deleted_message
    current_member_is :f_mentor
    messages(:first_message).mark_deleted!(members(:f_mentor))
    assert_permission_denied do
      get :show, params: { id: messages(:first_message).id}
    end
  end

  def test_show_to_sender
    assert messages(:first_message).unread?(members(:f_mentor))

    current_member_is :f_mentor_student
    get :show, params: { id: messages(:first_message).id}
    assert_response :success
    assert messages(:first_message).reload.unread?(members(:f_mentor))
    assert_equal messages(:first_message), assigns(:message)
    assert_select "div.cjs_preview_active", count: 1
  end

  def test_show_reply
    current_member_is :f_mentor_student
    m1 = create_message_reply(messages(:first_message))
    assert_equal messages(:first_message), m1.root
    assert m1.unread?(members(:f_mentor_student))

    get :show, params: { id: m1.id}
    assert_response :success
    assert_false assigns(:inbox)
    assert m1.reload.read?(members(:f_mentor_student))
    assert_equal m1, assigns(:message)
    get :show, params: { id: m1.id, is_inbox: 'true'}
    assert assigns(:inbox)
  end

  def test_show_redirect_to_scrap_path_for_scrap
    current_member_is :f_mentor
    group = groups(:mygroup)
    scrap = create_scrap(group: group, sender: members(:f_mentor))
    get :show, params: { id: scrap.id}
    assert_redirected_to scrap_path(from_inbox: true, root: group.program.root)
  end

  def test_destroy
    m1 = create_message_reply(messages(:first_message))
    assert_equal_unordered [messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2), messages(:meeting_scrap)], members(:f_mentor).received_messages
    current_member_is :f_mentor
    assert_no_difference "Message.count" do
      post :destroy, params: { id: messages(:first_message).id}
    end
    assert messages(:first_message).reload.deleted?(members(:f_mentor))
    assert_equal_unordered [messages(:mygroup_student_1), messages(:mygroup_student_2), messages(:meeting_scrap)], members(:f_mentor).reload.received_messages
    assert_redirected_to message_path(messages(:first_message))
    assert_equal "The message has been deleted", flash[:notice]
  end

  def test_destroy_by_sender
    current_member_is :f_student
    assert_permission_denied do
      post :destroy, params: { id: messages(:first_message).id}
    end
  end

  def test_dormant_members_can_see_inbox
    current_member_is :dormant_member
    get :index
    assert_response :success
  end
end
