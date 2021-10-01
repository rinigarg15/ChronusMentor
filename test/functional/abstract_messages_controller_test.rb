require_relative "./../test_helper.rb"

class AbstractMessagesControllerTest < ActionController::TestCase
  def test_show_receivers
    current_member_is :f_mentor
    get :show_receivers, xhr: true, params: { id: messages(:first_message).id}
    assert_response :success
    assert_equal messages(:first_message), assigns(:message)
  end

  def test_show_receivers_for_admin_message
    current_member_is :ram
    get :show_receivers, xhr: true, params: { id: messages(:first_admin_message).id}
    assert_response :success
    assert_equal messages(:first_admin_message), assigns(:message)
  end

  def test_show_receivers_permission_denied
    current_member_is :f_admin
    assert_permission_denied do
      get :show_receivers, xhr: true, params: { id: messages(:first_message).id}
    end
  end

  def test_show_detailed_scrap_for_sender
    scrap = messages(:mygroup_student_1)
    current_user_is :mkr_student
    get :show_detailed, xhr: true, params: { id: scrap.id }
    assert_response :success
    assert response.body.match /reply_link/
    # No delete link for the sent message
    assert_false response.body.match /delete_link/
  end

  def test_show_detailed_scrap_for_receiver
    scrap = messages(:mygroup_student_1)
    current_user_is :f_mentor
    get :show_detailed, xhr: true, params: { id: scrap.id, from_inbox: "true" }
    assert assigns("from_inbox")
    assert_response :success
    assert response.body.match /reply_link/
    assert response.body.match /delete_link/
    assert_match /<a [^<]*data-method=\\\"delete\\\"[^<]*href[^>]*scraps\/#{scrap.id}[^<]*>.*Delete<\\\/a>/, response.body
  end

  def test_show_detailed_scrap_when_group_deleted
    scrap = messages(:mygroup_student_1)
    scrap.update_attribute(:ref_obj_id, nil)

    current_user_is :f_mentor
    get :show_detailed, xhr: true, params: { id: messages(:mygroup_student_1).id }
    assert_response :success
    # No reply link for deleted group scraps
    assert_false response.body.match /reply_link/
    assert response.body.match /delete_link/
  end

  def test_show_detailed_scrap_for_suspended_user
    scrap = messages(:mygroup_student_1)
    mentor = users(:f_mentor)
    current_user_is mentor
    mentor.update_attribute :state, User::Status::SUSPENDED
    get :show_detailed, xhr: true, params: { id: messages(:mygroup_student_1).id }
    assert_response :success
    # No reply link for suspended users 
    assert_false response.body.match /reply_link/
    assert response.body.match /delete_link/
  end

  def test_show_detailed_messages_receiver_show
    current_member_is :f_mentor
    get :show_detailed, xhr: true, params: { id: messages(:first_message).id }
    assert_equal messages(:first_message), assigns(:message)
    assert response.body.match /reply_link/
    assert response.body.match /delete_link/
    assert_match /<a [^<]*data-method=\\\"delete\\\"[^<]*href[^>]*messages\/#{messages(:first_message).id}[^<]*>.*Delete<\\\/a>/, response.body
  end

  def test_show_detailed_messages_sender_show
    current_member_is :f_mentor_student
    get :show_detailed, xhr: true, params: { id: messages(:first_message).id }
    assert_equal messages(:first_message), assigns(:message)
    assert response.body.match /reply_link/
    assert_false response.body.match /delete_link/
  end

  def test_show_detailed_admin_messages_show
    # Make the messages as replies to another to test threaded msgs
    messages(:second_admin_message).update_attribute(:parent_id, messages(:first_admin_message).id)
    messages(:third_admin_message).update_attribute(:parent_id, messages(:second_admin_message).id)

    current_user_is :f_student
    get :show_detailed, xhr: true, params: { id: messages(:third_admin_message).id }
    assert_response :success
    # Assert threaded message
    assert response.body.match /(.*)#{messages(:third_admin_message).content}(.*)#{messages(:second_admin_message).content}(.*)#{messages(:first_admin_message).content}(.*)/m
    assert response.body.match /reply_link/
    assert_match /<a[^>]*data-method=\\\"delete\\\"[^>]*href[^>]*admin_messages\/#{messages(:third_admin_message).id}[^<]*>.*Delete<\\\/a>/, response.body
    assert response.body.match /new_admin_message/
  end

  def test_show_collapsed_messages
    message = messages(:first_message)
    receiver = message.receivers.first
    current_member_is receiver
    # create more messages to test collapsed messages
    10.times { create_message_reply(message) }
    message.reload.root.tree.each {|msg| msg.mark_as_read!(receiver)}
    # All the read messages except the first and last two will be collapsed.
    collapsed_messages = message.root.tree[1...-2]
    collapsed_message_ids = collapsed_messages.collect(&:id)
    get :show_collapsed, xhr: true, params: { id: message.id , collapsed_message_ids: collapsed_message_ids }
    assert_response :success
    assert_equal collapsed_messages, assigns(:messages_collection)
  end
end