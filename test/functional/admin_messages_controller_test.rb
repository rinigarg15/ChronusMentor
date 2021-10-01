require_relative './../test_helper.rb'

class AdminMessagesControllerTest < ActionController::TestCase

  def test_new_msg_to_group
    setup_ongoing_mentoring_enabled
    current_user_is :f_admin
    group = groups(:mygroup)
    get :new, xhr: true, params: { :recepient_group_id => group.id, :for_groups => "true"}
    assert_equal group, assigns(:connection)
    assert assigns(:for_groups)
    assert_ckeditor_rendered
    assert_select "input#admin_message_connection_ids[type=\"hidden\"][value=\"#{group.id.to_s}\"]"
    assert_select "input#admin_message_subject"
    assert_select "textarea#admin_message_content"
  end

  def test_new_message_to_admin_for_extension
    current_user_is users(:f_student)
    group = groups(:mygroup)
    get :new, xhr: true, params: { group_id: group.id, req_change_expiry: true}
    assert_false assigns(:is_admin_compose)
    assert assigns(:hide_contact_admin)
    assert_equal group, assigns(:connection)
    assert_select "input#admin_message_subject"
    assert_select "textarea#admin_message_content"
  end

  def test_new_with_no_current_user_with_new_sanitization_version
    current_program_is :albers
    organization = programs(:albers).organization
    organization.security_setting.sanitization_version = ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V2
    organization.save!
    get :new
    assert_nil assigns(:admin_message).sender_email
    assert_nil assigns(:admin_message).sender_name
    assert_nil assigns(:admin_message).sender_id
    assert_false assigns(:is_admin_compose)
    assert_template 'new'
    assert_no_select "input#admin_message_parent_id [type=\"hidden\"]"
    assert_select "input#admin_message_sender_name"
    assert_select "input#test-email"
    assert_no_select "input#admin_message_attachment"
  end

  def test_new_with_no_current_user_with_old_sanitization_version
    current_program_is :albers
    organization = programs(:albers).organization
    organization.security_setting.sanitization_version = ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V1
    organization.save!
    get :new
    assert_nil assigns(:admin_message).sender_email
    assert_nil assigns(:admin_message).sender_name
    assert_nil assigns(:admin_message).sender_id
    assert_false assigns(:is_admin_compose)
    assert_template 'new'
    assert_no_select "input#admin_message_parent_id [type=\"hidden\"]"
    assert_select "input#admin_message_sender_name"
    assert_select "input#test-email"
    assert_select "input#admin_message_attachment"
  end

  def test_new_with_current_user
    current_user_is users(:f_student)
    get :new
    assert_response :success
    assert_template 'new'
    assert_equal programs(:albers), assigns(:admin_message).program
    assert_tab TabConstants::HOME
    assert_page_title("Send Message to Administrator")
    assert_false assigns(:is_admin_compose)
    assert_ckeditor_not_rendered
    assert_no_select "input#admin_message_sender_name [type=\"hidden\"]"
    assert_no_select "input#admin_message_sender_email [type=\"hidden\"]"
  end

  def test_new_message_for_group_feedback
    current_user_is users(:f_student)
    get :new, params: { :group_id => 1}
    assert_response :success
    assert_template 'new'
    assert assigns(:admin_message).subject.nil?
    assert_false assigns(:is_admin_compose)
    assert_select("input#admin_message_group_id[type=hidden][value='1']")
    assert_page_title('Send Message to Administrator')
  end

  def test_new_admin_compose
    setup_admin_custom_term
    current_user_is users(:f_admin)
    get :new
    assert_response :success
    assert_template 'new'
    assert_equal programs(:albers), assigns(:admin_message).program
    assert_tab TabConstants::MANAGE
    assert_page_title("New Message from Super Admin")
    assert_equal AdminMessagesController::ComposeType::MEMBERS, assigns(:compose_type)
    assert assigns(:is_admin_compose)
    assert_ckeditor_rendered
    assert_no_select "input#admin_message_sender_name [type=\"hidden\"]"
    assert_no_select "input#admin_message_sender_email [type=\"hidden\"]"
  end

  def test_new_admin_compose_for_connections
    setup_admin_custom_term
    setup_ongoing_mentoring_enabled
    current_user_is users(:f_admin)
    get :new, params: { :for_groups => "true"}
    assert_response :success
    assert_template 'new'
    assert_equal programs(:albers), assigns(:admin_message).program
    assert_tab TabConstants::MANAGE
    assert_page_title("New Message from Super Admin")
    assert_equal AdminMessagesController::ComposeType::CONNECTIONS, assigns(:compose_type)
    assert assigns(:is_admin_compose)
    assert_nil assigns(:group)
    assert_nil assigns(:for_groups)
    assert_no_select "input#admin_message_sender_name [type=\"hidden\"]"
    assert_no_select "input#admin_message_sender_email [type=\"hidden\"]"
  end

  def test_new_admin_compose_for_one_connection
    setup_admin_custom_term
    setup_ongoing_mentoring_enabled
    current_user_is users(:f_admin)
    get :new, params: { :for_groups => "true", :recepient_group_id => "#{groups(:mygroup).id}"}
    assert_response :success
    assert_template 'new'
    assert_equal programs(:albers), assigns(:admin_message).program
    assert_tab TabConstants::MANAGE
    assert_page_title("New Message from Super Admin")
    assert_equal AdminMessagesController::ComposeType::CONNECTIONS, assigns(:compose_type)
    assert_equal groups(:mygroup), assigns(:group)
    assert assigns(:is_admin_compose)
    assert_no_select "input#admin_message_sender_name [type=\"hidden\"]"
    assert_no_select "input#admin_message_sender_email [type=\"hidden\"]"
  end

  def test_new_admin_view_bulk_action_permission_denied
    current_user_is :f_student
    assert_permission_denied do
      post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:users => ["1", "2", "3"]}}
    end
  end

  def test_new_admin_view_bulk_action
    current_user_is :f_admin
    post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:users => ["1", "2", "3"]}}
    assert_response :success
    assert_equal_unordered [1, 2, 3], assigns(:selected_users).collect(&:id)
    assert_equal true, assigns(:is_a_bulk_action)
    assert_select "input[type=\"hidden\"][value=\"#{assigns(:selected_users).collect(&:member_id).join(",")}\"]"
  end

  def test_new_admin_view_bulk_action_for_not_responded_users_program_event
    current_user_is :f_admin

    event = program_events(:birthday_party)
    tab = ProgramEventConstants::ResponseTabs::NOT_RESPONDED
    users = event.users_by_status(tab)

    post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:event => {event_id: 1 ,tab: tab}}}
    assert_response :success
    assert_equal event, assigns(:program_event)
    assert_equal true, assigns(:is_a_bulk_action)
    assert_equal ProgramEventConstants::ResponseTabs::NOT_RESPONDED, assigns(:tab).to_i
    assert_equal_unordered users.where("users.state != ?", User::Status::SUSPENDED).collect(&:member_id) , assigns(:receiver_member_ids)
    assert_equal_unordered users, assigns(:all_receiver_users)
  end

  def test_new_admin_view_bulk_action_for_attending_users_program_event
    event = program_events(:birthday_party)
    users = event.event_invites.where(:status => EventInvite::Status::YES).collect(&:user)

    current_user_is :f_admin
    post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:event => {event_id: 1 ,tab: ProgramEventConstants::ResponseTabs::ATTENDING, user_ids: users.collect(&:id)}}}
    assert_response :success
    assert_select "input#includes_suspended"
    assert_equal event, assigns(:program_event)
    assert_equal true, assigns(:is_a_bulk_action)
    assert_equal ProgramEventConstants::ResponseTabs::ATTENDING, assigns(:tab).to_i
    assert_equal_unordered users.collect(&:member_id), assigns(:receiver_member_ids)
  end

  def test_contact_admin_form_organization_level_non_logged_in_user
    current_organization_is programs(:org_primary)
    assert_permission_denied do
      get :new
    end
  end

  def test_contact_admin_form_organization_level_logged_in_user
    current_member_is members(:f_student)
    get :new
    assert_response :success
  end  

  def test_contact_admin_form_program_level_non_logged_in_user
    current_program_is programs(:albers)
    get :new
    assert_response :success
  end

  def test_contact_admin_form_program_level_logged_in_user
    current_user_is users(:f_student)
    get :new
    assert_response :success
  end

  def test_new_group_bulk_action_send_message
    setup_ongoing_mentoring_enabled
    current_user_is users(:f_admin)

    post :new_bulk_admin_message, xhr: true, params: { :for_groups => "true", :bulk_action => {:group_ids => [groups(:mygroup).id]}}
    assert_response :success
    assert_equal [groups(:mygroup)], assigns(:selected_groups)
    assert_false assigns(:is_a_bulk_action)
    assert assigns(:for_groups)
    assert assigns(:is_groups_bulk_action)
  end

  def test_new_group_bulk_action_send_message_membership_requests
    current_user_is users(:f_admin)

    post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:members => [members(:f_student).id, members(:f_mentor).id]}, src: MembershipRequest.name}
    assert_response :success
    assert_no_select "input#includes_suspended"
    assert_equal "MembershipRequest", assigns(:src)
    assert_equal [members(:f_student), members(:f_mentor)], assigns(:selected_members)
    assert_equal [members(:f_student).id, members(:f_mentor).id], assigns(:receiver_member_ids)
    assert assigns(:is_a_bulk_action)
    assert_false assigns(:for_groups)
    assert_false assigns(:is_groups_bulk_action)
  end

  def test_new_admin_view_bulk_action_at_org_level
    current_member_is :f_admin

    post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:members => ["1", "2", "3"]}}
    assert_response :success
    assert_equal_unordered [1, 2, 3], assigns(:selected_members).collect(&:id)
    assert_equal true, assigns(:is_a_bulk_action)
    assert_select "input[type=\"hidden\"][value=\"#{assigns(:selected_members).collect(&:id).join(",")}\"]"
  end

  def test_create_admin_message_for_mentor_feedback
    g = groups(:mygroup)
    current_user_is users(:mkr_student)
    post :create, params: { :admin_message => {:group_id => g.id, :subject => "anbd", :content => "Qiicr", :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}}
    assert_response :redirect
    msg = AdminMessage.last
    assert_equal "test_pic.png", msg.attachment_file_name
    assert_equal g, msg.group
    assert_equal members(:mkr_student), msg.sender
  end

  def test_create_admin_message_with_empty_subject
    current_user_is users(:f_student)
    assert_no_difference('AdminMessage.count') do
      post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => ''}}
    end
    assert_response :success
    assert_template 'new'
    assert_match(/can't be blank/, assigns(:admin_message).errors[:subject].join)
    assert_page_title("Send Message to Administrator")
  end

  def test_create_admin_message_with_invalid_file_type
    current_user_is users(:f_student)
    assert_no_difference('AdminMessage.count') do
      post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'TEST', :attachment => fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php') }}
    end
    assert_response :success
    assert_template 'new'
    assert_equal flash[:error], "Attachment content type is restricted and Attachment file name is invalid"
    assert_page_title("Send Message to Administrator")
  end

  def test_create_admin_message_to_admin
    current_user_is users(:f_student)
    assert_emails 2 do
      assert_difference('AdminMessage.count') do
        post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'This is a Subject', :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}}
      end
    end
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal "test_pic.png", AdminMessage.last.attachment_file_name
    assert_equal "Your message has been sent to Administrator.", flash[:notice]
  end

  def test_create_admin_message_for_resource_marked_not_helpful
    programs(:albers).enable_feature(FeatureName::RESOURCES, true)
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    setup_admin_custom_term
    res = create_resource(:programs => {programs(:albers) => [m1]})

    current_user_is users(:f_mentor)
    post :create, params: { :admin_message => {:content=>"sder", :resource_mail_subject=>"Resource res is marked not helpful", :resource_id =>res.id}}
    msg = AdminMessage.last
    assert_equal "Resource res is marked not helpful", msg.subject
    assert_equal res, assigns(:resource)

    assert_equal "Your message has been sent to Super Admin.", assigns(:success_flash)
    assert_equal "Your message has been sent to Super Admin.", flash[:notice]
  end

  def test_create_admin_message_for_resource_have_a_question
    programs(:albers).enable_feature(FeatureName::RESOURCES, true)
    m1 = programs(:albers).get_role(RoleConstants::MENTOR_NAME).id
    setup_admin_custom_term
    res = create_resource(:programs => {programs(:albers) => [m1]})

    current_user_is users(:f_mentor)
    post :create, params: { :admin_message => {:content=>"sder", :resource_mail_subject=>"Question regarding the resource res"}}
    msg = AdminMessage.last
    assert_equal "Question regarding the resource res", msg.subject
    assert_nil assigns(:resource)
    assert_equal "Your question has been sent to Super Admin.", assigns(:success_flash)
    assert_equal "Your question has been sent to Super Admin.", flash[:notice]
  end

  def test_create_admin_message_to_admin_with_limit_exceeded
    programs(:albers).admin_messages.joins(:message_receivers).where(:abstract_message_receivers => {:member_id => nil}, :created_at => 1.hour.ago.utc..Time.now.utc, :sender_id => members(:f_student).id, :parent_id => nil, :auto_email => false).destroy_all
    current_user_is users(:f_student)
    10.times do |i|
      admin_message = AdminMessage.new(:sender => members(:f_student), :program => programs(:albers), :subject => "Subject", :content => 'Content')
      admin_message.message_receivers.build
      admin_message.save!
    end
    assert_no_emails do
      assert_no_difference('AdminMessage.count') do
        post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'This is a Subject', :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}}
      end
    end
    assert_response :success
    assert_template 'new'
    assert_equal flash[:error], "You have exceeded the maximum number of messages that can be sent to the administrators in an hour. Please try again later."
    assert_page_title("Send Message to Administrator")
  end

  def test_create_admin_message_from_unloggedin_user
    captcha = NegativeCaptcha.new(:secret => '', :fields => [:email], :spinner => "0.0.0.0")
    current_program_is :albers
    org = programs(:albers).organization
    org.security_setting.sanitization_version = "v1"
    org.save!
    assert_emails 2 do
      assert_difference('AdminMessage.count') do
        post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'This is a Subject',
          :sender_name => "Test", :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}, :"test-email" => "test@example.com", :email => "", :timestamp => captcha.timestamp, :spinner => captcha.spinner
        }
      end
    end
    msg = AdminMessage.last
    assert_equal "Test", msg.sender_name
    assert_equal "test@example.com", msg.sender_email
    assert_equal "test_pic.png", msg.attachment_file_name
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal "Your message has been sent to Administrator.", flash[:notice]
  end

  def test_create_admin_message_from_unloggedin_user_fails_for_negative_captcha
    captcha = NegativeCaptcha.new(:secret => '', :fields => [:email], :spinner => "0.0.0.0")
    current_program_is :albers
    org = programs(:albers).organization
    org.security_setting.sanitization_version = "v1"
    org.save!
    assert_emails 0 do
      assert_no_difference('AdminMessage.count') do
        post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'This is a Subject',
          :sender_name => "Test", :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}, :"test-email" => "test@example.com", :email => "test@example.com", :timestamp => captcha.timestamp, :spinner => captcha.spinner
        }
      end
    end
    assert_redirected_to program_root_path
  end

  def test_create_admin_message_from_unloggedin_user_sanitization_version_v2
    captcha = NegativeCaptcha.new(:secret => '', :fields => [:email], :spinner => "0.0.0.0")
    current_program_is :albers
    org = programs(:albers).organization
    org.security_setting.sanitization_version = "v2"
    org.save!
    assert_emails 2 do
      assert_difference('AdminMessage.count') do
        post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'This is a Subject',
          :sender_name => "Test", :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}, :"test-email" => "test@example.com", :email => "", :timestamp => captcha.timestamp, :spinner => captcha.spinner
        }
      end
    end
    msg = AdminMessage.last
    assert_equal "Test", msg.sender_name
    assert_equal "test@example.com", msg.sender_email
    assert_nil msg.attachment_file_name
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal "Your message has been sent to Administrator.", flash[:notice]
  end

  def test_create_admin_message_from_unloggedin_user_with_whitespace_in_email
    captcha = NegativeCaptcha.new(:secret => '', :fields => [:email], :spinner => "0.0.0.0")
    current_program_is :albers
    assert_emails 2 do
      assert_difference('AdminMessage.count') do
        post :create, params: { :admin_message => {:content => 'This is the message I want to send. ', :subject => 'This is a Subject',
          :sender_name => "Test"}, :"test-email" => "test@example.com  ",  :email => "", :timestamp => captcha.timestamp, :spinner => captcha.spinner
        }
      end
    end
    msg = AdminMessage.last
    assert_equal "Test", msg.sender_name
    assert_equal "test@example.com", msg.sender_email
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal "Your message has been sent to Administrator.", flash[:notice]
  end

  def test_create_reply_by_admin_when_user_is_not_logged_in
    current_program_is :albers
    assert_permission_denied do
      post :create, params: { :admin_message => {:subject => "Test", :parent_id => messages(:first_admin_message).id}}
    end
  end

  def test_create_reply_failure
    current_user_is :f_admin
    assert_no_difference "AdminMessage.count" do
      post :create, params: { :admin_message => {:parent_id => messages(:first_admin_message).id}}
    end
    assert_redirected_to admin_message_path(messages(:first_admin_message))
  end

  def test_create_failure_compose
    setup_admin_custom_term
    current_user_is :f_admin
    assert_no_difference "AdminMessage.count" do
      post :create, params: { :admin_message => {:subject => "Test", :receiver_ids => "#{members(:f_student).id},#{members(:f_mentor).id}"}}
    end
    assert_response :success
    assert_template "new"
    assert_equal members(:f_admin), assigns(:admin_message).sender
    assert_equal [members(:f_student), members(:f_mentor)], assigns(:admin_message).receivers
    assert_equal programs(:albers), assigns(:admin_message).program
    assert_equal "Test", assigns(:admin_message).subject
    assert_tab TabConstants::MANAGE
    assert_page_title("New Message from Super Admin")
    assert_equal AdminMessagesController::ComposeType::MEMBERS, assigns(:compose_type)
  end

  def test_create_should_not_allow_non_admin_to_message_users
    current_user_is :f_mentor
    assert_permission_denied do
      assert_no_difference "AdminMessage.count" do
        post :create, params: { :admin_message => {:subject => "Test", :receiver_ids => "#{members(:f_student).id},#{members(:f_mentor).id}"}}
      end
    end
  end

  def test_create_reply_by_non_admin
    current_user_is :f_student
    assert_emails 2 do
      assert_difference "AdminMessage.count" do
        post :create, params: { admin_message: { content: "Content", parent_id: messages(:third_admin_message).id }, from_inbox: true}
      end
    end
    m = AdminMessage.last
    assert_redirected_to admin_message_path(m, is_inbox: true, reply: true, from_inbox: true)
    assert_equal members(:f_student), m.sender
    assert m.receivers.empty?
    assert_equal messages(:third_admin_message), assigns(:admin_message).parent
    assert_equal programs(:albers), m.program
    assert_equal "Your message has been sent to Administrator.", flash[:notice]
    assert_equal messages(:third_admin_message).subject, m.subject
    assert_equal "Content", m.content
  end

  def test_create_reply_to_program_level_admin_message_by_non_admin_deactivated_user
    current_user_is :f_student
    users(:f_student).update_attribute(:state, User::Status::SUSPENDED)
    message = messages(:third_admin_message)
    assert message.program.is_a?(Program)
    assert_emails 2 do
      assert_difference "AdminMessage.count" do
        post :create, params: { admin_message: { content: "Content", parent_id: message.id }, from_inbox: true}
      end
    end
    m = AdminMessage.last
    assert_redirected_to admin_message_path(m, is_inbox: true, reply: true, from_inbox: true)
    assert_equal members(:f_student), m.sender
    assert m.receivers.empty?
    assert_equal messages(:third_admin_message), assigns(:admin_message).parent
    assert_equal programs(:albers), m.program
    assert_equal "Your message has been sent to Administrator.", flash[:notice]
    assert_equal messages(:third_admin_message).subject, m.subject
    assert_equal "Content", m.content
  end

  def test_create_reply_by_admin
    current_user_is :ram
    assert_emails 1 do
      assert_difference "AdminMessage.count" do
        post :create, params: { :admin_message => {:content => "Content", :parent_id => messages(:first_admin_message).id,
                      :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
                    }
      end
    end
    m = AdminMessage.last
    assert_redirected_to admin_message_path(m, is_inbox: true, reply: true)
    assert_equal members(:ram), m.sender
    assert_equal [members(:f_student)], m.receivers
    assert_equal messages(:first_admin_message), assigns(:admin_message).parent
    assert_equal programs(:albers), m.program
    assert_equal "test_pic.png", m.attachment_file_name
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal messages(:first_admin_message).subject, m.subject
    assert_equal "Content", m.content
  end

  def test_create_from_compose
    current_user_is :ram
    assert_emails 2 do
      assert_difference "AdminMessage.count" do
        assert_difference "AdminMessages::Receiver.count", 2 do
          post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :receiver_ids => "#{members(:f_student).id},#{members(:f_mentor).id}",
            :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
          }
        end
      end
    end
    m = AdminMessage.last
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal members(:ram), m.sender
    assert_equal [members(:f_student), members(:f_mentor)], m.receivers
    assert_equal programs(:albers), m.program
    assert_equal "test_pic.png", m.attachment_file_name
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal "Test", m.subject
    assert_equal "Content", m.content
  end

  def test_create_from_compose_for_connections
    setup_ongoing_mentoring_enabled
    current_user_is :ram

    members = groups(:mygroup).members.collect(&:member) + groups(:group_2).members.collect(&:member)
    connection_ids = [groups(:mygroup), groups(:group_2), groups(:multi_group)].collect(&:id).join(",")

    current_user_is :ram
    assert_emails members.size do
      assert_difference "AdminMessage.count" do
        assert_difference "AdminMessages::Receiver.count", members.size do
          post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :connection_ids => connection_ids,
                                          :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
                                        }
        end
      end
    end
    m = AdminMessage.last
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal members(:ram), m.sender
    assert_equal_unordered members, m.receivers
    assert_equal programs(:albers), m.program
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal "Test", m.subject
    assert_equal "Content", m.content
    assert_equal "test_pic.png", m.attachment_file_name
  end

  def test_create_from_compose_for_connections_when_ongoing_mentoring_disabled
    current_user_is :ram
    program = programs(:albers)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    members = groups(:mygroup).members.collect(&:member) + groups(:group_2).members.collect(&:member)
    connection_ids = [groups(:mygroup), groups(:group_2), groups(:multi_group)].collect(&:id).join(",")
    assert_permission_denied do
      post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :connection_ids => connection_ids,
                                          :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
                                        }
    end
  end

  def test_create_from_reply_to_non_loggedin_user
    current_user_is :ram
    assert_emails 1 do
      assert_difference "AdminMessage.count" do
        post :create, params: { :admin_message => {:content => "Qiicr", :parent_id => messages(:second_admin_message).id,
          :attachment =>  fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}
        }
      end
    end
    m = AdminMessage.last
    assert_redirected_to admin_message_path(m, is_inbox: true, reply: true)
    assert_equal members(:ram), m.sender
    assert m.receivers.empty?
    assert_equal messages(:second_admin_message).sender_name, m.offline_receiver.name
    assert_equal messages(:second_admin_message).sender_email, m.offline_receiver.email
    assert_equal messages(:second_admin_message), m.parent
    assert_equal programs(:albers), m.program
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal messages(:second_admin_message).subject, m.subject
    assert_equal "Qiicr", m.content
    assert_equal "test_pic.png", m.attachment_file_name
  end

  def test_create_reply_by_another_admin
    parent_message = messages(:third_admin_message)
    current_user_is :ram
    assert_difference "AdminMessage.count" do
      post :create, params: { admin_message: { content: "a", parent_id: parent_message.id }}
    end
    m = AdminMessage.last
    assert parent_message.receivers, m.receivers
  end

  def test_new_admin_view_bulk_action_should_deny_for_student_role
    current_user_is :f_student

    assert_permission_denied do
      post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:users => ["1", "2", "3"]}}
    end
  end

  def test_admin_message_create_for_individual_group
    setup_ongoing_mentoring_enabled
    current_user_is :f_admin
    post :create, xhr: true, params: { :admin_message => {:connection_ids => groups(:mygroup).id}}
    assert_response :success
  end

  def test_admin_message_create_for_bulk_groups
    setup_ongoing_mentoring_enabled
    current_user_is :f_admin
    assert_difference "AdminMessage.count" do
      assert_difference "AdminMessages::Receiver.count", 2 do
        post :create, xhr: true, params: { :admin_message => {subject: "Test", content: "Content", connection_ids: groups(:mygroup).id, connection_send_message_type_or_role: Connection::Membership::SendMessage::ALL, :bulk_action_groups => "true"}}
      end
    end
    assert_response :success
    assert_nil assigns(:group_id)

    assert_difference "AdminMessage.count" do
      assert_difference "AdminMessages::Receiver.count", 1 do
        post :create, xhr: true, params: { :admin_message => {subject: "Test", content: "Content", connection_ids: groups(:mygroup).id, connection_send_message_type_or_role: RoleConstants::MENTOR_NAME, :bulk_action_groups => "true"}}
      end
    end
    assert_response :success
    assert_nil assigns(:group_id)
  end

  def test_bulk_action_create_with_empty_receivers
    current_user_is :f_admin
    post :create, params: { admin_message: { subject: "Test", content: "Content", receiver_ids: "" }, bulk_action: true }
    assert_redirected_to program_root_path
  end

  def test_bulk_action_create_to_suspended_users
    current_user_is :psg_only_admin
    suspended_user = users(:psg_mentor2)
    assert_emails 1 do
      assert_difference "AdminMessage.count" do
        assert_difference "AdminMessages::Receiver.count", 1 do
          post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :receiver_ids => "", :user_or_member_ids => "#{suspended_user.id}"}, :includes_suspended => true}
        end
      end
    end
    m = AdminMessage.last
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal members(:psg_only_admin), m.sender
    assert_equal [suspended_user.member], m.receivers
    assert_equal programs(:psg), m.program
    assert_equal "Your message has been sent", flash[:notice]
    assert_equal "Test", m.subject
    assert_equal "Content", m.content
  end

  def test_bulk_action_create_to_suspended_and_active_users
    current_user_is :psg_only_admin
    suspended_user = users(:psg_mentor2)
    assert_emails 2 do
      assert_difference "AdminMessage.count" do
        assert_difference "AdminMessages::Receiver.count", 2 do
          post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :receiver_ids => "#{users(:psg_student1).id}", :user_or_member_ids => "#{suspended_user.id},#{users(:psg_student1).id}"}, :includes_suspended => true}
        end
      end
    end
    m = AdminMessage.last
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal [members(:psg_student1), suspended_user.member], m.receivers
    assert_equal "Your message has been sent", flash[:notice]
  end

  def test_bulk_action_create_to_suspended_users_without_includes_suspended_option
    current_user_is :psg_only_admin
    suspended_user = users(:psg_mentor2)
    assert_no_emails do
      assert_no_difference "AdminMessage.count" do
        assert_no_difference "AdminMessages::Receiver.count" do
          post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :receiver_ids => "", :user_or_member_ids => "#{suspended_user.id}"}}
        end
      end
    end
    assert_equal "Please select at least one user", assigns(:error_flash)
    assert_equal "Please select at least one user", flash[:error]
    assert_redirected_to program_root_path
  end

  def test_bulk_action_create_should_not_send_to_suspended_if_checkbox_is_unchecked
    current_user_is :psg_only_admin
    suspended_user = users(:psg_mentor2)
    assert_emails 1 do
      assert_difference "AdminMessage.count" do
        assert_difference "AdminMessages::Receiver.count", 1 do
          post :create, params: { :admin_message => {:subject => "Test", :content => "Content", :receiver_ids => "#{users(:psg_student1).id}", :user_or_member_ids => "#{suspended_user.id},#{users(:psg_student1).id}"}}
        end
      end
    end
    m = AdminMessage.last
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    assert_equal [members(:psg_student1)], m.receivers
    assert_equal "Your message has been sent", flash[:notice]
  end

  def test_new_admin_message_create_at_org_level
    current_member_is :f_admin
    assert_emails 3 do
      assert_difference "AdminMessage.count" do
        post :create, params: { :admin_message => {:receiver_ids => "1,2,3", :subject => "sample subject", :content => "sample content"}, :bulk_action => true}
      end
    end
    assert_redirected_to program_root_path(ProgramsController::RETAIN_FLASH => true)
    admin_message = AdminMessage.last
    assert_equal programs(:org_primary), admin_message.program
    assert_equal "sample subject", admin_message.subject
    assert_equal "sample content", admin_message.content
    assert_equal_unordered [1,2,3], admin_message.receivers.collect(&:id)
  end

  def test_index_auth
    current_user_is :f_mentor
    assert_permission_denied do
      get :index
    end
  end

  def test_redirect_index_auth
    current_organization_is :org_primary
    get :index
    assert_redirected_to new_session_path
  end

  def test_index
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, []).returns(AbstractMessage.where(id: []).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    current_member_is :f_admin
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
    assert assigns(:messages_presenter)
    assert assigns(:messages_presenter).instance_of?(Messages::AdminMessagesPresenter)
    assert assigns(:my_filters)
  end

  def test_index_format
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(2, []).returns(AbstractMessage.where(id: []).paginate(page: 2, per_page: AbstractMessage::PER_PAGE)).once
    current_member_is :f_admin
    get :index, xhr: true, params: { format: :js, page: 2}
    assert_response :success
    presenter = assigns(:messages_presenter)
    assert_false presenter.fetch_data_for_all_tabs
  end

  def test_index_no_src
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, []).returns(AbstractMessage.where(id: []).paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    current_member_is :f_admin
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_show_received_message
    messages(:third_admin_message).offline_receiver.update_attribute :status, AbstractMessageReceiver::Status::UNREAD
    assert messages(:third_admin_message).unread?(members(:f_student))

    current_member_is :f_student
    get :show, params: { :id => messages(:third_admin_message).id}
    assert_response :success
    assert_template 'show'
    assert messages(:third_admin_message).reload.read?(members(:f_student))
  end

  def test_show_received_message_with_proper_formatiing
    admin_message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)])
    admin_message.update_attribute(:content, "<li>\r\ntest1</li><li>\r\ntest2</li>")
    current_member_is :f_student
    get :show, params: { id: admin_message.id}
    assert_response :success
    assert_match("<li>\r\ntest1</li><li>\r\ntest2</li>", response.body)
    assert_not_match(/<li>\r\n<br \/>test1<\/li><li>\r\n<br \/>test2<\/li>/, response.body)
  end

  def test_show_sent_message
    message = messages(:first_admin_message)
    sender = message.sender
    message.admin_receiver.update_attribute :status, AbstractMessageReceiver::Status::UNREAD
    filters_params = {
      include_system_generated: "",
      search_filters: { sender: sender.name_with_email }
    }

    current_program_is message.program
    current_member_is sender
    get :show, params: { id: message.id, filters_params: filters_params }
    assert_response :success
    assert_equal messages_path( { organization_level: true, tab: MessageConstants::Tabs::SENT }.merge(filters_params)), assigns(:back_link)[:link]
    assert message.reload.unread?(members(:f_admin))
  end

  def test_show_received_message_for_admin
    messages(:first_admin_message).admin_receiver.update_attribute :status, AbstractMessageReceiver::Status::UNREAD
    assert messages(:first_admin_message).reload.unread?(members(:f_admin))

    current_user_is :ram
    get :show, params: { :id => messages(:first_admin_message).id}
    assert_response :success
    assert_template 'show'
    assert messages(:first_admin_message).reload.read?(members(:f_admin))
  end

  def test_show_sent_message_for_admin
    messages(:third_admin_message).offline_receiver.update_attribute :status, AbstractMessageReceiver::Status::UNREAD
    assert messages(:third_admin_message).unread?(members(:f_student))

    current_user_is :ram
    get :show, params: { :id => messages(:third_admin_message).id}
    assert_response :success
    assert_template 'show'
    assert messages(:third_admin_message).reload.unread?(members(:f_student))
  end

  def test_show_sent_message_for_admin_should_redirect_if_current_program_not_set
    current_member_is :f_admin
    get :show, params: { :id => messages(:third_admin_message).id}
    assert_redirected_to admin_message_path(messages(:third_admin_message), :root => programs(:albers).root, :from_inbox => false, :is_inbox => false)
  end

  def test_show_deleted_message
    message = create_admin_message(sender: members(:f_student))
    message.mark_deleted!(members(:f_admin))

    current_user_is :f_admin
    assert_permission_denied do
      get :show, params: { :id => message.id}
    end
  end

  def test_destroy
    message1, message2 = messages(:first_admin_message), messages(:second_admin_message)
    assert_equal [message1.id, message2.id], programs(:albers).received_admin_message_ids.map(&:id)

    current_user_is :ram
    assert_no_difference "AdminMessage.count" do
      post :destroy, params: { :id => messages(:first_admin_message).id}
    end
    assert messages(:first_admin_message).reload.deleted?(members(:ram))
    assert_equal [message2.id], programs(:albers).reload.received_admin_message_ids.map(&:id)
    assert_redirected_to admin_message_path(messages(:first_admin_message))
    assert_equal "The message has been deleted", flash[:notice]
  end

  def test_destroy_by_non_admin_sender
    current_user_is :f_student
    assert_permission_denied do
      post :destroy, params: { :id => messages(:first_admin_message).id}
    end
  end

  def test_destroy_by_admin_sender
    current_user_is :ram
    assert_permission_denied do
      post :destroy, params: { :id => messages(:third_admin_message).id}
    end
  end

  def test_admin_messages_view_title
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    setup_admin_custom_term
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_page_title("Super Admin Inbox")
  end

  def test_admin_messages_if_ongoing_mentoring_enabled
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice

    current_user_is :f_admin
    program = programs(:albers)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program.reload


    get :index
    assert_response :success
    assert_select 'a.cui_send_message_to_connections'

    get :show, params: { :id => messages(:first_admin_message).id}
    assert_response :success
    assert_select 'a.cui_send_message_to_connections'
  end


  def test_admin_messages_if_ongoing_mentoring_disabled
    AbstractMessagesFilterService.any_instance.expects(:get_paginated_filtered_messages).with(1, [3, 4, 5, 6]).returns(AbstractMessage.where(id: [4, 3]).order("FIELD(id, 4,3)").paginate(page: 1, per_page: AbstractMessage::PER_PAGE)).twice
    setup_ongoing_mentoring_disabled

    get :index
    assert_response :success
    assert_no_select 'a.cui_send_message_to_connections'

    get :show, params: { :id => messages(:first_admin_message).id}
    assert_response :success
    assert_no_select 'a.cui_send_message_to_connections'
  end

  def test_admin_group_messages_if_ongoing_mentoring_disabled
    setup_ongoing_mentoring_disabled
    assert_permission_denied do
      get :new, xhr: true, params: { :for_groups => "true"}
    end
  end

  def test_new_admin_view_bulk_action_if_ongoing_mentoring_disabled
    setup_ongoing_mentoring_disabled

    assert_permission_denied do
      post :new_bulk_admin_message, xhr: true, params: { :bulk_action => {:users => ["1", "2", "3"]}, :for_groups => true}
    end
  end

  def test_create_admin_message_with_vulnerable_content_with_version_v2
    current_user_is users(:f_admin)
    assert_difference "VulnerableContentLog.count" do
      post :create, params: { admin_message: { receiver_ids: "#{members(:f_student).id}", subject: "anbd", content: "New Body <script>alert(10);</script>" }}
    end
    current_user_is users(:f_student)
    assert_no_difference "VulnerableContentLog.count" do
      post :create, params: { admin_message: { subject: "anbd", content: "New Body <script>alert(10);</script>" }}
    end
  end

  private

  def setup_ongoing_mentoring_enabled
    current_user_is :f_admin
    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program.reload
  end

  def setup_ongoing_mentoring_disabled
    current_user_is :f_admin
    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload
  end
end