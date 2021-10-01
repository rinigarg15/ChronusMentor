require_relative "./../test_helper.rb"

class AbstractMessageTest < ActiveSupport::TestCase

  def test_no_of_descendants
    assert_equal AbstractMessage.descendants, [AdminMessage, Message, Scrap]
    # if the following test is failing because of your change , please go and change the classes param passed in
    # get_paginated_filtered_messages method in abstract_message_filter_service.rb
  end

  def test_get_user
    assert_equal users(:f_admin), messages(:first_admin_message).get_user(members(:f_admin))
    assert_equal users(:f_mentor), messages(:mygroup_mentor_1).get_user(members(:f_mentor))
  end

  def test_sender_user
    assert_equal users(:f_student), messages(:first_admin_message).sender_user
    assert_equal users(:f_mentor), messages(:mygroup_mentor_1).sender_user
  end

  def test_for_program_and_organization
    assert_false messages(:first_message).for_program?
    assert messages(:first_message).for_organization?

    assert messages(:first_admin_message).for_program?
    assert_false messages(:first_admin_message).for_organization?
  end

  def test_context_program_for_email
    m = messages(:first_message)
    assert_nil m.context_program_for_email

    m.stubs(:get_context_program).returns(programs(:nwen))
    assert_equal programs(:nwen), m.context_program_for_email

    m.update_attribute(:program_id, programs(:albers).id)
    assert_equal programs(:albers), m.context_program_for_email
  end

  def test_get_context_program
    m = messages(:first_message)
    m.stubs(:context_program).returns("something")
    m.stubs(:all_members_are_present_in_program?).with("something").returns("something else")

    assert_equal "something", m.get_context_program

    m.stubs(:all_members_are_present_in_program?).with("something").returns(nil)
    assert_nil m.get_context_program
  end

  def test_all_members_are_present_in_program
    m = create_message(sender: members(:f_student))
    assert_equal [members(:f_mentor)], m.receivers
    assert_equal members(:f_student), m.sender
    assert m.all_members_are_present_in_program?(programs(:albers))
    assert m.all_members_are_present_in_program?(programs(:nwen))
    assert m.all_members_are_present_in_program?(programs(:pbe))

    users(:f_mentor_pbe).destroy
    assert m.all_members_are_present_in_program?(programs(:albers))
    assert m.all_members_are_present_in_program?(programs(:nwen))
    assert_false m.all_members_are_present_in_program?(programs(:pbe))

    users(:f_student_nwen_mentor).destroy
    assert m.all_members_are_present_in_program?(programs(:albers))
    assert_false m.all_members_are_present_in_program?(programs(:nwen))
    assert_false m.all_members_are_present_in_program?(programs(:pbe))
  end

  def test_send_progam_level_email
    m = messages(:first_message)
    assert_false m.for_program?
    assert_false m.send_progam_level_email?

    m.context_program = programs(:albers)
    assert m.send_progam_level_email?

    m.context_program = nil
    assert_false m.send_progam_level_email?

    m.stubs(:for_program?).returns(true)
    assert m.send_progam_level_email?
  end

  def test_formatted_subject
    m1 = create_message
    m1.update_attribute(:subject, "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n<br /> newline in it")
    assert_equal "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n<br /> newline in it", m1.formatted_subject
    assert m1.formatted_content.html_safe?
  end

  def test_formatted_content
    user_to_admin_message = messages(:first_admin_message)
    user_to_admin_message.update_attribute(:content, "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n newline in it")
    assert_equal "this has &lt;strong&gt;bold&lt;/strong&gt; content &lt;script&gt;alert(&#39;hacked&#39;)&lt;/script&gt; and \n<br /> newline in it", user_to_admin_message.formatted_content

    admin_to_user_message = messages(:first_campaigns_admin_message)
    admin_to_user_message.update_attribute(:content, "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n newline in it")
    assert_equal "this has <strong>bold</strong> content <script>alert('hacked')</script> and \n newline in it", admin_to_user_message.formatted_content
  end

  def test_get_root
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    assert_equal m1, m1.get_root
    assert_equal m1, m2.get_root
    assert_equal m1, m3.get_root
    assert_equal m1, m5.get_root
  end

  def test_siblings
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    assert_equal_unordered [m1, m2, m3, m4, m5], m1.siblings # root
    assert_equal_unordered [m1, m2, m3, m4, m5], m2.siblings # non-root
  end

  def test_subtree
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    assert_equal_unordered [m2, m3, m4, m5], m1.subtree
    assert_equal_unordered [], m3.subtree
    assert_equal_unordered [m5], m4.subtree
  end

  def test_tree
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    assert_equal [m1, m2, m3, m4, m5], m1.tree
    assert_equal [m3], m3.tree
    assert_equal [m4, m5], m4.tree
  end

  def test_reply
    assert_false messages(:first_admin_message).reply?
    assert_false messages(:first_admin_message).reply?

    assert messages(:third_admin_message).reply?
    assert messages(:reply_to_offline_user).reply?
  end

  def test_root
    m1 = create_message
    m2 = create_message; m2.update_attribute(:parent_id, m1.id)
    assert m1.root?
    assert_false m2.root?
  end

  def test_sender_name
    assert_equal messages(:first_message).sender_name, "Mentor Studenter"
    assert_equal messages(:second_admin_message).sender_name, "Test User"
    assert_equal messages(:reply_to_offline_user).sender_name, "Freakin Admin (Administrator)"
  end

  def test_get_message_receiver
    message = messages(:first_message)
    message.receivers << members(:f_mentor_student)
    assert_equal message.message_receivers.first, message.get_message_receiver(members(:f_mentor))
    assert_equal message.message_receivers.last, message.get_message_receiver(members(:f_mentor_student))
    assert_nil message.get_message_receiver(members(:f_admin))
  end

  def test_sent_by
    assert messages(:first_message).sent_by?(members(:f_mentor_student))
    assert_false messages(:first_message).sent_by?(members(:f_mentor))
  end

  def test_sent_to
    assert messages(:first_message).sent_to?(members(:f_mentor))
    assert_false messages(:first_message).sent_to?(members(:f_mentor_student))
  end

  def test_read_unread_and_mark_as_read
    message = messages(:first_message)
    assert message.read?(members(:f_mentor_student))
    assert_false message.read?(members(:f_mentor))
    assert_false message.unread?(members(:f_mentor_student))
    assert message.unread?(members(:f_mentor))

    message.mark_as_read!(members(:f_mentor))
    assert message.read?(members(:f_mentor_student))
    assert message.read?(members(:f_mentor))
    assert_false message.unread?(members(:f_mentor_student))
    assert_false message.unread?(members(:f_mentor))
  end

  def test_mark_tree_as_read
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    assert m1.tree_contains_unread_for_member?(members(:f_mentor))
    m1.mark_tree_as_read!(members(:f_mentor))
    assert_false m1.reload.tree_contains_unread_for_member?(members(:f_mentor))
  end

  def test_mark_siblings_as_read
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    assert m1.tree_contains_unread_for_member?(members(:f_mentor))
    m1.mark_siblings_as_read(members(:f_mentor))
    assert_false m1.reload.tree_contains_unread_for_member?(members(:f_mentor))
  end

  def test_deleted_and_mark_deleted
    m1 = create_message
    assert_false m1.deleted?(members(:f_mentor))

    m1.mark_deleted!(members(:f_mentor))
    assert_false m1.reload.deleted?(m1.sender)
    assert m1.deleted?(members(:f_mentor))
  end

  def test_file_attachment_type_not_recognized
    message = messages(:first_message)
    message.attachment = fixture_file_upload(File.join("files", "test_php.php"), "application/x-php")
    assert_false message.valid?
    assert_equal message.errors.full_messages.first, "Attachment content type is restricted"
  end

  def test_attachment_type_on_create
    message = AbstractMessage.create(
      subject: "test message",
      content: "test content",
      program: programs(:albers),
      attachment: fixture_file_upload(File.join("files", "test_php.php"), "application/x-php")
    )
    assert_false message.valid?
    assert_equal message.errors.full_messages.first, "Attachment content type is restricted"
    assert_equal message.errors.full_messages.last, "Attachment file name is invalid"
  end

  def test_attachment_type_on_update
    message = messages(:first_message)
    message.attachment = fixture_file_upload(File.join("files", "some_file.txt"))
    assert message.valid?
    message.attachment_file_name = "test.html"
    assert_false message.valid?
    assert_equal message.errors.full_messages.first , "Attachment file name is invalid"
  end

  def test_file_attachment_file_name_in_disallowed_extensions
    message = messages(:first_message)
    message.attachment = fixture_file_upload(File.join("files", "test_php.php"), "application/octet-stream")
    assert_false message.valid?
    assert_equal message.errors.full_messages.first, "Attachment file name is invalid"
  end

  def test_file_attachment_type_recognized
    message = messages(:first_message)
    message.attachment = fixture_file_upload(File.join("files", "some_file.txt"), "text/text")
    assert message.valid?
  end

  def test_file_attachment_size_too_big
    message = messages(:first_message)
    message.attachment = fixture_file_upload(File.join("files", "some_file.txt"), "text/text")
    message.attachment_file_size = 21.megabytes
    assert_false message.valid?
  end

  def test_file_attachment_size_upload
    message = messages(:first_message)
    message.attachment = fixture_file_upload(File.join("files", "some_file.txt"), "text/text")
    message.attachment_content_type = 2.megabytes
    assert_false message.valid?
  end

  def test_can_be_viewed
    message = messages(:first_message)
    assert message.can_be_viewed?(members(:f_mentor))
    assert message.can_be_viewed?(members(:f_mentor_student))
    assert_false message.can_be_viewed?(members(:f_admin))

    message.mark_deleted!(members(:f_mentor))
    assert message.reload.can_be_viewed?(members(:f_mentor_student))
    assert_false message.can_be_viewed?(members(:f_mentor))
    assert_false message.can_be_viewed?(members(:f_admin))
  end

  def test_can_be_deleted
    assert_false messages(:first_admin_message).can_be_deleted?(members(:f_mentor_student))
    assert messages(:first_admin_message).can_be_deleted?(members(:f_admin))

    from_me_to_me = create_admin_message(sender: members(:f_admin), receivers: [members(:f_admin)])
    assert_false from_me_to_me.can_be_deleted?(members(:f_admin))
    assert_false from_me_to_me.can_be_deleted?(members(:ram))
  end

  def test_last_message_can_be_viewed_and_sibling_has_attachment
    m1 = create_message
    m2 = create_message
    m2.update_attributes(parent_id: m1.id, root_id: m1.id, attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    assert_equal m2, m1.reload.last_message_can_be_viewed(members(:f_mentor))
    assert m1.sibling_has_attachment?(members(:f_mentor))

    m2.mark_deleted!(members(:f_mentor))
    assert_equal m1, m1.reload.last_message_can_be_viewed(members(:f_mentor))
    assert_false m1.sibling_has_attachment?(members(:f_mentor))
  end

  def test_thread_members_and_size
    m1 = create_message
    m2 = create_message; m2.update_attribute(:parent_id, m1.id)
    m3 = create_message(sender: members(:f_mentor), receivers: [members(:f_mentor_student)]); m3.update_attribute(:parent_id, m1.id)
    m4 = create_message; m4.update_attribute(:parent_id, m2.id)
    m5 = create_message; m5.update_attribute(:parent_id, m4.id)

    details = m1.thread_members_and_size(m1.sender)
    assert_equal 5, details[:size]
    assert_equal_unordered [members(:f_mentor_student), members(:f_mentor)], details[:members]

    unread_hash = details[:unread]
    assert unread_hash[m3.sender]
    assert_false unread_hash[m1.sender]
    m3.mark_as_read!(m1.sender)
    unread_hash = m1.reload.thread_members_and_size(m1.sender)[:unread]
    assert_false unread_hash[m3.sender] # Read receiver
    assert_false unread_hash[m1.sender] # Sender
  end

  def test_thread_receivers_details
    m1 = messages(:first_message)
    m2 = create_message(sender: members(:f_mentor), receivers: [members(:f_mentor_student)]); m2.update_attribute(:parent_id, m1.id)

    details = m1.thread_receivers_details(members(:f_mentor_student))
    assert_equal m1, details[:first_sent_message]
    assert details[:unread]
    assert_equal 2, details[:size]

    m2.mark_as_read!(members(:f_mentor_student))
    details = m1.reload.thread_receivers_details(members(:f_mentor_student))
    assert_false details[:unread]

    details = m1.thread_receivers_details(members(:f_mentor))
    assert_equal m2, details[:first_sent_message]
    assert details[:unread]
    assert_equal 2, details[:size]
  end

  def test_tree_contains_unread_for_member
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    [m1, m2, m3, m4, m5].each do |m|
      assert m1.tree_contains_unread_for_member?(members(:f_mentor))
      m.mark_as_read!(members(:f_mentor))
    end
    assert_false m1.reload.tree_contains_unread_for_member?(members(:f_mentor))
  end

  def test_get_next_not_marked_as_deleted
    m1, m2, m3, m4, m5 = create_temporary_messages_tree
    receiver = members(:f_mentor)
    assert_equal m1, m1.get_next_not_marked_as_deleted(receiver)
    assert_not_equal m1, m1.mark_deleted!(receiver)
    assert_equal m2, m1.reload.get_next_not_marked_as_deleted(receiver)
  end

  def test_send_email_notifications_for_messages
    Push::Notifications::AbstractMessagePushNotification.any_instance.expects(:send_push_notification).once
    sender = members(:f_mentor)
    receiver = members(:f_user)
    assert_difference "JobLog.count" do
      assert_emails 1 do
        @m1 = create_message(sender: sender, receiver: receiver)
      end
    end
    joblog = JobLog.last
    assert_equal "AbstractMessage", joblog.loggable_object_type
    assert_equal @m1.id, joblog.loggable_object_id
    assert_equal "Member", joblog.ref_obj_type
    assert_equal RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION, joblog.action_type

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        AbstractMessage.send_email_notifications(@m1.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION)
      end
    end

    User.any_instance.expects(:send_email).once #campaign mails should call send_email on the user.
    Push::Notifications::AbstractMessagePushNotification.any_instance.expects(:send_push_notification).once
    assert_difference "JobLog.count" do
      cm_campaign_message_jobs(:pending_active_campaign_message_1_job_for_admin).create_personalized_message
    end
    joblog = JobLog.last
    assert_equal RecentActivityConstants::Type::USER_CAMPAIGN_EMAIL_NOTIFICATION, joblog.action_type
  end

  def test_send_email_notifications_for_messages_from_program_level
    Push::Notifications::AbstractMessagePushNotification.any_instance.expects(:send_push_notification).once
    assert_difference "JobLog.count" do
      assert_emails 1 do
        @m1 = Message.new({sender: members(:f_mentor), receivers: [members(:f_user)], organization: programs(:org_primary), subject: "This is subject", content: "This is content"})
        @m1.context_program = programs(:albers)
        @m1.save!
      end
    end
    joblog = JobLog.last
    assert_equal "AbstractMessage", joblog.loggable_object_type
    assert_equal @m1.id, joblog.loggable_object_id
    assert_equal "Member", joblog.ref_obj_type
    assert_equal RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK, joblog.action_type

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        AbstractMessage.send_email_notifications(@m1.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK)
      end
    end
  end

  def test_send_email_notifications_for_scraps
    Push::Notifications::AbstractMessagePushNotification.any_instance.expects(:send_push_notification).once
    assert_difference "JobLog.count" do
      assert_emails 1 do
        @s1 = create_scrap(group: groups(:mygroup))
      end
    end
    joblog = JobLog.last
    assert_equal "AbstractMessage", joblog.loggable_object_type
    assert_equal @s1.id, joblog.loggable_object_id
    assert_equal "Member", joblog.ref_obj_type
    assert_equal RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK, joblog.action_type

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        AbstractMessage.send_email_notifications(@s1.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK)
      end
    end
  end

  def test_send_email_notifications_for_admin_message
    Push::Notifications::AbstractMessagePushNotification.any_instance.expects(:send_push_notification).times(2)
    sender = members(:f_admin)
    receiver = members(:f_mentor)
    assert_difference "JobLog.count" do
      assert_emails 1 do
        @m1 = create_admin_message(sender: sender, receiver: receiver, program: sender.programs[0])
      end
    end
    job_logs = JobLog.last
    assert_equal "AbstractMessage", job_logs.loggable_object_type
    assert_equal @m1.id, job_logs.loggable_object_id
    assert_equal "Member", job_logs.ref_obj_type
    assert_equal receiver.id, job_logs.ref_obj_id

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        AbstractMessage.send_email_notifications(@m1.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK)
      end
    end

    #need_confirmation
    assert_difference "JobLog.count" do
      assert_emails 1 do
        create_admin_message(auto_email: true, receiver: receiver, program: sender.programs[0])
      end
    end
  end

  def test_send_email_notifications_for_inbox_message_for_track
    JobLog.destroy_all
    am = messages(:third_admin_message)
    assert_equal programs(:albers), am.program
    sender = am.sender
    assert_equal 1, am.receivers.count

    assert_difference "JobLog.count", 1 do
      assert_emails 1 do
        AbstractMessage.send_email_notifications(am.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_match(/in #{programs(:albers).name}/, get_html_part_from(email))
    assert_match(/#{am.content}/, get_html_part_from(email))

    JobLog.destroy_all
    AdminMessage.any_instance.stubs(:context_program_for_email).returns(programs(:nwen))

    assert_difference "JobLog.count", 1 do
      assert_emails 1 do
        AbstractMessage.send_email_notifications(am.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION_FOR_TRACK)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_match(/in #{programs(:nwen).name}/, get_html_part_from(email))
    assert_match(/#{am.content}/, get_html_part_from(email))

    AdminMessage.any_instance.unstub(:context_program_for_email)
    am.update_attributes!(program_id: am.program.parent_id)
    assert_difference "JobLog.count", 1 do
      assert_emails 1 do
        AbstractMessage.send_email_notifications(am.id, RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_no_match(/in #{programs(:albers).name}/, get_html_part_from(email))
    assert_match(/#{am.content}/, get_html_part_from(email))
  end

  def test_viewer_and_receiver_from_same_program
    message = create_admin_message(sender: members(:moderated_admin), receivers: [members(:moderated_student)], program: programs(:moderated_program))
    assert_false message.viewer_and_receiver_from_same_program?(members(:moderated_student), members(:f_student))
    assert message.viewer_and_receiver_from_same_program?(members(:moderated_student), members(:moderated_mentor))

    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], program: programs(:org_primary))
    assert message.viewer_and_receiver_from_same_program?(members(:f_student), members(:moderated_admin))

    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], program: programs(:albers))
    assert message.viewer_and_receiver_from_same_program?(members(:f_mentor), members(:f_admin))
  end

  def test_viewer_and_sender_from_same_program
    message = create_admin_message(sender: members(:moderated_admin), receivers: [members(:moderated_student)], program: programs(:moderated_program))
    assert_false message.viewer_and_sender_from_same_program?(members(:f_student))
    assert message.viewer_and_sender_from_same_program?(members(:moderated_mentor))

    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], program: programs(:org_primary))
    assert message.viewer_and_sender_from_same_program?(members(:moderated_student))

    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], program: programs(:albers))
    assert message.viewer_and_sender_from_same_program?(members(:f_mentor))
  end

  def test_set_context_program
    m1 = Message.create!(sender: members(:f_mentor), receivers: [members(:f_user)], organization: programs(:org_primary), subject: "This is subject", content: "This is content")
    assert_nil m1.context_program_id

    m2 = Message.create!(sender: members(:f_mentor), receivers: [members(:f_user)], organization: programs(:org_primary), subject: "This is subject", content: "This is content", context_program: programs(:albers))
    assert_equal programs(:albers).id, m2.context_program_id

    m3 = Message.create!(sender: members(:f_mentor), receivers: [members(:f_user)], organization: programs(:org_primary), subject: "This is subject", content: "This is content", parent_id: m1)
    assert_nil m3.context_program_id

    m4 = Message.create!(sender: members(:f_mentor), receivers: [members(:f_user)], organization: programs(:org_primary), subject: "This is subject", content: "This is content", parent_id: m1, context_program: programs(:albers))
    assert_equal programs(:albers).id, m4.context_program_id

    m5 = Message.create!(sender: members(:f_mentor), receivers: [members(:f_user)], organization: programs(:org_primary), subject: "This is subject", content: "This is content", parent_id: m2)
    assert_nil m5.context_program_id
  end

  def test_has_rich_text_content
    admin_to_user_message = messages(:first_campaigns_admin_message)
    assert admin_to_user_message.has_rich_text_content?
    user_to_admin_message = messages(:first_admin_message)
    assert_false user_to_admin_message.has_rich_text_content?
    reply_message = messages(:third_admin_message)
    assert_false reply_message.has_rich_text_content?
  end

  private

  def create_temporary_messages_tree
    m1 = create_message
    m2 = create_message(parent_id: m1.id, root_id: m1.id)
    m3 = create_message(parent_id: m1.id, root_id: m1.id)
    m4 = create_message(parent_id: m2.id, root_id: m1.id)
    m5 = create_message(parent_id: m4.id, root_id: m1.id)
    [m1, m2, m3, m4, m5]
  end
end
