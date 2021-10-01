require_relative './../../test_helper.rb'

class AdminMessages::ReceiverTest < ActiveSupport::TestCase

  def test_should_not_create_with_out_message
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
      AdminMessages::Receiver.create!(email: 'good@good.com', name: "test")
    end
  end

  def test_should_not_create_a_message_with_bad_receiver_email
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :email do
      AdminMessages::Receiver.create!(email: 'good', name: "test", message: messages(:reply_to_offline_user))
    end
  end

  def test_should_not_create_a_message_with_no_receiver_name
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :name do
      AdminMessages::Receiver.create!(email: 'good@chronus.com', message: messages(:reply_to_offline_user))
    end
  end

  def test_should_create
    assert_difference "AdminMessages::Receiver.count" do
      AdminMessages::Receiver.create!(email: 'good@good.com', name: "test", message: messages(:reply_to_offline_user))
    end
  end

  def test_should_create_for_email_with_whitespace_in_the_end
    assert_difference "AdminMessages::Receiver.count" do
      AdminMessages::Receiver.create!(email: 'good@good.com  ', name: "test", message: messages(:reply_to_offline_user))
    end
  end

  def test_received_messages
    rc_1 = messages(:second_admin_message).only_receiver
    rc_2 = messages(:first_admin_message).only_receiver
    assert_equal_unordered [rc_1, rc_2], programs(:albers).admin_message_receivers.received
    rc_1.mark_deleted!
    assert_equal_unordered [rc_2], programs(:albers).admin_message_receivers.received
  end

  def test_sent_messages
    rc_1 = messages(:reply_to_offline_user).only_receiver
    rc_2 = messages(:third_admin_message).only_receiver
    rc_3 = messages(:first_campaigns_admin_message).only_receiver
    rc_4 = messages(:second_campaigns_admin_message).only_receiver
    rc_5 = messages(:third_campaigns_admin_message).only_receiver
    rc_6 = messages(:seventh_campaigns_admin_message).only_receiver
    rc_7 = messages(:eigth_campaigns_admin_message).only_receiver
    rc_8 = messages(:first_campaigns_second_admin_message).only_receiver
    rc_9 = messages(:first_campaigns_third_admin_message).only_receiver
    assert_equal_unordered [rc_1, rc_2, rc_3, rc_4, rc_5, rc_6, rc_7, rc_8, rc_9], programs(:albers).admin_message_receivers.sent
    rc_2.mark_deleted!
    assert_equal_unordered [rc_1, rc_2, rc_3, rc_4, rc_5, rc_6, rc_7, rc_8, rc_9], programs(:albers).admin_message_receivers.sent
  end

  def test_check_for_presence_of_name_email
    assert_false messages(:first_admin_message).message_receivers.any?(&:check_for_presence_of_name_email?)
    assert_false messages(:second_admin_message).message_receivers.any?(&:check_for_presence_of_name_email?)
    assert_false messages(:third_admin_message).message_receivers.any?(&:check_for_presence_of_name_email?)
    assert messages(:reply_to_offline_user).message_receivers.all?(&:check_for_presence_of_name_email?)
  end

  def test_handle_reply_via_email_active_pending_and_suspended_user
    member = members(:f_student)
    message_receiver = messages(:third_admin_message).message_receivers.first
    message_receiver.update_attribute(:status, AbstractMessageReceiver::Status::UNREAD)
    assert message_receiver.unread?
    assert_difference "AdminMessage.count", 1 do
      assert message_receiver.handle_reply_via_email(
        content: "Re: This is just a test",
        sender_email: member.email
      )
    end
    assert message_receiver.read?

    users(:f_student).update_attribute(:state, User::Status::PENDING)
    assert_difference "AdminMessage.count", 1 do
      assert message_receiver.handle_reply_via_email(
        content: "Re: This is just a test",
        sender_email: member.email
      )
    end
    assert message_receiver.read?

    users(:f_student).update_attribute(:state, User::Status::SUSPENDED)
    assert_difference "AdminMessage.count", 1 do
      assert message_receiver.handle_reply_via_email(
        content: "Re: This is just a test",
        sender_email: member.email
      )
    end
    assert message_receiver.read?
  end

  def test_handle_reply_via_email_for_active_and_suspended_member_at_org_level
    member = members(:f_student)
    admin_message = create_admin_message(
      sender: members(:f_admin),
      receivers: [members(:f_student)],
      program: programs(:org_primary),
      subject: "Admin message",
      content: "This is just a test")
    message_receiver = admin_message.message_receivers.first
    assert message_receiver.unread?
    assert_difference "AdminMessage.count", 1 do
      assert message_receiver.handle_reply_via_email(
        content: "Re: This is just a test",
        sender_email: member.email
      )
    end

    member.update_attribute(:state, Member::Status::SUSPENDED)
    assert_difference "AdminMessage.count", 1 do
      assert message_receiver.handle_reply_via_email(
        content: "Re: This is just a test",
        sender_email: member.email
      )
    end
    assert message_receiver.read?
  end

  def test_handle_reply_via_email_should_fail_at_org_level
    admin_message = create_admin_message(
      sender: members(:f_student),
      program: programs(:org_primary),
      subject: "Admin message",
      content: "This is just a test")
    message_receiver = admin_message.message_receivers.first
    assert message_receiver.unread?
    assert_no_emails do
      assert_no_difference "AdminMessage.count" do
        assert_false message_receiver.handle_reply_via_email(
          subject: "This is a test subject",
          content: "This is a test content",
          sender_email: "xyz@example.com"
        )
      end
    end
    assert message_receiver.unread?
  end

  def test_handle_reply_via_email_should_fail_and_send_email_for_invalid_sender
    message_receiver = messages(:first_admin_message).message_receivers.first
    message_receiver.update_attribute(:status, AbstractMessageReceiver::Status::UNREAD)
    assert message_receiver.unread?

    assert_emails 1 do
      assert_no_difference "AdminMessage.count" do
        assert_false message_receiver.handle_reply_via_email(
          subject: "This is a test subject",
          content: "This is a test content",
          sender_email: "xyz@example.com"
        )
      end
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Re: This is a test subject", mail.subject
    assert "xyz@example.com", mail.to.first
    mail_body = get_html_part_from(mail)
    assert_match /We're sorry, but your message could not be posted because the sender email, xyz@example.com, is not recognized by the program/, mail_body
    assert_match /This is a test content/, mail_body
    assert message_receiver.unread?
  end

  def test_handle_reply_via_email_for_members_scope
    member_1 = members(:f_admin)
    member_2 = members(:psg_only_admin)
    member_2.update_attribute(:email, member_1.email)

    admin_message = create_admin_message(
      sender: members(:anna_univ_admin),
      receivers: [member_2],
      program: programs(:org_anna_univ),
      subject: "Admin message",
      content: "This is just a test")
    message_receiver = admin_message.message_receivers.first
    assert message_receiver.unread?
    assert_difference "AdminMessage.count", 1 do
      assert message_receiver.handle_reply_via_email(
        content: "Re: This is just a test",
        sender_email: member_2.email
      )
    end
    assert_equal member_2, admin_message.children.first.sender
    assert message_receiver.read?
  end
end