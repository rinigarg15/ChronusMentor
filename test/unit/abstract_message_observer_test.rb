require_relative './../test_helper.rb'

class AbstractMessageObserverTest < ActiveSupport::TestCase

  def test_airbrake_notification_on_message_destroy
    message = messages(:first_message)
    Airbrake.expects(:notify).times(1)
    message.destroy

    message_2 = messages(:second_message)
    message_2.allow_scrubber_to_destroy = true
    Airbrake.expects(:notify).never
    message_2.destroy
  end

  def test_root
    m1 = create_message
    m2 = create_message(parent: m1)
    m3 = create_message(parent: m2)
    m4 = create_message(parent: m1)
    assert_equal m1, m1.root
    assert_equal m1, m2.root
    assert_equal m1, m3.root
    assert_equal m1, m4.root

    assert_equal [m1.id], m1.message_receivers.pluck(:message_root_id)
    assert_equal [m1.id], m2.message_receivers.pluck(:message_root_id)
    assert_equal [m1.id], m3.message_receivers.pluck(:message_root_id)
    assert_equal [m1.id], m4.message_receivers.pluck(:message_root_id)
  end

  def test_message_creation
    assert_emails 1 do
      create_message(:receiver => members(:f_mentor), :sender => members(:f_student))
    end

    assert_equal_unordered([[users(:f_mentor).email]],
      ActionMailer::Base.deliveries.collect(&:to).last(2))
  end

  def test_creates_new_scrap_recent_activity
    student = users(:f_student)
    mentor = users(:f_mentor)
    @group = create_group(:students => [student], :mentor => mentor, :program => programs(:albers))

    assert_difference 'RecentActivity.count' do
      @scrap = Scrap.create!(:sender => mentor.member, :content => "hello", :subject => "hello", :ref_obj => @group, :program_id => @group.program_id)
    end

    activity = RecentActivity.last
    assert_equal(@scrap, activity.ref_obj)
    assert_equal(RecentActivityConstants::Type::SCRAP_CREATION, activity.action_type)
    assert_equal(mentor, activity.get_user(@group.program))
  end

  def test_scrap_creation_notification
    student_1 = users(:f_student)
    student_2 = users(:rahim)
    mentor = users(:f_mentor_student)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    @group = create_group(:students => [student_1, student_2], :mentor => mentor, :program => programs(:albers))

    assert_difference'ActionMailer::Base.deliveries.size', 2 do
      create_scrap(:group => @group, :sender => student_1.member)
    end
    email = ActionMailer::Base.deliveries[-2]
    assert_equal [student_2.email], email.to
    email = ActionMailer::Base.deliveries[-1]
    assert_equal [mentor.email], email.to
  end

  def test_create_messages_from_scrap
    group = groups(:mygroup)
    t1 = create_mentoring_model_task(group_id: group.id, required: true)
    assert_difference 'Scrap.count', 1 do
      comment = create_task_comment(t1, {notify: 1})
    end
    scrap = Scrap.last
    assert scrap.root?
    scp = scrap.dup
    scp.parent = scrap
    assert_difference 'MentoringModel::Task::Comment.count', 1 do
      scp.save!
    end
    scp = scrap.dup
    scp.root = Scrap.first
    assert_difference 'MentoringModel::Task::Comment.count', 0 do
      scp.save!
    end
  end

  def test_message_is_getting_converted_to_scrap
    meeting = meetings(:f_mentor_mkr_student)
    group = groups(:mygroup)

    Message.any_instance.stubs(:relavant_meetings).returns([meeting])
    Message.any_instance.stubs(:relavant_groups).returns([])

    message = create_message(:receiver => members(:f_mentor), :sender => members(:mkr_student))

    assert_false message.is_a?(Scrap)
    message = AbstractMessage.find(message.id)
    assert message.is_a?(Scrap)
    assert_equal meeting, message.ref_obj

    Message.any_instance.stubs(:relavant_meetings).returns([])
    Message.any_instance.stubs(:relavant_groups).returns([group])

    message = create_message(:receiver => members(:f_mentor), :sender => members(:mkr_student))

    assert_false message.is_a?(Scrap)
    message = AbstractMessage.find(message.id)
    assert message.is_a?(Scrap)
    assert_equal group, message.ref_obj
  end

  def test_assert_push_notifications_on_create
    organization = programs(:org_primary)
    group = groups(:mygroup)

    PushNotifier.expects(:push).once
    programs(:org_primary).messages.create!(:sender => members(:f_mentor_student), :subject => 'Test',:content => 'This is the content', :receivers => [members(:f_mentor)])

    PushNotifier.expects(:push).times(group.members.count - 1)
    create_scrap(:group => group)
  end

  def test_trigger_emails
    Message.any_instance.stubs(:send_progam_level_email?).returns(false)
    assert_emails 1 do
      create_message(:receiver => members(:f_mentor), :sender => members(:f_user))
    end

    email = ActionMailer::Base.deliveries.last
    assert_no_match(/in #{programs(:albers).name}/, get_html_part_from(email))
 
    Message.any_instance.stubs(:send_progam_level_email?).returns(true)
    Message.any_instance.stubs(:context_program).returns(programs(:albers))
    assert_emails 1 do
      create_message(:receiver => members(:f_mentor), :sender => members(:f_user))
    end

    email = ActionMailer::Base.deliveries.last
    assert_match(/in #{programs(:albers).name}/, get_html_part_from(email))
  end
end
