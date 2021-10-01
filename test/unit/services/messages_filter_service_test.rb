require_relative "./../../test_helper.rb"

class MessagesFilterServiceTest < ActiveSupport::TestCase

  ### members(:f_mentor) ###
  ### Sent: messages(:second_message), messages(:mygroup_mentor_1), messages(:mygroup_mentor_2), messages(:mygroup_mentor_3), messages(:mygroup_mentor_4)
  ### Received: messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2)

  ### members(:f_mentor_student) ###
  ### Sent: messages(:first_message)
  ### Received: messages(:second_message)

  ### members(:f_student) ###
  ### Sent: messages(:first_admin_message)
  ### Received: messages(:third_admin_message)

  def test_inbox_messages_ids
    filter = MessagesFilterService.new({})
    assert_equal_unordered [messages(:meeting_scrap), messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    reply = create_message_reply(messages(:second_message), sender: members(:f_mentor_student))
    assert_equal_unordered [messages(:meeting_scrap), messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2), messages(:second_message), reply].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    reply.mark_deleted!(members(:f_mentor))
    assert_equal_unordered [messages(:meeting_scrap), messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
  end

  def test_inbox_messages_ids_filtered_by_sender
    filter = MessagesFilterService.new({sender: members(:f_mentor_student).email})
    assert_equal_unordered [messages(:first_message)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    filter = MessagesFilterService.new({sender: members(:f_mentor_student).name_with_email})
    assert_equal_unordered [messages(:first_message)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    filter = MessagesFilterService.new({sender: members(:f_mentor).email})
    assert_equal_unordered [], filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
  end

  def test_inbox_messages_ids_filtered_by_sender_ignores_auto_emails
    filter = MessagesFilterService.new({sender: members(:f_admin).email})
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), filter.inbox_messages_ids(members(:f_student), programs(:org_primary))[0]

    auto_message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student)], auto_email: true)
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), filter.inbox_messages_ids(members(:f_student), programs(:org_primary))[0]

    auto_message.update_attributes(auto_email: false)
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message), auto_message].collect(&:id), filter.inbox_messages_ids(members(:f_student), programs(:org_primary))[0]
  end

  def test_inbox_messages_ids_filtered_by_receiver
    filter = MessagesFilterService.new({receiver: members(:f_mentor).email})
    assert_equal_unordered [messages(:meeting_scrap), messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    messages(:first_message).mark_deleted!(members(:f_mentor))
    assert_equal_unordered [messages(:meeting_scrap), messages(:mygroup_student_1), messages(:mygroup_student_2)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    reply = create_message_reply(messages(:first_message), sender: members(:f_mentor_student), receivers: [members(:f_mentor)])
    assert_equal_unordered [messages(:meeting_scrap), messages(:mygroup_student_1), messages(:mygroup_student_2), reply].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
  end

  def test_inbox_messages_ids_filtered_by_status
    read_filter = MessagesFilterService.new({status: {read: "1"}})
    unread_filter = MessagesFilterService.new({status: {read: "0"}})
    assert_equal_unordered [], read_filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
    assert_equal_unordered [messages(:meeting_scrap), messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2)].collect(&:id), unread_filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    messages(:first_message).mark_as_read!(members(:f_mentor))
    assert_equal_unordered [messages(:first_message)].collect(&:id), read_filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
    assert_equal_unordered [messages(:meeting_scrap), messages(:mygroup_student_1), messages(:mygroup_student_2)].collect(&:id), unread_filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    reply = create_message_reply(messages(:first_message), sender: members(:f_mentor_student), receivers: [members(:f_mentor)])
    assert_equal_unordered [], read_filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
    assert_equal_unordered [messages(:meeting_scrap), messages(:first_message), messages(:mygroup_student_1), messages(:mygroup_student_2), reply].collect(&:id), unread_filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
  end

  def test_inbox_messages_ids_filtered_by_date_range
    filter = MessagesFilterService.new({date_range: "#{2.days.ago.strftime('%m/%d/%Y')} - #{2.days.from_now.strftime('%m/%d/%Y')}"})
    message = create_message(sender: members(:robert), receivers: [members(:rahim)])
    assert_equal_unordered [message].collect(&:id), filter.inbox_messages_ids(members(:rahim), programs(:org_primary))[0]

    message.update_attributes(created_at: 5.days.ago)
    assert_equal_unordered [], filter.inbox_messages_ids(members(:rahim), programs(:org_primary))[0]
  end

  def test_inbox_message_ids_when_admin_sends_admin_message_to_admin
    filter = MessagesFilterService.new({status: {read: "0"}})
    message = create_admin_message(sender: members(:f_admin), receivers: [members(:f_student), members(:ram)])
    assert_equal_unordered [message].collect(&:id), filter.inbox_messages_ids(members(:ram), programs(:org_primary))[0]

    message.mark_as_read!(members(:ram))
    assert_equal_unordered [], filter.inbox_messages_ids(members(:ram), programs(:org_primary))[0]

    reply = create_admin_message(sender: members(:f_student), parent_id: message.id, root_id: message.id)
    assert_equal_unordered [message, reply].collect(&:id), filter.inbox_messages_ids(members(:ram), programs(:org_primary))[0]
  end

  def test_inbox_message_ids_multiple_filters
    filter = MessagesFilterService.new({status: {read: "0"}, sender: members(:f_mentor_student).name_with_email})
    assert_equal_unordered [messages(:first_message)].collect(&:id), filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]

    messages(:first_message).mark_as_read!(members(:f_mentor))
    assert_equal_unordered [], filter.inbox_messages_ids(members(:f_mentor), programs(:org_primary))[0]
  end

  def test_sent_messages_ids
    filter = MessagesFilterService.new({})
    assert_equal_unordered [messages(:first_message)].collect(&:id), filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
  end

  def test_sent_message_ids_without_receivers
    filter = MessagesFilterService.new({})
    message = create_message(sender: members(:f_mentor_student), receivers: [members(:rahim)])
    assert_equal_unordered [message, messages(:first_message)].collect(&:id), filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]

    message.message_receivers.delete_all
    assert_equal_unordered [message, messages(:first_message)].collect(&:id), filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
  end

  def test_sent_messages_ids_filtered_by_sender
    filter = MessagesFilterService.new({sender: members(:f_mentor_student).email})
    assert_equal_unordered [messages(:first_message)].collect(&:id), filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]

    filter = MessagesFilterService.new({sender: members(:f_mentor).name_with_email})
    assert_equal_unordered [], filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
  end

  def test_sent_messages_ids_filtered_by_receiver
    filter = MessagesFilterService.new({receiver: members(:f_mentor).email})
    assert_equal_unordered [messages(:first_message)].collect(&:id), filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]

    filter = MessagesFilterService.new({receiver: members(:f_mentor).name_with_email})
    reply = create_message_reply(messages(:second_message), sender: members(:f_mentor_student))
    assert_equal_unordered [messages(:first_message), messages(:second_message), reply].collect(&:id), filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
  end

  def test_sent_messages_ids_filtered_by_status
    read_filter = MessagesFilterService.new({status: {read: "1"}})
    unread_filter = MessagesFilterService.new({status: {read: "0"}})
    assert_equal_unordered [], read_filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
    assert_equal_unordered [], unread_filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]

    reply = create_message_reply(messages(:first_message), sender: members(:f_mentor))
    assert_equal_unordered [], read_filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
    assert_equal_unordered [messages(:first_message), reply].collect(&:id), unread_filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]

    reply.mark_as_read!(members(:f_mentor_student))
    assert_equal_unordered [messages(:first_message), reply].collect(&:id), read_filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
    assert_equal_unordered [], unread_filter.sent_messages_ids(members(:f_mentor_student), programs(:org_primary))[0]
  end

  def test_sent_messages_ids_filtered_by_date_range
    filter = MessagesFilterService.new({date_range: "#{2.days.ago.strftime('%m/%d/%Y')} - #{2.days.from_now.strftime('%m/%d/%Y')}"})
    message = create_message(sender: members(:robert), receivers: [members(:rahim)])
    assert_equal_unordered [message].collect(&:id), filter.sent_messages_ids(members(:robert), programs(:org_primary))[0]

    message.update_attributes(created_at: 5.days.ago)
    assert_equal_unordered [], filter.sent_messages_ids(members(:robert), programs(:org_primary))[0]
  end

  def test_sent_messages_ids_multiple_filters
    filter = MessagesFilterService.new({status: {read: "0"}, sender: members(:f_admin).email})
    assert_equal_unordered [], filter.sent_messages_ids(members(:f_student), programs(:org_primary))[0]

    messages(:third_admin_message).message_receivers.update_all(status: AbstractMessageReceiver::Status::UNREAD)
    assert_equal_unordered [messages(:first_admin_message), messages(:third_admin_message)].collect(&:id), filter.sent_messages_ids(members(:f_student), programs(:org_primary))[0]
  end
end