require_relative "./../../test_helper.rb"

class AdminMessagesFilterServiceTest < ActiveSupport::TestCase

  ## first_admin_message - Sender: members(:f_student)
  ## second_admin_message - Sender: Test User <test@chronus.com>
  ## third_admin_message - Sender: members(:f_admin)
  ## reply_to_offline_user - Sender: members(:f_admin)

  def test_inbox_messages_ids
    filter = AdminMessagesFilterService.new({})
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), filter.inbox_messages_ids(members(:ram), programs(:albers))

    messages(:second_admin_message).mark_deleted!(members(:f_admin))
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), filter.inbox_messages_ids(members(:ram), programs(:albers))
  end

  def test_inbox_messages_ids_filtered_by_sender_receiver
    sender_filter = AdminMessagesFilterService.new({sender: members(:f_student).name_with_email})
    receiver_filter = AdminMessagesFilterService.new({receiver: members(:f_student).name_with_email})
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), sender_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), receiver_filter.inbox_messages_ids(members(:ram), programs(:albers))

    sender_filter = AdminMessagesFilterService.new({sender: "Test User"})
    receiver_filter = AdminMessagesFilterService.new({receiver: "Test User"})
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), sender_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), receiver_filter.inbox_messages_ids(members(:ram), programs(:albers))

    sender_filter = AdminMessagesFilterService.new({sender: "test@chronus.com"})
    receiver_filter = AdminMessagesFilterService.new({receiver: "test@chronus.com"})
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), sender_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), receiver_filter.inbox_messages_ids(members(:ram), programs(:albers))

    sender_filter = AdminMessagesFilterService.new({sender: members(:f_admin).email})
    receiver_filter = AdminMessagesFilterService.new({receiver: members(:f_admin).email})
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), sender_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [], receiver_filter.inbox_messages_ids(members(:ram), programs(:albers))
  end

  def test_inbox_messages_ids_filtered_by_status
    read_filter = AdminMessagesFilterService.new({status: {read: "1"}})
    unread_filter = AdminMessagesFilterService.new({status: {read: "0"}})
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), read_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [], unread_filter.inbox_messages_ids(members(:ram), programs(:albers))

    message = create_admin_message(sender: members(:f_student))
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), read_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [message].collect(&:id), unread_filter.inbox_messages_ids(members(:ram), programs(:albers))

    message.mark_as_read!(members(:f_admin))
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user), message].collect(&:id), read_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [], unread_filter.inbox_messages_ids(members(:ram), programs(:albers))
  end

  def test_inbox_messages_ids_filtered_by_date_range
    filter = AdminMessagesFilterService.new({date_range: "#{2.days.from_now.strftime('%m/%d/%Y')} - #{10.days.from_now.strftime('%m/%d/%Y')}"})
    message = create_admin_message(sender: members(:f_student))
    message.update_attributes!(created_at: 5.days.from_now)
    assert_equal_unordered [message].collect(&:id), filter.inbox_messages_ids(members(:ram), programs(:albers))
  end

  def test_sent_messages_ids
    filter = AdminMessagesFilterService.new({})
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))
  end

  def test_sent_messages_ids_with_no_message_receivers
    filter = AdminMessagesFilterService.new({})
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:rahim)])
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user), message].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))

    message.message_receivers.delete_all
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user), message].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))
  end

  def test_sent_messages_ids_filtered_by_sender_receiver
    sender_filter = AdminMessagesFilterService.new({sender: members(:f_student).name_with_email})
    receiver_filter = AdminMessagesFilterService.new({receiver: members(:f_student).name_with_email})
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), sender_filter.sent_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), receiver_filter.sent_messages_ids(members(:ram), programs(:albers))

    sender_filter = AdminMessagesFilterService.new({sender: "Test User"})
    receiver_filter = AdminMessagesFilterService.new({receiver: "Test User"})
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), sender_filter.sent_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), receiver_filter.sent_messages_ids(members(:ram), programs(:albers))

    sender_filter = AdminMessagesFilterService.new({sender: "test@chronus.com"})
    receiver_filter = AdminMessagesFilterService.new({receiver: "test@chronus.com"})
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), sender_filter.sent_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), receiver_filter.sent_messages_ids(members(:ram), programs(:albers))

    sender_filter = AdminMessagesFilterService.new({sender: members(:f_admin).email})
    receiver_filter = AdminMessagesFilterService.new({receiver: members(:f_admin).email})
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), sender_filter.sent_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [], receiver_filter.sent_messages_ids(members(:ram), programs(:albers))
  end

  def test_sent_messages_ids_filtered_by_status
    read_filter = AdminMessagesFilterService.new({status: {read: "1"}})
    unread_filter = AdminMessagesFilterService.new({status: {read: "0"}})
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), read_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [], unread_filter.inbox_messages_ids(members(:ram), programs(:albers))

    messages(:second_admin_message).message_receivers.update_all(status: AbstractMessageReceiver::Status::UNREAD)
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), read_filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [messages(:second_admin_message), messages(:reply_to_offline_user)].collect(&:id), unread_filter.inbox_messages_ids(members(:ram), programs(:albers))
  end

  def test_sent_messages_ids_filtered_by_date_range
    filter = AdminMessagesFilterService.new({date_range: "#{2.days.from_now.strftime('%m/%d/%Y')} - #{10.days.from_now.strftime('%m/%d/%Y')}"})
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)])
    message.update_attributes!(created_at: 5.days.from_now)
    assert_equal_unordered [message].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))
  end

  def test_include_system_generated_messages
    filter = AdminMessagesFilterService.new({}, true)
    initial_sent_messages = filter.sent_messages_ids(members(:ram), programs(:albers))
    auto_message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student), members(:ram)], auto_email: true)
    assert_equal_unordered (initial_sent_messages + [auto_message.id]), filter.sent_messages_ids(members(:ram), programs(:albers))

    filter = AdminMessagesFilterService.new({}, false)
    assert_equal_unordered [messages(:first_admin_message), messages(:second_admin_message), messages(:third_admin_message), messages(:reply_to_offline_user)].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))
  end

  def test_admin_sending_admin_message_to_admin
    filter = AdminMessagesFilterService.new({status: {read: "0"}})
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student), members(:ram)])
    assert_equal_unordered [], filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [message].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))

    message.mark_as_read!(members(:ram))
    assert_equal_unordered [], filter.sent_messages_ids(members(:ram), programs(:albers))

    reply = create_admin_message(sender: members(:f_student), parent_id: message.id, root_id: message.id)
    assert_equal_unordered [message, reply].collect(&:id), filter.inbox_messages_ids(members(:ram), programs(:albers))
    assert_equal_unordered [message, reply].collect(&:id), filter.sent_messages_ids(members(:ram), programs(:albers))
  end
end