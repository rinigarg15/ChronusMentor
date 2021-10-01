require_relative './../../test_helper.rb'

class AdminMessageObserverTest < ActiveSupport::TestCase
  def test_message_creation_contact_admin
    assert_emails 2 do
      create_admin_message(sender: members(:f_student))
    end
    assert_equal_unordered([[users(:f_admin).email], [users(:ram).email]], ActionMailer::Base.deliveries.collect(&:to).last(2))
  end

  def test_admin_message_not_sent_to_self_for_user_with_admin_non_admin_roles
    assert_emails do
      create_admin_message(sender: members(:ram))
    end
    # No email is sent to members(:ram)
    assert_equal [users(:f_admin).email], ActionMailer::Base.deliveries.last.to
  end

  def test_message_creation_contact_active_admins_only
    suspend_user(users(:ram))
    assert_emails do
      create_admin_message(sender: members(:f_student))
    end
    assert_equal_unordered([[users(:f_admin).email]], ActionMailer::Base.deliveries.collect(&:to).last(2))
    member = members(:f_admin)
    member.state = Member::Status::SUSPENDED
    member.save
    assert_no_emails do
      create_admin_message(program_id: programs(:org_primary).id, sender: members(:f_student))
    end
  end

  def test_reply_creation_admin_to_user
    ca = create_admin_message(sender: members(:f_student))
    user = members(:f_student).user_in_program(programs(:albers))

    ActionMailer::Base.deliveries.clear
    assert_emails do
      create_admin_message(sender: members(:f_admin), receiver: members(:f_student), parent_id: ca.id)
    end

    assert_equal_unordered([[users(:f_student).email]], ActionMailer::Base.deliveries.collect(&:to).last(2))

    # Send email to user with digest emails in his notification setting
    user.update_attributes!(program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::DAILY)
    ActionMailer::Base.deliveries.clear
    assert_emails do
      create_admin_message(sender: members(:f_admin), receiver: members(:f_student), parent_id: ca.id)
    end

    assert_equal_unordered([[users(:f_student).email]], ActionMailer::Base.deliveries.collect(&:to).last(2))

    # Send email to user with weekly digest in his notification setting
    user.update_attributes!(program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY)
    ActionMailer::Base.deliveries.clear
    assert_emails do
      create_admin_message(sender: members(:f_admin), receiver: members(:f_student), parent_id: ca.id)
    end

    assert_equal_unordered([[users(:f_student).email]], ActionMailer::Base.deliveries.collect(&:to).last(2))
  end

  def test_reply_creation_admin_to_not_logged_in_user
    AdminMessage.expects(:send_new_message_to_offline_user_notification).once
    admin_message = messages(:second_admin_message).build_reply(members(:f_admin))
    admin_message.sender = members(:f_admin)
    admin_message.content = "This is another good message"
    admin_message.save!
  end

  def test_contact_admin_notification_emails_should_go_to_all_admins
    # There are two admins for this program, they are ram@example.com and userram@example.com.
    assert_emails 2 do
      a = AdminMessage.new(program: programs(:albers), sender_name: 'Srini', sender_email: 'good@gamil.com', subject: 'Test', content: 'This is the content')
      a.message_receivers = [AdminMessages::Receiver.new(message: a)]
      a.save!
    end
  end

  def test_message_creation_for_organization
    # message sent to admin
    assert_emails do
      create_admin_message(sender: members(:f_student), program: programs(:org_primary))
    end
    assert_equal [members(:f_admin).email], ActionMailer::Base.deliveries.collect(&:to).last

    # message sent by admin
    ActionMailer::Base.deliveries.clear
    assert_emails do
      create_admin_message(sender: members(:f_admin), receiver: members(:f_student), program: programs(:org_primary))
    end
    assert_equal [members(:f_student).email] , ActionMailer::Base.deliveries.collect(&:to).last
  end

  def test_admin_message_not_sent_to_self_for_global_admin_org_level
    members(:ram).update_attributes!(admin: true)
    assert_emails do
      create_admin_message(sender: members(:ram), program: programs(:org_primary))
    end
    # No email is sent to members(:ram)
    assert_equal [users(:f_admin).email], ActionMailer::Base.deliveries.last.to
  end

  def test_assert_push_notifications_on_create
    organization = programs(:org_primary)
    program = programs(:albers)

    # organization level message - to admin
    PushNotifier.expects(:push).never
    create_admin_message(sender: members(:f_student), program: organization)

    # organization level message - sent by admin
    PushNotifier.expects(:push).once
    create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], program: organization)

    # organization level message - unregistered user to admin
    PushNotifier.expects(:push).never
    create_admin_message(program: organization, sender_name: 'Srini', sender_email: 'good@gamil.com', subject: 'Test', content: 'This is the content')

    # program level message - to admin
    PushNotifier.expects(:push).never
    create_admin_message(sender: members(:f_student), program: program)

    # program level message - sent by admin
    PushNotifier.expects(:push).once
    create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], program: program)

    #program level message - unregistered user to admin
    PushNotifier.expects(:push).never
    create_admin_message(program: program, sender_name: 'Srini', sender_email: 'good@gamil.com', subject: 'Test', content: 'This is the content')
  end

  def test_trigger_emails
    AdminMessage.any_instance.stubs(:send_progam_level_email?).returns(false)
    AdminMessage.any_instance.stubs(:context_program_for_email).returns(nil)
    assert_emails 1 do
      create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)])
    end

    email = ActionMailer::Base.deliveries.last
    assert_no_match(/in #{programs(:albers).name}/, get_html_part_from(email))

    AdminMessage.any_instance.stubs(:send_progam_level_email?).returns(true)
    AdminMessage.any_instance.unstub(:context_program_for_email)
    assert_emails 1 do
      create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)])
    end

    email = ActionMailer::Base.deliveries.last
    assert_match(/in #{programs(:albers).name}/, get_html_part_from(email))
  end
end
