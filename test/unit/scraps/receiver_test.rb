require_relative './../../test_helper.rb'

class Scraps::ReceiverTest < ActiveSupport::TestCase
  def setup
    super
    @group = create_group(
      :students => [users(:f_student)],
      :mentors => [users(:f_mentor)],
      :program => programs(:albers))

    @meeting = meetings(:f_mentor_mkr_student)

    @scrap = Scrap.create!(
      :sender => members(:f_student),
      :subject => "Subject",
      :content => "This is the content for Scrap.",
      :ref_obj => @group,
      :program => programs(:albers)
    )

    @meeting_scrap = Scrap.create!(
      :sender => members(:f_mentor),
      :subject => "Subject",
      :content => "This is the content for Scrap.",
      :ref_obj => @meeting,
      :program => programs(:albers)
    )
  end
  
  def test_successful_create
    assert_difference 'Scraps::Receiver.count' do
      assert_nothing_raised do
        Scraps::Receiver.create!(
          :message => @scrap,
          :member => members(:f_mentor)
        )
      end
    end
  end

  def test_message_is_required
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
      Scraps::Receiver.create!(:member => members(:f_mentor))
    end
  end

  def test_member_is_required
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :member do
      Scraps::Receiver.create!(:message => @scrap)
    end
  end

  def test_receiver_should_belong_to_the_group
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Scraps::Receiver.create!(
        :message => @scrap,
        :member => members(:mentor_1)
      )
    end
    assert_match(/Receiver does not belong to the mentoring group/, e.message)
  end

  def test_receiver_should_belong_to_the_meeting
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Scraps::Receiver.create!(
        :message => @meeting_scrap,
        :member => members(:mentor_1)
      )
    end
    assert_match(/Receiver does not belong to the meeting/, e.message)
  end

  def test_receiver_user
    scrap = Scrap.first
    assert_equal scrap.message_receivers.first.receiver_user, users(:mkr_student)

    msg_receiver = messages(:mygroup_mentor_1).message_receivers.first
    msg_receiver.message = @meeting_scrap
    msg_receiver.save
    assert_equal msg_receiver.receiver_user, users(:mkr_student)    
  end

  def test_handle_reply_via_email
    msg_receiver = messages(:mygroup_mentor_1).message_receivers.first
    assert msg_receiver.unread?
    assert_not_equal 'some content', Scrap.last.content
    assert_false msg_receiver.deleted?
    assert msg_receiver.handle_reply_via_email({:content => 'some content'})
    assert_equal 'some content', Scrap.last.content
    assert msg_receiver.read?

    msg_receiver.mark_deleted!
    assert_equal AbstractMessageReceiver::Status::DELETED, msg_receiver.reload.status
    assert_false msg_receiver.handle_reply_via_email({:content => 'some new content'})
    assert_not_equal 'some new content', Scrap.last.content
    assert msg_receiver.deleted?
  end

  def test_handle_reply_via_email_for_meeting_message_receiver
    msg_receiver = messages(:mygroup_mentor_1).message_receivers.first
    msg_receiver.message = @meeting_scrap
    msg_receiver.save

    assert msg_receiver.unread?
    assert_not_equal 'some content', Scrap.last.content
    assert_false msg_receiver.deleted?
    assert msg_receiver.handle_reply_via_email({:content => 'some content'})
    assert_equal 'some content', Scrap.last.content
    assert msg_receiver.read?

    Scrap.any_instance.stubs(:can_be_replied?).with(msg_receiver.member).returns(false)

    assert_false msg_receiver.handle_reply_via_email({:content => 'some new content', :subject => 'some subject'})
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match "or the user you are trying to contact is not part of the program", mail_content
  end

  def test_handle_reply_via_email_for_meeting_message_receiver_for_suspended_user
    msg_receiver = messages(:mygroup_mentor_1).message_receivers.first
    msg_receiver.message = @meeting_scrap
    msg_receiver.save

    assert msg_receiver.unread?
    assert_not_equal 'some content', Scrap.last.content
    assert_false msg_receiver.deleted?
    assert msg_receiver.handle_reply_via_email({:content => 'some content'})
    assert_equal 'some content', Scrap.last.content
    assert msg_receiver.read?

    Scrap.any_instance.stubs(:can_be_replied?).with(msg_receiver.member).returns(false)

    receiver_user = msg_receiver.member.users.first
    AbstractMessage.any_instance.stubs(:get_user).returns(receiver_user)

    receiver_user.update_attribute(:state, User::Status::SUSPENDED)

    assert_no_difference "ActionMailer::Base.deliveries.size" do
      assert_false msg_receiver.handle_reply_via_email({:content => 'some new content', :subject => 'some subject'})
    end
  end
end