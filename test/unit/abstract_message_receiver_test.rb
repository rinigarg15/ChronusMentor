require_relative './../test_helper.rb'

class AbstractMessageReceiverTest < ActiveSupport::TestCase

  def test_uniqueness_of_member
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member_id do
      Messages::Receiver.create!(:message => messages(:first_message), :member => members(:f_mentor))
    end
  end

  def test_create_success
    assert_nothing_raised do
      Messages::Receiver.create!(:message => messages(:first_message), :member => members(:f_mentor_student))
    end
  end

  def test_read_unread_deleted_and_markings
    msg_receiver = messages(:first_message).message_receivers.first
    assert_equal AbstractMessageReceiver::Status::UNREAD, msg_receiver.status
    assert_false msg_receiver.read?
    assert msg_receiver.unread?
    assert_false msg_receiver.deleted?

    msg_receiver.mark_as_read!
    assert_equal AbstractMessageReceiver::Status::READ, msg_receiver.reload.status
    assert msg_receiver.read?
    assert_false msg_receiver.unread?
    assert_false msg_receiver.deleted?

    msg_receiver.mark_deleted!
    assert_equal AbstractMessageReceiver::Status::DELETED, msg_receiver.reload.status
    assert_false msg_receiver.read?
    assert_false msg_receiver.unread?
    assert msg_receiver.deleted?
  end

  def test_message_sent_to_suspended_member
    message = messages(:first_message)
    member = members(:f_mentor_student)

    message_receiver = Messages::Receiver.new(message: message, member: member)
    assert message_receiver.valid?
    message_receiver.save!
    member.update_attribute :state, Member::Status::SUSPENDED
    assert message_receiver.reload.valid?
    message_receiver.destroy

    message_receiver = Messages::Receiver.new(message: message, member: member)
    assert_false message_receiver.valid?
    assert_equal ["is not active"], message_receiver.errors[:member]
    message.update_attribute :sender, members(:f_admin)
    message_receiver = Messages::Receiver.new(message: message, member: member)
    assert message_receiver.valid?
  end

  def test_scope_unread
    member = members(:f_mentor_student)
    assert_equal [messages(:second_message).message_receivers.first.id], member.message_receivers.unread.collect(&:id)
    messages(:second_message).mark_as_read!(member)
    assert_equal [], member.reload.message_receivers.unread
    messages(:second_message).mark_deleted!(member)
    assert_equal [], member.reload.message_receivers.unread
  end

  def test_scope_read
    member = members(:f_mentor_student)
    assert_equal [messages(:second_message).message_receivers.first.id], member.message_receivers.unread.collect(&:id)
    messages(:second_message).mark_as_read!(member)
    assert_equal [messages(:second_message).message_receivers.first.id], member.reload.message_receivers.read.collect(&:id)
  end

  def test_scope_deleted
    member = members(:f_mentor_student)
    assert_equal [messages(:second_message).message_receivers.first.id], member.message_receivers.unread.collect(&:id)
    messages(:second_message).mark_deleted!(member)
    assert_equal [messages(:second_message).message_receivers.first.id], member.reload.message_receivers.deleted.collect(&:id)
  end

  def test_offline
    assert_false messages(:first_message).message_receivers.first.offline?
    assert_false messages(:first_admin_message).message_receivers.first.offline?
    assert messages(:reply_to_offline_user).message_receivers.first.offline?
  end
end