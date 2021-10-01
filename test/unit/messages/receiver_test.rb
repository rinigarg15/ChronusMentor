require_relative './../../test_helper.rb'

class Messages::ReceiverTest < ActiveSupport::TestCase

  def test_should_not_create_with_out_message
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
      Messages::Receiver.create!
    end
  end

  def test_presence_of_member
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member do
      Messages::Receiver.create!
    end
  end

  def test_should_not_create_a_message_with_org_conflict
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member do
      Messages::Receiver.create!(:member => members(:sarat_mentor_ceg), :message => messages(:first_message))
    end
  end

  def test_mentees_cannot_send_message_to_unconnected_mentors_if_program_does_not_allow_it
	  org = programs(:org_primary)
	  programs(:albers).update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)
    mentor = members(:f_mentor)
    student = members(:student_11)
    assert_false student.connected_with?(mentor)

    m = Message.new(:organization => org, :sender => student, :receivers => [mentor], :subject => "test", :content => "What is this?")
    assert_raise ActiveRecord::RecordInvalid, "You are not allowed to message #{mentor.name}" do
      m.save!
    end
    create_group(:program => programs(:albers), :mentor => users(:f_mentor), :students => [users(:student_11)])
    assert student.reload.connected_with?(mentor.reload)
    assert_difference("Messages::Receiver.count", 1) do
      Message.create!(:organization => org, :sender => student, :receivers => [mentor], :subject => "test", :content => "What is this?")
    end
    # Message becomes a scrap now
    assert_equal([mentor], AbstractMessage.last.receivers)
    assert_equal(student, AbstractMessage.last.sender)
  end

  def test_mentees_cannot_send_message_to_other_mentees_if_program_does_not_allow_it
    org = programs(:org_primary)
    programs(:albers).update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)
    student1 = members(:f_student)
    student2 = members(:student_11)
    m = Message.new(:organization => org, :sender => student1, :receivers => [student2], :subject => "test", :content => "What is this?")
    assert_raise ActiveRecord::RecordInvalid, "You are not allowed to message #{student2.name}" do
      m.save!
    end
    programs(:albers).update_attribute(:allow_user_to_send_message_outside_mentoring_area, true)
    assert_difference("Messages::Receiver.count", 1) do
      Message.create!(:organization => org, :sender => student1, :receivers => [student2], :subject => "test", :content => "What is this?")
    end
    assert_equal([student2], Message.last.receivers)
    assert_equal(student1, Message.last.sender)
  end

  def test_mentees_send_message_to_unconnected_mentors_in_case_of_reply
    org = programs(:org_primary)
    programs(:albers).update_attribute(:allow_user_to_send_message_outside_mentoring_area, false)
    mentor = members(:f_mentor)
    student = members(:student_3)
    assert_false student.connected_with?(mentor)

    msg = create_message(:sender => mentor, :receivers => [student], :subject => "test", :content => "Hi Student")
    assert_difference("Messages::Receiver.count", 1) do
      Message.create!(:organization => org, :sender => student, :receivers => [mentor], :subject => "Re: test", :content => "Thanks mentor", :parent_id => msg.id)
    end
    assert_equal([mentor], Message.last.receivers)
    assert_equal(student, Message.last.sender)
  end

  def test_handle_reply_via_email
    msg_receiver = messages(:first_message).message_receivers.first
    assert msg_receiver.unread?
    assert_not_equal 'some content', Message.last.content
    assert_false msg_receiver.deleted?
    assert msg_receiver.handle_reply_via_email({:content => 'some content'})
    assert_equal 'some content', Message.last.content
    assert msg_receiver.read?

    msg_receiver.mark_deleted!
    assert_equal AbstractMessageReceiver::Status::DELETED, msg_receiver.reload.status
    assert_false msg_receiver.handle_reply_via_email({:content => 'some new content'})
    assert_not_equal 'some new content', Message.last.content
    assert msg_receiver.deleted?
  end
end