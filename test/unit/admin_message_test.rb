require_relative "./../test_helper.rb"

class AdminMessageTest < ActiveSupport::TestCase

  def test_humanize_names
    assert_equal "Word verification", AdminMessage.human_attribute_name(:captcha)
  end

  def test_message_should_have_name__email__subject_and_content
    e = assert_raise(ActiveRecord::RecordInvalid) do
      AdminMessage.create!(program: programs(:albers))
    end

    assert_match(/email can't be blank/, e.message)
    assert_match(/name can't be blank/, e.message)
    assert_match(/Subject can't be blank/, e.message)
    assert_match(/Message can't be blank/, e.message)
    assert_match(/Receivers can't be blank/, e.message)

    e = assert_raise(ActiveRecord::RecordInvalid) do
      AdminMessage.create!(program: programs(:albers), auto_email: true)
    end

    assert_no_match(/email can't be blank/, e.message)
    assert_no_match(/name can't be blank/, e.message)
    assert_match(/Subject can't be blank/, e.message)
    assert_match(/Message can't be blank/, e.message)
    assert_match(/Receivers can't be blank/, e.message)
  end

  def test_belong_to_campaign_message
    a = AdminMessage.new(program: programs(:albers), sender_name: 'Test ', sender_email: "test@gmail.com", subject: 'Test', content: 'This is the content', campaign_message_id: cm_campaign_messages(:campaign_message_6).id)
    a.message_receivers = [AdminMessages::Receiver.new(message: a)]
    a.save!
    assert_equal [a], cm_campaign_messages(:campaign_message_6).emails
  end

  def test_admin_message_can_have_many_email_event_logs
    assert_equal 6, messages(:first_campaigns_admin_message).event_logs.size
    assert_difference "CampaignManagement::EmailEventLog.count", -6 do
      messages(:first_campaigns_admin_message).destroy
    end
  end

  def test_should_not_create_a_request_with_bad_sender_email
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender_email do
      AdminMessage.create!(program: programs(:albers), sender_name: 'Srini', sender_email: 'good', subject: 'Test', content: 'This is the content')
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender_email do
      AdminMessage.create!(program: programs(:albers), sender_name: 'Srini', sender_email: '.good@abc.com', subject: 'Test', content: 'This is the content')
    end
  end

  def test_should_create_a_request_with_sender_email_containing_apostrophe
    assert_difference('AdminMessage.count') do
      a = AdminMessage.new(program: programs(:albers), sender_name: 'Srini', sender_email: "g_o'od@gmail.com", subject: 'Test', content: 'This is the content')
      a.message_receivers = [AdminMessages::Receiver.new(message: a)]
      a.save!
    end
  end

  def test_should_not_create_a_request_with_no_sender_and_no_sender_name_email
    e = assert_raise(ActiveRecord::RecordInvalid) do
      AdminMessage.create!(program: programs(:albers),subject: 'Test', content: 'This is the content')
    end
    assert_match(/email can't be blank/, e.message)
    assert_match(/name can't be blank/, e.message)
  end

  def test_should_not_create_a_request_with_no_sender_name
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender_name do
      AdminMessage.create!(program: programs(:albers), sender_email: 'good@chronus.com', subject: 'Test', content: 'Content')
    end
  end

  def test_should_not_allow_non_admin_to_message_end_users
    member = members(:f_mentor)
    program = programs(:albers)
    assert_false member.admin?
    assert_false member.user_in_program(program).is_admin?

    # Registered user
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender do
      a = AdminMessage.new(program: program, sender: member, subject: "Test", content: "Content")
      a.receiver_ids = "#{members(:f_student).id}"
      a.save!
    end

    # Offline user
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender do
      a = AdminMessage.new(program: program, sender: member, subject: "Test", content: "Content")
      a.message_receivers = [AdminMessages::Receiver.new(message: a, email: "Offline-user@example.com", name: "Offline User")]
      a.save!
    end
  end

  def test_creation_to_admin_success_without_id
    program = programs(:albers)
    admin_message = nil

    assert_emails program.admin_users.count do
      assert_difference "AdminMessage.count" do
        admin_message = AdminMessage.new(
          program: program,
          sender_name: 'Srini',
          sender_email: 'good@gmail.com',
          subject: 'Test',
          content: 'This is the content'
        )
        admin_message.message_receivers = [AdminMessages::Receiver.new(message: admin_message)]
        admin_message.save!
      end
    end
    assert_equal 'Srini', admin_message.sender_name
    assert_equal 'good@gmail.com', admin_message.sender_email
    assert_equal 'Test', admin_message.subject
    assert_equal 'This is the content', admin_message.content
  end

  def test_should_not_create_message_if_group_given_and_user_is_not_given
    error = assert_raise(ActiveRecord::RecordInvalid) do
      AdminMessage.create!(
        group: groups(:mygroup),
        program: programs(:albers),
        sender_email: 'email@sender.com',
        sender_name: 'Sender Name',
        subject: "Subject",
        content: 'Content'
      )
    end
    assert_match("Sender can't be blank (group given)", error.message)
  end

  def test_should_not_create_message_if_user_does_not_belong_to_group
    error = assert_raise(ActiveRecord::RecordInvalid) do
      AdminMessage.create!(
        sender: members(:f_student),
        group: groups(:mygroup),
        program: programs(:albers),
        sender_email: 'email@sender.com',
        sender_name: 'Sender Name',
        subject: "Subject",
        content: 'Content',
        auto_email: false
      )
    end
    assert_match("User does not belong to the group", error.message)
  end

  def test_should_not_create_message_if_limit_exceeded
    AdminMessage.destroy_all
    10.times do
      admin_message = AdminMessage.new(sender: members(:f_student), program: programs(:albers), subject: "Subject", content: 'Content')
      admin_message.message_receivers.build
      admin_message.save!
    end
    e = assert_raise(ActiveRecord::RecordInvalid) do
      admin_message = AdminMessage.new(sender: members(:f_student), program: programs(:albers), subject: "Subject", content: 'Content')
      admin_message.message_receivers.build
      admin_message.save!
    end
    assert_match("You have exceeded the maximum number of messages that can be sent to the administrators in an hour. Please try again later.", e.message)
  end

  def test_should_create_message_and_send_email_instantly_even_if_user_is_weekly_digest
    program = programs(:albers)
    receiver_member = members(:f_student)
    receiver_user = receiver_member.user_in_program(program)
    receiver_user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::DAILY
    receiver_user.save!
    assert_no_difference('PendingNotification.count') do
      assert_emails do
        create_admin_message(receivers: [receiver_member], sender: members(:f_admin), auto_email: true)
      end
    end
    assert_equal UserConstants::DigestV2Setting::ProgramUpdates::DAILY, receiver_user.program_notification_setting
  end

  def test_should_create_message_if_user_belongs_to_group
    assert_difference "AdminMessage.count" do
      @admin_message = AdminMessage.new(
        sender: members(:mkr_student),
        group: groups(:mygroup),
        program: programs(:albers),
        subject: "Subject",
        content: 'Content'
      )
      @admin_message.message_receivers = [AdminMessages::Receiver.new(message: @admin_message)]
      @admin_message.save!
    end
    assert_equal users(:mkr_student), @admin_message.sender_user
    assert_equal groups(:mygroup), @admin_message.group
  end

  def test_setters
    m1 = create_admin_message(receivers: [members(:f_student)], sender: members(:f_admin))
    m2 = create_admin_message(receivers: [members(:f_student)], sender: members(:f_admin), program: programs(:org_primary))
    assert_equal [members(:f_student)], m1.receivers
    assert_equal [members(:f_student)], m2.receivers

    m1.receiver_ids = [members(:f_mentor_student), members(:f_mentor)].collect(&:id).join(",")
    m2.receiver_ids = [members(:f_mentor_student), members(:f_mentor)].collect(&:id).join(",")
    m1.save!
    m2.save!
    assert_equal_unordered [members(:f_mentor_student), members(:f_mentor)], m1.receivers
    assert_equal_unordered [members(:f_mentor_student), members(:f_mentor)], m2.receivers

    groups = [groups(:mygroup), groups(:group_2), groups(:multi_group)]
    members = [groups(:mygroup), groups(:group_2)].collect(&:members).flatten.collect(&:member).uniq
    mentors = [groups(:mygroup), groups(:group_2)].collect(&:mentors).flatten.collect(&:member).uniq
    m1.connection_send_message_type_or_role = Connection::Membership::SendMessage::ALL
    m1.connection_ids = groups.collect(&:id).join(",")
    m2.connection_send_message_type_or_role = Connection::Membership::SendMessage::ALL
    m2.connection_ids = groups.collect(&:id).join(",")
    m1.save!
    m2.save!
    assert_equal_unordered members, m1.receivers
    assert_equal_unordered [members(:f_mentor_student), members(:f_mentor)], m2.receivers

    m1.connection_send_message_type_or_role = RoleConstants::MENTOR_NAME
    m1.connection_ids = groups.collect(&:id).join(",")
    m1.save!
    assert_equal_unordered mentors, m1.receivers
  end

  def test_sent_by_admin
    assert_false messages(:first_admin_message).sent_by_admin?
    assert messages(:third_admin_message).sent_by_admin?

    m1 = create_admin_message(program: programs(:org_primary), sender: members(:ram)) # not a org level admin
    assert_false m1.sent_by_admin?
    m1.update_attributes(sender: members(:f_admin))
    assert m1.sent_by_admin?
  end

  def test_is_member_admin_for_this_msg
    assert messages(:first_admin_message).is_member_admin_for_this_msg?(members(:f_admin))
    assert messages(:first_admin_message).is_member_admin_for_this_msg?(members(:ram))

    m1 = create_admin_message(program: programs(:org_primary), sender: members(:ram)) # not a org level admin
    assert m1.is_member_admin_for_this_msg?(members(:f_admin))
    assert_false m1.is_member_admin_for_this_msg?(members(:ram))
  end

  def test_sent_to_and_sent_by
    assert messages(:first_admin_message).sent_to?(members(:f_admin))
    assert_false messages(:first_admin_message).sent_to?(members(:f_student))
    assert messages(:third_admin_message).sent_to?(members(:f_student))
    assert_false messages(:third_admin_message).sent_to?(members(:f_admin))

    assert_false messages(:first_admin_message).sent_by?(members(:f_admin))
    assert messages(:first_admin_message).sent_by?(members(:f_student))
    assert_false messages(:third_admin_message).sent_by?(members(:f_student))
    assert messages(:third_admin_message).sent_by?(members(:f_admin))
  end

  def test_admin_to_user
    message_1 = messages(:third_admin_message)
    message_2 = messages(:reply_to_offline_user)
    assert message_1.admin_to_registered_user?
    assert_false message_2.admin_to_registered_user?
    assert_false message_1.admin_to_offline_user?
    assert message_2.admin_to_offline_user?

    assert message_1.admin_to_user?
    assert message_2.admin_to_user?
    assert_false messages(:first_admin_message).admin_to_user?

    message_1.stubs(:message_receivers).returns([])
    assert message_1.admin_to_registered_user?
    assert_false message_1.admin_to_offline_user?
    assert message_1.admin_to_user?
  end

  def test_user_to_admin
    assert messages(:first_admin_message).user_to_admin?
    assert messages(:second_admin_message).user_to_admin?
    assert_false messages(:third_admin_message).user_to_admin?
    assert_false messages(:reply_to_offline_user).user_to_admin?
  end

  def test_logged_in_user_to_admin_new_thread
    assert messages(:first_admin_message).logged_in_user_to_admin_new_thread?
    assert_false messages(:second_admin_message).logged_in_user_to_admin_new_thread? # non loggedin user
    assert_false messages(:third_admin_message).logged_in_user_to_admin_new_thread? # reply
  end

  def test_deleted
    user_to_admin = messages(:first_admin_message)
    admin_to_user = messages(:third_admin_message)
    assert_false user_to_admin.deleted?(members(:f_admin))
    assert_false user_to_admin.deleted?(members(:ram))
    assert_false user_to_admin.deleted?(members(:f_student))

    user_to_admin.mark_deleted!(members(:f_admin))
    assert user_to_admin.reload.deleted?(members(:f_admin))
    assert user_to_admin.deleted?(members(:ram))
    assert_false user_to_admin.deleted?(members(:f_student))

    assert_false admin_to_user.deleted?(members(:f_student))
    assert_false admin_to_user.deleted?(members(:f_admin))

    admin_to_user.mark_deleted!(members(:f_student))
    assert admin_to_user.reload.deleted?(members(:f_student))
    assert_false admin_to_user.deleted?(members(:f_admin))
  end

  def test_can_be_viewed
    user_to_admin = messages(:first_admin_message)
    admin_to_user = messages(:third_admin_message)
    assert user_to_admin.receivers.empty?
    assert_equal members(:f_student), user_to_admin.sender
    assert_false user_to_admin.can_be_viewed?(members(:f_mentor))
    assert user_to_admin.can_be_viewed?(members(:f_student))
    assert user_to_admin.can_be_viewed?(members(:f_admin))

    user_to_admin.mark_deleted!(members(:f_admin))
    assert_false user_to_admin.can_be_viewed?(members(:f_admin))
    assert user_to_admin.can_be_viewed?(members(:f_student))

    assert admin_to_user.sent_to?(members(:f_student))
    assert admin_to_user.can_be_viewed?(members(:f_admin))
    assert admin_to_user.can_be_viewed?(members(:ram))
    assert admin_to_user.can_be_viewed?(members(:f_student))

    admin_to_user.mark_deleted!(members(:f_student))
    assert_false admin_to_user.reload.can_be_viewed?(members(:f_student))
    assert admin_to_user.can_be_viewed?(members(:f_admin))
  end

  def test_can_be_replied_user_to_admin
    user_to_admin_message = messages(:first_admin_message)

    assert user_to_admin_message.can_be_replied?(members(:f_student))
    assert_false user_to_admin_message.can_be_replied?(members(:f_mentor_student))
    assert user_to_admin_message.can_be_replied?(members(:f_admin))
    assert user_to_admin_message.can_be_replied?(members(:ram))

    user_to_admin_message.mark_deleted!(members(:f_admin))
    assert user_to_admin_message.can_be_replied?(members(:f_student))
    assert_false user_to_admin_message.can_be_replied?(members(:f_admin))
    assert_false user_to_admin_message.can_be_replied?(members(:ram))
  end

  def test_can_be_replied_admin_to_user
    admin_to_user_message = messages(:third_admin_message)

    assert admin_to_user_message.can_be_replied?(members(:f_student))
    assert_false admin_to_user_message.can_be_replied?(members(:f_mentor_student))
    assert admin_to_user_message.can_be_replied?(members(:f_admin))
    assert admin_to_user_message.can_be_replied?(members(:ram))

    admin_to_user_message.update_attribute(:auto_email, true)
    assert admin_to_user_message.can_be_replied?(members(:f_student))
    assert_false admin_to_user_message.can_be_replied?(members(:f_admin))

    admin_to_user_message.update_attribute(:auto_email, false)
    admin_to_user_message.mark_deleted!(members(:f_student))
    assert_false admin_to_user_message.can_be_replied?(members(:f_student))
    assert admin_to_user_message.can_be_replied?(members(:f_admin))
    assert admin_to_user_message.can_be_replied?(members(:ram))
  end

  def test_build_reply_admin_to_offline_user
    user_to_admin_message = create_admin_message(sender_name: "Test", sender_email: "test@chronus.com")
    admin_to_user_reply = user_to_admin_message.build_reply(members(:f_admin))
    assert_equal user_to_admin_message, admin_to_user_reply.parent
    assert admin_to_user_reply.is_a?(AdminMessage)
    assert_equal user_to_admin_message.program, admin_to_user_reply.program
    assert_equal user_to_admin_message.subject, admin_to_user_reply.subject
    assert_equal members(:f_admin), admin_to_user_reply.sender

    assert_equal user_to_admin_message.sender_email, admin_to_user_reply.only_receiver.email
    assert_equal user_to_admin_message.sender_name, admin_to_user_reply.only_receiver.name
    assert_nil admin_to_user_reply.only_receiver.member
  end

  def test_build_reply_offline_user_to_admin
    admin_to_user_message = create_admin_message(receiver_name: "Test", receiver_email: "test@chronus.com", sender: members(:f_admin))
    user_to_admin_reply = admin_to_user_message.build_reply(nil)
    assert_equal admin_to_user_message, user_to_admin_reply.parent
    assert user_to_admin_reply.is_a?(AdminMessage)
    assert_equal admin_to_user_message.program, user_to_admin_reply.program
    assert_equal admin_to_user_message.subject, user_to_admin_reply.subject
    assert_nil user_to_admin_reply.sender
    assert_nil user_to_admin_reply.only_receiver.member
  end

  def test_build_reply_admin_to_member
    member = members(:dormant_member)
    member_to_admin_message = create_admin_message(sender: member)
    admin_to_member_reply = member_to_admin_message.build_reply(members(:f_admin))
    assert_equal member_to_admin_message, admin_to_member_reply.parent
    assert admin_to_member_reply.is_a?(AdminMessage)
    assert_equal member_to_admin_message.program, admin_to_member_reply.program
    assert_equal member_to_admin_message.subject, admin_to_member_reply.subject
    assert_equal members(:f_admin), admin_to_member_reply.sender
    [:name, :email].all? { |attr| assert_nil admin_to_member_reply.only_receiver.send(attr) }

    member_to_admin_reply = member_to_admin_message.build_reply(member, from_inbox: true)
    assert_equal member, member_to_admin_reply.sender
    assert member_to_admin_reply.user_to_admin?
  end

  def test_build_reply_member_to_admin
    member = members(:dormant_member)
    admin_to_member_message = create_admin_message(receiver: member, sender: members(:f_admin))
    member_to_admin_reply = admin_to_member_message.build_reply(member, from_inbox: true)
    assert_equal admin_to_member_message, member_to_admin_reply.parent
    assert member_to_admin_reply.is_a?(AdminMessage)
    assert_equal admin_to_member_message.program, member_to_admin_reply.program
    assert_equal admin_to_member_message.subject, member_to_admin_reply.subject
    assert_equal admin_to_member_message.only_receiver.member, member_to_admin_reply.sender
    [:member, :name, :email].all? { |attr| assert_nil member_to_admin_reply.only_receiver.send(attr) }

    admin_to_member_reply = admin_to_member_message.build_reply(admin_to_member_message.sender)
    assert_equal members(:f_admin), admin_to_member_reply.sender
    assert_equal [member], admin_to_member_reply.message_receivers.collect(&:member)
  end

  def test_build_reply_admin_to_admin
    admin1 = members(:f_admin)
    admin2 = members(:ram)
    message = create_admin_message(sender: admin1, receivers: [admin2])
    reply_from_admin_inbox = message.build_reply(admin2)
    reply_from_personal_inbox = message.build_reply(admin2, from_inbox: true)
    assert reply_from_admin_inbox.admin_to_user?
    assert_equal reply_from_admin_inbox.only_receiver.member, admin2
    assert reply_from_personal_inbox.user_to_admin?
    assert_nil reply_from_personal_inbox.only_receiver.member
    reply_to_user_to_admin_message_sent_by_user_with_admin_role = reply_from_personal_inbox.build_reply(admin1)
    assert reply_to_user_to_admin_message_sent_by_user_with_admin_role.admin_to_user?
    assert reply_to_user_to_admin_message_sent_by_user_with_admin_role.only_receiver.member, admin2
  end

  def test_dependent_destroy_push_notification
    member = members(:f_admin)
    ref_obj = create_admin_message(receiver_name: "Test", receiver_email: "test@chronus.com", sender: member, no_email_notifications: false, auto_email: true)
    object = { object_id: ref_obj.id, category: AdminMessage.name }
    member.push_notifications.create!(notification_params: object, ref_obj_id: ref_obj.id, ref_obj_type: ref_obj.class.name, notification_type: PushNotification::Type::MESSAGE_SENT_NON_ADMIN)
    assert_difference "PushNotification.count", -1 do
      ref_obj.reload.destroy
    end
  end

  def test_read_unread_and_mark_as_read
    m1 = create_admin_message(sender: members(:f_mentor))
    assert_false m1.read?(members(:f_admin))
    assert_false m1.read?(members(:ram))
    assert m1.read?(members(:f_mentor))
    assert m1.unread?(members(:f_admin))
    assert m1.unread?(members(:ram))
    assert_false m1.unread?(members(:f_mentor))

    m1.mark_as_read!(members(:ram))
    assert m1.read?(members(:f_admin))
    assert m1.read?(members(:ram))
    assert m1.read?(members(:f_mentor))
    assert_false m1.unread?(members(:f_admin))
    assert_false m1.unread?(members(:ram))
    assert_false m1.unread?(members(:f_mentor))

    m2 = create_admin_message(sender: members(:f_admin), receivers: [members(:f_admin), members(:f_student)])
    assert_false m2.read?(members(:f_admin))
    assert m2.read?(members(:ram))
    assert_false m2.read?(members(:f_student))
    assert m2.unread?(members(:f_admin))
    assert_false m2.unread?(members(:ram))
    assert m2.unread?(members(:f_student))

    m2.mark_as_read!(members(:f_student))
    assert_false m2.read?(members(:f_admin))
    assert m2.read?(members(:ram))
    assert m2.read?(members(:f_student))
    assert m2.unread?(members(:f_admin))
    assert_false m2.unread?(members(:ram))
    assert_false m2.unread?(members(:f_student))
  end

  def test_member_admin_filtered_tree
    admin = members(:f_admin)
    m1 = create_admin_message(sender: admin, receivers: [members(:f_student), members(:f_mentor)])
    m2 = create_admin_message(sender: members(:f_student))
    m2.update_attribute(:parent_id, m1.id)
    m3 = create_admin_message(sender: members(:f_mentor))
    m3.update_attribute(:parent_id, m1.id)

    assert_equal_unordered [m1, m2, m3], m1.member_admin_filtered_tree(admin)
    assert_equal_unordered [m1, m2], m1.member_admin_filtered_tree(members(:f_student))
    assert_equal_unordered [m1, m3], m1.member_admin_filtered_tree(members(:f_mentor))
  end

  def test_create_for_facilitation_message
    user = users(:f_mentor)
    group = user.groups.first
    facilitation_template = create_mentoring_model_facilitation_template

    admin_message = nil
    facilitation_template.expects(:prepare_message).returns(["message", true])
    assert_difference "AdminMessage.count" do
      admin_message = AdminMessage.create_for_facilitation_message(facilitation_template, user, members(:f_admin), group)
    end
    assert admin_message.auto_email?
    assert admin_message.no_email_notifications
  end

  def test_tags_for_facilitation_message
    program = programs(:albers)
    group = groups(:mygroup)
    admin_member = program.admin_users.first.member
    facilitation_template = create_mentoring_model_facilitation_template(roles: program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]),
      message: "Group Name : {{group_name}}, Connection Area Button : {{mentoring_area_button}}")
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      facilitation_template.deliver_to_eligible_recipients(group, admin_member)
    end
    admin_message = AdminMessage.last
    assert_match "Group Name : #{h group.name}", admin_message.content
    assert_match "Visit your #{program.return_custom_term_hash[:_mentoring_connection]} area", admin_message.content
  end

  def test_get_sender
    message = messages(:first_admin_message)
    assert message.sender
    assert message.for_program?
    assert_equal message.sender_user, message.get_sender

    message = messages(:second_admin_message)
    assert_nil message.sender
    assert_equal message.sender_email, message.get_sender
  end

  def test_send_new_message_to_offline_user_notification
    admin_message = messages(:reply_to_offline_user)
    assert_emails 1 do
      AdminMessage.send_new_message_to_offline_user_notification(admin_message.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [messages(:second_admin_message).sender_email], email.to
    assert_equal "Re - Second admin message", email.subject

    assert_no_emails do
      AdminMessage.send_new_message_to_offline_user_notification(0)
    end
  end
end