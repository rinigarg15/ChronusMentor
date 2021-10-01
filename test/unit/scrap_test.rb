require_relative "./../test_helper.rb"

class ScrapTest < ActiveSupport::TestCase
  include ScrapExtensions

  def setup
    super
    @sender = members(:f_student)
    @group = create_group(
      students: [users(:f_student)],
      mentors: [users(:f_mentor)],
      program: programs(:albers))
    @meeting = meetings(:f_mentor_mkr_student)
    @subject = "Subject"
    @content = "This is the content for Scrap."
    @program = programs(:albers)
  end

  def test_successful_create
    assert_difference 'Scrap.count' do
      assert_nothing_raised do
        Scrap.create!(
          sender: @sender,
          subject: @subject,
          content: @content,
          ref_obj: @group,
          program: @program
        )
      end
    end

    assert_equal @group, Scrap.last.ref_obj
  end

  def test_ref_obj_is_required
    assert_no_difference 'Scrap.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :ref_obj do
        Scrap.create!(
          sender: @sender,
          subject: @subject,
          content: @content
        )
      end
    end
  end

  def test_sender_is_required
    assert_no_difference 'Scrap.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender do
        Scrap.create!(
          subject: @subject,
          content: @content,
          ref_obj: @group
        )
      end
    end
  end

  def test_subject_and_content_required
    assert_no_difference 'Scrap.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :content do
        Scrap.create!(
          sender: @sender,
          ref_obj: @group,
          subject: @subject
        )
      end

      assert_raise_error_on_field ActiveRecord::RecordInvalid, :subject do
        Scrap.create!(
          sender: @sender,
          ref_obj: @group,
          content: @content
        )
      end
    end
  end

  def test_sender_should_belong_to_the_group
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Scrap.create!(
        sender: members(:mentor_1),
        subject: @subject,
        content: @content,
        ref_obj: @group
      )
    end
    assert_match(/Sender does not belong to the mentoring group/, e.message)
  end

  def test_sender_should_belong_to_the_meeting
    e = assert_raise(ActiveRecord::RecordInvalid) do
      Scrap.create!(
        program: @program,
        sender: members(:mentor_1),
        subject: @subject,
        content: @content,
        ref_obj: @meeting
      )
    end
    assert_match(/Sender does not belong to the meeting/, e.message)
  end

  def test_check_group_allows_scraps
    Group.any_instance.stubs(:scraps_enabled?).returns(false)
    e = assert_raise ActiveRecord::RecordInvalid do
      Scrap.create!(
        program: @program,
        sender: @group.mentors.first.member,
        subject: @subject,
        content: @content,
        ref_obj: @group
      )
    end
    assert_match(/Messaging is not allowed in the mentoring connection./, e.message)

    Group.any_instance.stubs(:scraps_enabled?).returns(true)
    assert_difference "Scrap.count" do
      Scrap.create!(
        program: @program,
        sender: @group.mentors.first.member,
        subject: @subject,
        content: @content,
        ref_obj: @group
      )
    end
  end

  def test_comment_association
    group = groups(:mygroup)
    t1 = create_mentoring_model_task(group_id: group.id, required: true)
    comment = create_task_comment(t1)
    scrap1 = create_scrap(group: groups(:mygroup), sender: members(:f_mentor))
    scrap1.comment = comment
    scrap1.save!
    assert_equal scrap1.comment, comment
    assert_equal scrap1.mentoring_model_task_comment_scrap, MentoringModelTaskCommentScrap.last
    assert_no_difference 'Scrap.count' do
      assert_difference 'MentoringModelTaskCommentScrap.count', -1 do
        comment.destroy
      end
    end
    assert_nil scrap1.reload.comment
  end

  def test_of_member_in_ref_obj_scope
    group = groups(:multi_group)
    s1 = create_scrap(group: group, sender: members(:psg_mentor1))
    s2 = create_scrap(group: group, sender: members(:psg_mentor2)); s2.update_attribute(:parent_id, s1.id)
    assert_equal_unordered [s1, s2], Scrap.of_member_in_ref_obj(members(:psg_mentor1).id, group.id, Group.to_s)

    s2.mark_deleted!(members(:psg_mentor1))
    assert_equal_unordered [s1], Scrap.of_member_in_ref_obj(members(:psg_mentor1).id, group.id, Group.to_s)

    s3 = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert_equal_unordered [s3, messages(:meeting_scrap)], Scrap.of_member_in_ref_obj(members(:f_mentor).id, @meeting.id, Meeting.to_s)

    mentor = group.mentors.first
    group.status = Group::Status::PENDING
    group.update_members([mentor], [], nil)

    s4 = create_scrap(group: group, sender: mentor.member)
    assert Scrap.of_member_in_ref_obj(mentor.member_id, group.id, Group.name).include?(s4)
  end

  def test_created_in_date_range_scope
    time_traveller(2.days.from_now) do
      create_scrap(group: groups(:mygroup))
    end
    assert_equal 0, Scrap.created_in_date_range(Time.now.utc..1.day.from_now).count
    assert_equal 1, Scrap.created_in_date_range(Time.now.utc..3.day.from_now).count
  end

  def test_receiving_users
    scrap = Scrap.first
    assert_equal [users(:mkr_student)], scrap.receiving_users

    scrap = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert_equal [users(:mkr_student)], scrap.receiving_users
    assert_equal [users(:f_mentor)], scrap.receiving_users(users(:mkr_student))
  end

  def test_receiving_active_users
    users(:mkr_student).update_attribute :state, User::Status::SUSPENDED
    assert_empty Scrap.first.receiving_users
  end

  def test_receiving_pending_users
    users(:mkr_student).update_attribute :state, User::Status::PENDING
    assert_equal [users(:mkr_student)], Scrap.first.receiving_users
  end

  def test_receiver_names
    scrap_1 = create_scrap(group: groups(:mygroup), sender: members(:f_mentor))
    assert_equal "mkr_student madankumarrajan", scrap_1.receiver_names(users(:f_mentor))

    scrap_2 = create_scrap(group: groups(:multi_group), sender: members(:psg_mentor1))
    assert_equal "studa psg, studb psg, studc psg, PSG mentorb and PSG mentorc", scrap_2.receiver_names(users(:psg_mentor1))

    scrap = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert_equal "Good unique name", scrap.receiver_names(users(:mkr_student))
  end

  def test_has_group_access
    group = groups(:mygroup)
    scrap = create_scrap(group: group, sender: members(:f_mentor))
    assert_false scrap.has_group_access?(members(:psg_mentor1)) # not a member of group
    assert scrap.has_group_access?(members(:mkr_student))

    group.stubs(:scraps_enabled?).returns(false)
    assert_false scrap.has_group_access?(members(:mkr_student))

    group.stubs(:scraps_enabled?).returns(true)
    group.terminate!(users(:f_admin), "Test termination reason", group.program.permitted_closure_reasons.first.id)
    assert_false scrap.has_group_access?(members(:mkr_student)) # non-active group

    group.stubs(:open?).returns(true)
    assert scrap.has_group_access?(members(:mkr_student))

    AbstractMessage.any_instance.stubs(:get_user).returns(users(:mkr_student))
    users(:mkr_student).update_attribute(:state, User::Status::SUSPENDED)
    assert_false scrap.has_group_access?(members(:mkr_student))
  end

  def test_has_meeting_access
    scrap = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert scrap.has_meeting_access?(members(:f_mentor))
    assert scrap.has_meeting_access?(members(:mkr_student))
    assert_false scrap.has_meeting_access?(members(:f_admin))

    @meeting.update_attribute(:state, Meeting::State::COMPLETED)
    assert_false scrap.has_meeting_access?(members(:mkr_student))

    @meeting.update_attribute(:state, nil)
    @meeting.update_attribute(:active, false)
    assert_false scrap.has_meeting_access?(members(:mkr_student))

    @meeting.update_attribute(:active, true)
    assert scrap.has_meeting_access?(members(:mkr_student))

    AbstractMessage.any_instance.stubs(:get_user).returns(users(:mkr_student))
    users(:mkr_student).update_attribute(:state, User::Status::SUSPENDED)
    assert_false scrap.has_meeting_access?(members(:mkr_student))
  end

  def test_is_admin_viewing
    scrap = messages(:mygroup_mentor_1)
    assert scrap.is_admin_viewing?(members(:f_admin))
    scrap.update_attribute(:ref_obj_id, nil)
    assert scrap.is_admin_viewing?(members(:f_admin))

    scrap = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert scrap.is_admin_viewing?(members(:f_admin))
    assert_false scrap.is_admin_viewing?(members(:mkr_student))
  end

  def test_is_group_message
    scrap = create_scrap(group: @group, sender: members(:f_mentor))
    assert scrap.is_group_message?
    assert_false scrap.is_meeting_message?
  end

  def test_is_meeting_message
    scrap = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert_false scrap.is_group_message?
    assert scrap.is_meeting_message?
  end

  def test_can_be_viewed
    scrap = create_scrap(group: groups(:multi_group), sender: members(:psg_mentor1))
    assert_equal_unordered [members(:psg_mentor2), members(:psg_mentor3), members(:psg_student1), members(:psg_student2), members(:psg_student3)], scrap.receivers
    assert scrap.can_be_viewed?(members(:psg_mentor3))
    assert scrap.can_be_viewed?(members(:psg_student1))
    assert scrap.can_be_viewed?(members(:anna_univ_admin)) # admin
    assert_false scrap.can_be_viewed?(members(:anna_univ_mentor)) # not a receiver

    root_ids = groups(:multi_group).scraps.pluck(:root_id)
    # with options
    # mentor
    preloaded_hash = get_preloaded_scraps_hash(root_ids, members(:psg_mentor3))
    options = { preloaded: true, has_receiver: preloaded_hash[:viewable_scraps_hash][scrap.id].present?, is_deleted: preloaded_hash[:deleted_scraps_hash][scrap.id].present? }
    assert scrap.can_be_viewed?(members(:psg_mentor3), options)

    # student
    preloaded_hash = get_preloaded_scraps_hash(root_ids, members(:psg_student1))
    options = { preloaded: true, has_receiver: preloaded_hash[:viewable_scraps_hash][scrap.id].present?, is_deleted: preloaded_hash[:deleted_scraps_hash][scrap.id].present? }
    assert scrap.can_be_viewed?(members(:psg_student1), options)

    # admin
    preloaded_hash = get_preloaded_scraps_hash(root_ids, members(:anna_univ_admin))
    options = { preloaded: true, has_receiver: preloaded_hash[:viewable_scraps_hash][scrap.id].present?, is_deleted: preloaded_hash[:deleted_scraps_hash][scrap.id].present? }
    assert scrap.can_be_viewed?(members(:anna_univ_admin), options)

    # not a receiver
    preloaded_hash = get_preloaded_scraps_hash(root_ids, members(:anna_univ_mentor))
    options = { preloaded: true, has_receiver: preloaded_hash[:viewable_scraps_hash][scrap.id].present?, is_deleted: preloaded_hash[:deleted_scraps_hash][scrap.id].present? }
    assert_false scrap.can_be_viewed?(members(:anna_univ_mentor), options)

    scrap.mark_deleted!(members(:psg_mentor3))
    assert_false scrap.reload.can_be_viewed?(members(:psg_mentor3)) # receiver - deleted
    assert scrap.can_be_viewed?(members(:psg_mentor2))
    assert scrap.can_be_viewed?(members(:psg_student1))
    assert scrap.can_be_viewed?(members(:anna_univ_admin))

    # with options
    # receiver - deleted
    preloaded_hash = get_preloaded_scraps_hash(root_ids, members(:psg_mentor3))
    options = { preloaded: true, has_receiver: preloaded_hash[:viewable_scraps_hash][scrap.id].present?, is_deleted: preloaded_hash[:deleted_scraps_hash][scrap.id].present? }
    assert_false scrap.reload.can_be_viewed?(members(:psg_mentor3), options)

    # admin
    preloaded_hash = get_preloaded_scraps_hash(root_ids, members(:anna_univ_admin))
    options = { preloaded: true, has_receiver: preloaded_hash[:viewable_scraps_hash][scrap.id].present?, is_deleted: preloaded_hash[:deleted_scraps_hash][scrap.id].present? }
    assert scrap.can_be_viewed?(members(:anna_univ_admin), options)
  end

  def test_can_be_replied
    scrap = create_scrap(group: @meeting, sender: members(:f_mentor))
    assert scrap.can_be_replied?(members(:mkr_student))
    assert scrap.can_be_replied?(scrap.sender)
    assert_false scrap.can_be_replied?(members(:f_admin))

    Meeting.any_instance.stubs(:member_can_send_new_message?).returns(false)
    assert_false scrap.can_be_replied?(members(:mkr_student))

    scrap = messages(:mygroup_mentor_1)
    assert_false scrap.can_be_replied?(members(:psg_mentor1)) # not a member of group
    assert scrap.can_be_replied?(members(:mkr_student))

    scrap.update_attribute(:ref_obj_id, nil)
    assert_false scrap.can_be_replied?(members(:mkr_student)) # group deleted

    user = members(:mkr_student).user_in_program(scrap.program)
    user.update_attribute :state, User::Status::SUSPENDED
    assert_false user.active_or_pending?
    assert_false scrap.can_be_replied?(members(:mkr_student))
  end

  def test_can_be_deleted
    scrap = create_scrap(group: @group, sender: @member)
    assert scrap.can_be_deleted?(members(:f_mentor))
    assert_false scrap.can_be_deleted?(@member)
    assert_false scrap.can_be_deleted?(members(:f_admin))

    options = {
      preloaded: true,
      has_receiver: true,
      is_deleted: true
    }
    assert_false scrap.can_be_deleted?(members(:f_student), options)
  end

  def test_build_reply
    group = groups(:multi_group)
    scrap = create_scrap(group: group, sender: members(:psg_mentor1))
    assert_equal_unordered [members(:psg_mentor2), members(:psg_mentor3), members(:psg_student1), members(:psg_student2), members(:psg_student3)], scrap.receivers
    scrap_reply = scrap.build_reply(members(:psg_mentor2))
    assert_equal scrap, scrap_reply.parent
    assert_equal_unordered [members(:psg_mentor1), members(:psg_mentor3), members(:psg_student1), members(:psg_student2), members(:psg_student3)], scrap_reply.receivers
    assert scrap.subject, scrap_reply.subject

    scrap_reply_2 = scrap.build_reply(scrap.sender)
    assert_equal_unordered [members(:psg_mentor2), members(:psg_mentor3), members(:psg_student1), members(:psg_student2), members(:psg_student3)], scrap_reply_2.receivers
  end

  def test_add_to_activity_log
    s1 = create_scrap(group: groups(:multi_group), sender: members(:psg_mentor1))
    assert_difference "ActivityLog.count" do
      s1.add_to_activity_log
    end
  end

  def test_create_comment_from_scrap
    group = groups(:mygroup)
    t1 = create_mentoring_model_task(group_id: group.id, required: true)
    comment = create_task_comment(t1)
    scrap1 = create_scrap(group: groups(:mygroup), sender: members(:f_mentor))
    scrap1.comment = comment
    scrap1.save!

    scrap2 = create_scrap(group: groups(:mygroup), sender: members(:f_mentor), subject: "Comment subject", content: "Comment Content")
    scrap2.update_attribute(:parent_id, scrap1.id)
    scrap2.update_attribute(:root_id, scrap1.id)
    assert_difference 'MentoringModel::Task::Comment.count', 1 do
      scrap2.create_comment_from_scrap
    end
    comment = MentoringModel::Task::Comment.last
    assert_equal scrap2, comment.scrap
    assert_equal scrap2.sender, comment.sender
    assert_equal scrap2.program, comment.program
    assert_equal "Comment Content", comment.content
    assert_equal scrap2.attachment.url, comment.attachment.url
    assert_equal scrap1.comment.mentoring_model_task, comment.mentoring_model_task
  end

  def test_create_comment_from_scrap_with_attachment_from_S3_download
    group = groups(:group_5)
    t1 = create_mentoring_model_task(group: group, user: group.students.first, required: true)
    comment = create_task_comment(t1)
    Scrap.any_instance.stubs(:get_attachment).returns(fixture_file_upload(File.join("files", "some_file.txt"), "text/unsupported_content_type"))
    scrap1 = create_scrap(group: groups(:group_5), sender: group.students.first.member)
    scrap1.comment = comment
    scrap1.save!

    scrap2 = create_scrap(group: group, sender: group.students.first.member, subject: "Comment subject", content: "Comment Content", attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    scrap2.update_attribute(:parent_id, scrap1.id)
    scrap2.update_attribute(:root_id, scrap1.id)
    assert_difference 'MentoringModel::Task::Comment.count', 1 do
      scrap2.create_comment_from_scrap
    end

    comment = MentoringModel::Task::Comment.last
    assert_equal scrap2.attachment_file_size, comment.attachment_file_size
    assert_equal scrap2.attachment_content_type, comment.attachment_content_type
    assert_equal scrap2.content, comment.content
  end

  def test_get_attachment
    scrap = Scrap.first
    scrap.attachment = fixture_file_upload(File.join("files", "some_file.txt"), "text/text")
    scrap.save!
    assert_equal scrap.attachment, scrap.get_attachment
    assert_equal "text/text", scrap.attachment_content_type
    assert_equal "some_file.txt", scrap.attachment_file_name
  end

  def test_sibling_has_attachment
    group = groups(:multi_group)
    m1 = create_scrap(group: group)
    m2 = create_scrap(group: group, sender: members(:psg_mentor1))
    m2.update_attributes(parent_id: m1.id, root_id: m1.id, attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    assert m1.sibling_has_attachment?(members(:psg_mentor2))

    # with options
    preloaded_hash = get_preloaded_scraps_hash(group.scraps.pluck(:root_id), members(:psg_mentor2))
    options = {
      preloaded: true,
      siblings_index: preloaded_hash[:siblings_index],
      viewable_scraps_hash: preloaded_hash[:viewable_scraps_hash],
      deleted_scraps_hash: preloaded_hash[:deleted_scraps_hash]
    }
    assert m1.sibling_has_attachment?(members(:psg_mentor2), options)

    # mark the message as deleted
    m2.mark_deleted!(members(:psg_mentor2))
    assert_false m1.sibling_has_attachment?(members(:psg_mentor2))

    # with options
    preloaded_hash = get_preloaded_scraps_hash(group.scraps.pluck(:root_id), members(:psg_mentor2))
    options = {
      preloaded: true,
      siblings_index: preloaded_hash[:siblings_index],
      viewable_scraps_hash: preloaded_hash[:viewable_scraps_hash],
      deleted_scraps_hash: preloaded_hash[:deleted_scraps_hash]
    }
    assert_false m1.sibling_has_attachment?(members(:psg_mentor2), options)
  end
end