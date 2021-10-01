require_relative "./../test_helper.rb"

class MessageTest < ActiveSupport::TestCase

  def test_message_should_have_organization
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :organization do
      Message.create!
    end
  end

  def test_message_should_have_name__email__subject_and_content
    e = assert_raise(ActiveRecord::RecordInvalid) do
      programs(:org_primary).messages.create!
    end

    assert_match(/Subject can't be blank/, e.message)
    assert_match(/Message can't be blank/, e.message)
  end

  def test_message_should_verify_programs
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender do
      assert_no_difference "Message.count" do
        programs(:org_primary).messages.create!(
          sender: members(:arun_ceg), subject: 'Test',
          content: 'This is the content', receivers: [members(:f_mentor)])
      end
    end
  end

  def test_message_creation_success
    assert_emails 1 do
      assert_difference('Message.count') do
        programs(:org_primary).messages.create!(
          sender: members(:f_mentor_student), subject: 'Test',
          content: 'This is the content', receivers: [members(:f_mentor)])
      end
    end

    message = Message.last
    assert_equal 'Test', message.subject
    assert_equal members(:f_mentor_student), message.sender
    assert_equal [members(:f_mentor)], message.receivers
    assert_equal 'This is the content', message.content
  end

  def test_message_update_user_deletion
    assert_emails 1 do
      assert_difference('Message.count') do
        programs(:org_primary).messages.create!(
          sender: members(:f_mentor_student), subject: 'Test',
          content: 'This is the content', receivers: [members(:f_mentor)])
      end
    end

    message = Message.last
    member = message.sender
    e = assert_raise ActiveRecord::RecordInvalid do
      message.update_attributes!(sender_id: '')
    end
    assert_match(/Sender name can't be blank/, e.message)
    message.update_attributes!(sender_name: member.name, sender_id: '')
    assert_nil message.sender
  end

  def test_setters
    m = messages(:first_message)
    assert_equal [members(:f_mentor)], m.receivers
    m.receiver_ids = members(:f_mentor_student).id.to_s
    m.save!
    assert_equal [members(:f_mentor_student)], m.receivers
  end

  def test_build_reply
    m = create_message
    m1 = m.build_reply(m.receivers.first)
    assert_equal m, m1.parent
    assert_equal m.organization, m1.organization
    assert_equal [m.sender], m1.receivers
    assert_equal m.receivers, [m1.sender]
    assert_equal "#{m.subject}", m1.subject

    m2 = m.build_reply(m.sender)
    assert_equal m.receivers, m2.receivers
    assert_equal m.sender, m2.sender
  end

  def test_participant_member_ids
    message = messages(:first_message)
    assert_equal_unordered [message.sender.id, message.receiver_ids].flatten, message.participant_member_ids
  end

  def test_relavant_groups
    student = members(:f_student)
    mentor = members(:f_mentor)
    mentor_student = members(:f_mentor_student)

    assert_empty create_message(sender: mentor, receiver: mentor_student).relavant_groups
    assert_equal [groups(:group_nwen)], create_message(sender: mentor, receiver: student).relavant_groups

    Group.any_instance.stubs(:scraps_enabled?).returns(true)
    assert_equal [groups(:group_nwen), groups(:group_pbe)], create_message(sender: mentor, receiver: student).relavant_groups
    assert_empty create_message(sender: mentor, receiver: student, context_program: programs(:albers)).relavant_groups
    assert_equal [groups(:group_nwen)], create_message(sender: mentor, receiver: student, context_program: programs(:nwen)).relavant_groups

    programs(:nwen).update_attribute(:engagement_type, nil)
    programs(:nwen).enable_feature(FeatureName::CALENDAR, false)
    assert_empty create_message(sender: mentor, receiver: student, context_program: programs(:nwen)).relavant_groups
  end

  def test_relavant_meetings
    m1 = messages(:first_message)
    m1.program = programs(:albers)
    m1.save

    meeting = create_meeting(members: [members(:f_mentor_student), members(:f_mentor)],
                owner_id: members(:f_mentor_student).id, program_id: programs(:albers).id, start_time: Time.now, end_time: Time.now + 5.hours)
    assert_equal [], m1.relavant_meetings

    Meeting.stubs(:upcoming_recurrent_meetings).with([meeting]).returns([{meeting: meeting}])
    meeting.update_attribute(:group_id, nil)
    assert_equal [meeting], m1.relavant_meetings

    Meeting.stubs(:upcoming_recurrent_meetings).with([meeting]).returns([])
    assert_equal [], m1.relavant_meetings
  end

  def test_convert_to_scrap
    message = messages(:second_message)
    grp = groups(:mygroup)
    assert message.is_a?(Message)
    assert_false message.is_a?(Scrap)

    message.convert_to_scrap(grp)
    scrap = Scrap.find(message.id)
    assert_false scrap.is_a?(Message)
    assert scrap.is_a?(Scrap)
    assert_equal grp, scrap.ref_obj

    message = messages(:first_message)
    meeting = meetings(:f_mentor_mkr_student)
    assert message.is_a?(Message)
    assert_false message.is_a?(Scrap)

    message.convert_to_scrap(meeting)
    scrap = Scrap.find(message.id)
    assert_false scrap.is_a?(Message)
    assert scrap.is_a?(Scrap)
    assert_equal meeting, scrap.ref_obj
  end

  def test_attach_to_related_group
    message = messages(:first_message)
    group = create_group(student: users(:f_mentor_student), mentor: users(:f_mentor))

    message.attach_to_related_group
    assert_equal Scrap.find(message.id).ref_obj, group
  end

  def test_attach_to_related_meeting
    message = messages(:first_message)
    meeting = meetings(:f_mentor_mkr_student)

    Message.any_instance.stubs(:relavant_meetings).returns([meeting])
    message.attach_to_related_meetings
    assert_equal meeting, Scrap.find(message.id).ref_obj
  end

  def test_can_be_replied
    message = messages(:first_message)
    receiver = message.receivers.first
    assert message.can_be_replied?(receiver)
    assert message.can_be_replied?(message.sender)
    assert_false message.can_be_replied?(members(:f_student))

    message.mark_deleted!(receiver)
    assert_false message.reload.can_be_replied?(receiver)

    message.update_attribute(:sender_id, nil)
    assert_false message.can_be_replied?(receiver)
  end
end