require_relative './../test_helper.rb'

class ScrapsControllerTest < ActionController::TestCase
  include ScrapExtensions
  def setup
    super
    @group = groups(:mygroup)
    @student = @group.students.first
    @mentor = @group.mentors.first
    @subject = "Hello"
    @content = "This is the message content"
  end

  def test_get_scraps_for_homepage
    initial_scraps_count = @group.scraps.count
    s1 = nil
    s2 = nil
    time_traveller(2.days.from_now) do
      s1 = create_scrap(group: @group)
      s2 = create_scrap(group: @group, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end

    current_user_is users(:mkr_student)
    member = members(:mkr_student)
    get :index, xhr: true, params: { group_id: @group.id, home_page: true}
    assert_response :success
    assert_equal_unordered assigns(:scraps_ids).collect(&:root_id), [s1.id, s2.id]
  end

  def test_index
    initial_scraps_count = @group.scraps.count
    s1 = nil
    s2 = nil
    time_traveller(2.days.ago) do
      s1 = create_scrap(group: @group)
      s2 = create_scrap(group: @group, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end
    current_user_is @mentor
    member = @mentor.member
    preloaded_hash = get_preloaded_scraps_hash(@group.scraps.pluck(:root_id), member)

    @controller.expects(:update_login_count).once
    @controller.expects(:update_last_visited_tab).once

    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :index, xhr: true, params: { group_id: @group.id, src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, from_find_new: "form_find_new"}
      end
    end
    assert_response :success
    assert_equal @group, assigns(:group)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s1.id)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s2.id)
    assert 8, assigns(:scraps_ids).count
    assert_false assigns(:scraps_attachments)[s1.id]
    assert assigns(:scraps_attachments)[s2.id]
    assert_equal s1.created_at.to_i, assigns(:scraps_last_created_at)[s1.id].to_i
    assert_equal @group, assigns(:ref_obj)
    assert_nil assigns(:meeting)
    assert_nil assigns(:page_controls_allowed)
    assert_nil assigns(:current_occurrence_time)
    assert_nil assigns(:new_scrap)
    assert_nil assigns(:from_find_new)
    assert_nil assigns(:is_group_profile_view)
    assert assigns(:preloaded)
    assert_equal preloaded_hash[:siblings_index], assigns(:scraps_siblings_index)
    assert_equal preloaded_hash[:viewable_scraps_hash], assigns(:viewable_scraps_hash)
    assert_equal preloaded_hash[:deleted_scraps_hash], assigns(:deleted_scraps_hash)
    assert_equal preloaded_hash[:unread_scraps_hash], assigns(:unread_scraps_hash)
    assert assigns(:src_path), EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST
  end

  def test_index_pending_group_specific_instance_variables
    group = groups(:group_pbe_0)
    mentor = group.mentors.first
    current_user_is mentor
    member = mentor.member
    preloaded_hash = get_preloaded_scraps_hash(group.scraps.pluck(:root_id), member)

    Group.any_instance.expects(:scraps_enabled?).returns(true)
    @controller.expects(:update_login_count).never
    @controller.expects(:update_last_visited_tab).never
    @controller.expects(:mark_group_activity).never

    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'Connection::Activity.count' do
        get :index, xhr: true, params: { group_id: group.id, src: "src_path", from_find_new: "from_find_new"}
      end
    end

    assert_equal "src_path", assigns(:src_path)
    assert_equal "from_find_new", assigns(:from_find_new)
    assert assigns(:is_group_profile_view)
  end

  def test_index_not_accessible_if_scraps_disabled
    group = groups(:group_pbe_0)
    mentor = group.mentors.first
    current_user_is mentor
    member = mentor.member
    preloaded_hash = get_preloaded_scraps_hash(group.scraps.pluck(:root_id), member)

    assert_false group.scraps_enabled?
    assert_permission_denied do
      get :index, xhr: true, params: { group_id: group.id, src: "src_path", from_find_new: "form_find_new"}
    end
  end

  def test_index_for_meeting_scraps
    current_user_is :mkr_student

    meeting = meetings(:f_mentor_mkr_student)
    s1 = nil
    s2 = nil
    time_traveller(2.days.ago) do
      s1 = create_scrap(group: meeting)
      s2 = create_scrap(group: meeting, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end

    get :index, xhr: true, params: { meeting_id: meeting.id, current_occurrence_time: meeting.occurrences.first.start_time}

    assert_response :success
    assert_equal meeting, assigns(:meeting)
    assert_nil assigns(:group)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s1.id)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s2.id)
    assert 2, assigns(:scraps_ids).count
    assert_false assigns(:scraps_attachments)[s1.id]
    assert assigns(:scraps_attachments)[s2.id]
    assert_equal s1.created_at.to_i, assigns(:scraps_last_created_at)[s1.id].to_i
    assert_equal meeting, assigns(:ref_obj)
    assert_nil meeting.state
    assert assigns(:page_controls_allowed)
    assert_equal meeting.occurrences.first.start_time, assigns(:current_occurrence_time)
    assert_equal meeting, assigns(:new_scrap).ref_obj
    assert assigns(:back_link).present?
  end

  def test_index_for_completed_meeting
    current_user_is :mkr_student

    meeting = meetings(:f_mentor_mkr_student)

    meeting.update_attribute(:state, Meeting::State::COMPLETED)
    s1 = nil
    s2 = nil
    time_traveller(2.days.ago) do
      s1 = create_scrap(group: meeting)
      s2 = create_scrap(group: meeting, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end

    Meeting.any_instance.stubs(:member_can_send_new_message?).returns(true)

    get :index, xhr: true, params: { meeting_id: meeting.id, current_occurrence_time: meeting.occurrences.first.start_time}

    assert_response :success
    assert_equal meeting, assigns(:meeting)
    assert_nil assigns(:group)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s1.id)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s2.id)
    assert 2, assigns(:scraps_ids).count
    assert_false assigns(:scraps_attachments)[s1.id]
    assert assigns(:scraps_attachments)[s2.id]
    assert_equal s1.created_at.to_i, assigns(:scraps_last_created_at)[s1.id].to_i
    assert_equal meeting, assigns(:ref_obj)
    assert_not_nil meeting.state
    assert assigns(:page_controls_allowed)
    assert_equal meeting.occurrences.first.start_time, assigns(:current_occurrence_time)
    assert_equal meeting, assigns(:new_scrap).ref_obj
  end

  def test_only_member_can_view_scraps
    current_user_is :f_student

    meeting = meetings(:f_mentor_mkr_student)
    s1 = nil
    s2 = nil
    time_traveller(2.days.ago) do
      s1 = create_scrap(group: meeting)
      s2 = create_scrap(group: meeting, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end

    assert_permission_denied do
      get :index, xhr: true, params: { meeting_id: meeting.id}
    end
  end

  def test_admin_can_view_scraps
    current_user_is :f_admin

    meeting = meetings(:f_mentor_mkr_student)
    s1 = nil
    s2 = nil
    time_traveller(2.days.ago) do
      s1 = create_scrap(group: meeting)
      s2 = create_scrap(group: meeting, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end

    get :index, params: { meeting_id: meeting.id, current_occurrence_time: meeting.occurrences.first.start_time}

    assert_response :success
    assert_equal meeting, assigns(:meeting)
    assert_nil assigns(:group)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s1.id)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s2.id)
    assert 2, assigns(:scraps_ids).count
    assert_false assigns(:scraps_attachments)[s1.id]
    assert assigns(:scraps_attachments)[s2.id]
    assert_equal s1.created_at.to_i, assigns(:scraps_last_created_at)[s1.id].to_i
    assert_equal meeting, assigns(:ref_obj)

    assert_nil assigns(:page_controls_allowed)
    assert_equal meeting.occurrences.first.start_time, assigns(:current_occurrence_time)
    assert_nil assigns(:new_scrap)
    assert assigns(:is_admin_view)
  end

  def test_index_rejects_deleted_messages
    initial_scraps_count = @group.scraps.count
    s1 = nil
    s2 = nil
    s3 = nil
    time_traveller(2.days.ago) do
      s1 = create_scrap(group: @group, sender: @student.member)
      s2 = create_scrap(group: @group)
    end
    time_traveller(1.day.ago) do
      s3 = s2.build_reply(@student.member)
      s3.content = @content
      s3.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
      s3.save!
    end
    s1.mark_deleted!(@mentor.member)

    current_user_is @mentor
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :index, xhr: true, params: { group_id: @group.id}
      end
    end
    assert_response :success
    assert assigns(:scraps_ids).collect(&:root_id).include?(s2.id)
    assert assigns(:scraps_attachments)[s2.id]
    assert_equal s3.created_at.to_i, assigns(:scraps_last_created_at)[s2.id].to_i
    assert_nil assigns(:back_link)
  end

  def test_show_scraps_of_group_member
    current_user_is :f_mentor
    s1, s2, s3, s4 = create_temporary_scraps

    get :index, params: { group_id: groups(:mygroup).id}
    assert_equal assigns(:scraps_ids).collect(&:root_id), [s1, s4, s2].collect(&:id)
    assert_equal_hash assigns(:scraps_attachments), {s1.id => true, s4.id => false, s2.id => false}
    assert_equal assigns(:scraps_last_created_at)[s1.id].to_i, s3.created_at.to_i
  end

  def test_show_scraps_of_group_member_without_any_receivers
    group = groups(:group_pbe_0)
    sender = group.mentors.first
    group.update_members([sender], [], nil)
    group.mentoring_model.update_columns(allow_forum: false, allow_messaging: true)
    current_user_is sender


    s1 = create_scrap(group: group, sender: sender.member)
    s2 = create_scrap(group: group, sender: sender.member)
    get :index, params: { group_id: group.id}
    assert_equal_unordered [s1, s2].collect(&:id), assigns(:scraps_ids).collect(&:root_id)
  end

  def test_ignore_deleted_scraps_of_group_member
    s1, s2, s3, s4 = create_temporary_scraps
    s3.mark_deleted!(members(:f_mentor))
    s4.mark_deleted!(members(:f_mentor))

    current_user_is :f_mentor
    get :index, params: { group_id: groups(:mygroup).id}
    assert_equal assigns(:scraps_ids).collect(&:root_id), [s2, s1].collect(&:id)
    assert_equal_hash assigns(:scraps_attachments), {s1.id => false, s2.id => false}
    assert_equal assigns(:scraps_last_created_at)[s1.id].to_i, s1.created_at.to_i
  end

  def test_include_all_non_deleted_member_scraps
    s1, s2, s3, s4 = create_temporary_scraps
    s3.mark_deleted!(members(:f_mentor))
    s4.mark_deleted!(members(:f_mentor))

    # Other member of group
    current_user_is :mkr_student
    get :index, params: { group_id: groups(:mygroup).id}
    assert_equal assigns(:scraps_ids).collect(&:root_id), [s1, s4, s2].collect(&:id)
    assert_equal_hash assigns(:scraps_attachments), {s1.id => true, s4.id => false, s2.id => false}
    assert_equal assigns(:scraps_last_created_at)[s1.id].to_i, s3.created_at.to_i
  end

  def test_show_all_scraps_for_admin
    s1, s2, s3, s4 = create_temporary_scraps
    s1.mark_deleted!(members(:mkr_student))
    s2.mark_deleted!(members(:mkr_student))
    s3.mark_deleted!(members(:f_mentor))
    s4.mark_deleted!(members(:f_mentor))

    # Admin - not a group member, sees all the scraps
    current_user_is :f_admin
    programs(:albers).confidentiality_audit_logs.create!(user_id: users(:f_admin).id, reason: "This is another reason", group_id: groups(:mygroup).id)
    get :index, params: { group_id: groups(:mygroup).id}
    assert_equal assigns(:scraps_ids).collect(&:root_id), [s1, s4, s2].collect(&:id)
    assert_equal_hash assigns(:scraps_attachments), {s1.id => true, s4.id => false, s2.id => false}
    assert_equal assigns(:scraps_last_created_at)[s1.id].to_i, s3.created_at.to_i
  end

  def test_index_for_admin
    initial_scraps_count = @group.scraps.count
    s1 = nil
    s2 = nil
    s3 = nil
    time_traveller(1.day.ago) do
      s1 = create_scrap(group: @group, sender: @student.member)
    end
    time_traveller(3.days.ago) do
      s2 = create_scrap(group: @group)
    end
    time_traveller(2.days.ago) do
      s3 = create_scrap(group: @group, parent_id: s2.id, root_id: s2.id, attachment: fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text'))
    end
    s1.mark_deleted!(@mentor.member)

    current_user_is :f_admin
    get :index, xhr: true, params: { group_id: @group.id}
    assert_response :success
    assert assigns(:scraps_ids).collect(&:root_id).include?(s1.id)
    assert assigns(:scraps_ids).collect(&:root_id).include?(s2.id)
    assert_false assigns(:scraps_attachments)[s1.id]
    assert assigns(:scraps_attachments)[s2.id]
    assert_equal s3.created_at.to_i, assigns(:scraps_last_created_at)[s2.id].to_i
  end

  def test_create_scrap
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_emails 1 do
      assert_difference 'Scrap.count' do
        assert_difference 'RecentActivity.count' do
          assert_difference 'Connection::Activity.count' do
            post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, group_id: @group.id}
          end
        end
      end
    end
    assert_response :success
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::SCRAP_CREATION
    scrap = assigns(:scrap)
    assert_equal @content, scrap.content
    assert_equal @subject, scrap.subject
    assert_equal @mentor.member, scrap.sender
    assert_equal [@student.member], scrap.receivers
    assert_false scrap.attachment?
  end

  def test_create_meeting_scrap
    current_user_is :mkr_student
    meeting = meetings(:f_mentor_mkr_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_emails 1 do
      assert_difference 'Scrap.count' do
        assert_difference 'RecentActivity.count' do
          post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, meeting_id: meeting.id}
        end
      end
    end

    assert_response :success
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::SCRAP_CREATION
    scrap = assigns(:scrap)
    assert_equal @content, scrap.content
    assert_equal @subject, scrap.subject
    assert_equal members(:mkr_student), scrap.sender
    assert_equal [members(:f_mentor)], scrap.receivers
    assert_false scrap.attachment?
    assert scrap.is_meeting_message?
    assert_equal scrap.ref_obj, meeting
  end

  def test_create_scrap_with_inactive_members
    current_user_is @mentor
    group = groups(:mygroup)
    group.mentors = [users(:f_mentor), users(:ram)]
    group.save!
    members(:ram).update_attribute :state, Member::Status::SUSPENDED
    users(:ram).update_attribute :state, User::Status::SUSPENDED
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_emails 1 do
      assert_difference 'Scrap.count' do
        assert_difference 'RecentActivity.count' do
          assert_difference 'Connection::Activity.count' do
            post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, group_id: group.id}
          end
        end
      end
    end
    assert_response :success
    assert_equal Scrap.last.receivers, [members(:mkr_student)]
  end

  def test_create_scrap_with_pending_users
    current_user_is @mentor
    group = groups(:mygroup)
    group.mentors = [users(:f_mentor), users(:ram)]
    group.save!
    users(:ram).update_attribute :state, User::Status::PENDING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_emails 2 do
      assert_difference 'Scrap.count' do
        assert_difference 'RecentActivity.count' do
          assert_difference 'Connection::Activity.count' do
            post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, group_id: group.id}
          end
        end
      end
    end
    assert_response :success
    assert_equal_unordered Scrap.last.receivers, [members(:mkr_student),  members(:ram)]
  end

  def test_create_scrap_failure_with_unsupported_attachment
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_no_difference 'Scrap.count' do
      assert_no_difference 'RecentActivity.count' do
        assert_no_difference 'Connection::Activity.count' do
          post :create, xhr: true, params: { scrap: {content: @content, subject: @subject, attachment:  fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')}, group_id: @group.id}
        end
      end
    end
    assert_equal assigns(:error_message), "Attachment content type is restricted and Attachment file name is invalid"
  end

  def test_create_scrap_failure_with_big_attachment
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_no_difference 'Scrap.count' do
      assert_no_difference 'RecentActivity.count' do
        assert_no_difference 'Connection::Activity.count' do
          post :create, xhr: true, params: { scrap: {content: @content, subject: @subject, attachment:  fixture_file_upload(File.join('files', 'TEST.JPG'), 'image/jpeg')}, group_id: @group.id}
        end
      end
    end
    assert_equal assigns(:error_message), "Attachment file size should be within #{AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE} MB"
  end

  def test_create_scrap_reply_from_inbox
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).once
    assert_emails 1 do
      assert_difference 'Scrap.count' do
        assert_difference 'RecentActivity.count' do
          assert_difference 'Connection::Activity.count' do
            post :create, params: { scrap: {content: @content, subject: @subject, parent_id: messages(:mygroup_student_1).id,
              attachment: fixture_file_upload(File.join('files', 'SOMEspecialcharacters@#$%\'123_test.txt'), 'text/text')}, from_inbox: 'true'
            }
          end
        end
      end
    end
    scrap = assigns(:scrap)
    assert_redirected_to  message_path(scrap, is_inbox: true, reply: true)
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::SCRAP_CREATION
    assert_equal @content, scrap.content
    assert_equal @subject, scrap.subject
    assert_equal @mentor.member, scrap.sender
    assert_equal [@student.member], scrap.receivers
    assert_equal messages(:mygroup_student_1), scrap.parent
    assert_equal messages(:mygroup_student_1), scrap.root
    assert_equal 'SOMEspecialcharacters123_test.txt', scrap.attachment_file_name
  end

  def test_create_scrap_reply_from_inbox_failure
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_emails 0 do
      assert_no_difference 'Scrap.count' do
        post :create, params: { scrap: {content: @content, subject: @subject, parent_id: messages(:mygroup_student_1).id,
          attachment: fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')}, from_inbox: 'true'
        }
      end
    end
    assert_redirected_to  root_organization_path
  end

  def test_create_scrap_reply_from_mentoring_area
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).once
    assert_emails 1 do
      assert_difference 'Scrap.count' do
        post :create, xhr: true, params: { scrap: {content: @content, subject: @subject, parent_id: messages(:mygroup_student_2).id}, from_inbox: 'false'}
      end
    end
    assert_response :success
    scrap = assigns(:scrap)
    assert_equal @content, scrap.content
    assert_equal @subject, scrap.subject
    assert_equal @mentor.member, scrap.sender
    assert_equal [@student.member], scrap.receivers
    assert_equal messages(:mygroup_student_2), scrap.parent
    assert_equal messages(:mygroup_student_2), scrap.root
    assert_false scrap.attachment?
  end

  def test_create_scrap_with_virus
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    Scrap.any_instance.expects(:save).at_least(1).raises(VirusError)
    assert_no_difference 'Scrap.count' do
      post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, group_id: @group.id}
    end
    assert_response :success
    assert_equal "Our security system has detected the presence of a virus in the attachment.", assigns(:error_message)
  end

  # Non-member of the group cannot create a scrap.
  def test_create_scrap_permission_denied
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, group_id: @group.id}
    end
  end

  def test_create_meeting_scrap_permission_denied
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, meeting_id: meetings(:f_mentor_mkr_student).id}
    end
  end

  def test_create_meeting_scrap_permission_denied_for_completed_meeting
    current_user_is :mkr_student
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_attribute(:state, Meeting::State::COMPLETED)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, meeting_id: meeting.id}
    end
  end

  def test_create_scrap_not_allowed_in_closed_group
    current_user_is @mentor
    @group.terminate!(users(:f_admin), "Test reason", @group.program.permitted_closure_reasons.first.id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      post :create, xhr: true, params: { scrap: {content: @content, subject: @subject}, group_id: @group.id}
    end
  end

  def test_create_scrap_reply_failure
    current_user_is :f_mentor_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      post :create, xhr: true, params: { scrap: { parent_id: messages(:mygroup_mentor_1) }}
    end
  end

  # Non Admin - Non receiver should not see the scrap
  def test_show_auth
    current_user_is :f_mentor_student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      get :show, params: { id: messages(:mygroup_mentor_1).id, from_inbox: 'true'}
    end
  end

  def test_show_from_inbox
    scrap = messages(:mygroup_student_1)
    assert scrap.unread?(@mentor.member)
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).twice
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :show, params: { id: scrap.id, from_inbox: 'true'}
      end
    end
    assert_response :success
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert_equal scrap.ref_obj, RecentActivity.last.ref_obj
    assert scrap.reload.read?(@mentor.member)
    assert_false assigns(:preloaded)
    assert_equal scrap, assigns(:scrap)

    # Do NOT expose the reply link for a scrap when its associated group is terminated, but deletion is allowed always
    @group.terminate!(users(:f_admin), "Reason for termination", @group.program.permitted_closure_reasons.first.id)
    get :show, params: { id: scrap.id, from_inbox: 'true'}
    assert_response :success
    assert scrap.reload.read?(@mentor.member)
    assert_equal scrap, assigns(:scrap)
  end

  def test_show_from_inbox_for_suspended_user
    scrap = messages(:mygroup_student_1)
    assert scrap.unread?(@mentor.member)
    current_user_is @mentor
    @mentor.update_attribute :state, User::Status::SUSPENDED
    assert @mentor.suspended?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).once

    get :show, params: { id: scrap.id, from_inbox: 'true'}

    assert_response :success
    assert scrap.reload.read?(@mentor.member)
    assert_equal scrap, assigns(:scrap)
    assert @group.active?
    assert_false scrap.can_be_replied?(@mentor.member)
    # Do NOT expose the reply link for a scrap when its associated with an active group but expose for a suspended user.
  end

  def test_show_from_inbox_for_deleted_user
    scrap = messages(:mygroup_student_1)
    member = members(:f_mentor)
    assert scrap.unread?(member)
    current_program_is :albers
    current_member_is member

    Member.any_instance.stubs(:user_in_program).returns(nil)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).once
    get :show, params: { id: scrap.id, from_inbox: 'true'}

    assert_response :success
    assert scrap.reload.read?(member)
    assert_equal scrap, assigns(:scrap)
    assert @group.active?
  end

  def test_show_from_inbox_for_non_logged_in_user
    current_program_is :albers
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).never
    get :show, params: { id: messages(:mygroup_student_1).id, from_inbox: 'true'}
    assert_redirected_to login_path
  end

  def test_show_from_mentoring_area
    scrap = messages(:mygroup_student_1)
    member = @mentor.member
    assert scrap.unread?(member)
    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).twice
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :show, xhr: true, params: { id: scrap.id}
      end
    end
    preloaded_hash = get_preloaded_scraps_hash(scrap.root_id, member)
    assert_response :success
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert_equal scrap.ref_obj, RecentActivity.last.ref_obj
    assert scrap.reload.read?(member)
    assert assigns(:preloaded)
    assert_equal preloaded_hash[:siblings_index], assigns(:scraps_siblings_index)
    assert_equal preloaded_hash[:viewable_scraps_hash], assigns(:viewable_scraps_hash)
    assert_equal preloaded_hash[:deleted_scraps_hash], assigns(:deleted_scraps_hash)
    assert_equal scrap, assigns(:scrap)
    assert response.body.match /reply_link/
    assert response.body.match /delete_link/

    @group.terminate!(users(:f_admin), "Reason for termination", @group.program.permitted_closure_reasons.first.id)
    get :show, xhr: true, params: { id: scrap.id}
    assert_response :success
    assert scrap.reload.read?(@mentor.member)
    assert_equal scrap, assigns(:scrap)
    assert_false response.body.match /reply_link/
    assert response.body.match /delete_link/
  end

  def test_show_for_admin
    scrap = messages(:mygroup_student_1)
    current_user_is :f_admin
    old_last_activity_at = scrap.ref_obj.last_activity_at
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).once
    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'Connection::Activity.count' do
        get :show, xhr: true, params: { id: scrap.id}
      end
    end
    assert_response :success
    assert_equal old_last_activity_at, scrap.ref_obj.reload.last_activity_at
  end

  def test_show_deleted_scrap
    scrap = messages(:mygroup_student_1)
    assert scrap.unread?(@mentor.member)
    scrap.mark_deleted!(@mentor.member)

    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).never
    assert_permission_denied do
      get :show, params: { id: scrap.id, from_inbox: 'true'}
    end
  end

  def test_show_when_group_deleted
    scrap = messages(:mygroup_student_1)
    scrap.update_attribute(:ref_obj_id, nil)

    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).never
    get :show, params: { id: scrap.id, from_inbox: 'true'}
    assert_response :success
    assert scrap.reload.read?(@mentor.member)
    assert_equal scrap, assigns(:scrap)
  end

  def test_show_to_sender
    current_user_is @student
    scrap = Scrap.create!(sender: @student.member, subject: @subject, content: @content, ref_obj: @group, receivers: [@mentor.member], program: @group.program)
    assert scrap.read?(scrap.sender)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).once
    get :show, params: { id: scrap.id}
    assert_response :success
    assert scrap.unread?(@mentor.member)
    assert_equal scrap, assigns(:scrap)
  end

  def test_show_reply
    filters_params = { search_filters: {
      sender: @student.member.name_with_email,
      receiver: @mentor.member.name_with_email,
      status: { read: 1 }
    } }
    scrap = messages(:mygroup_mentor_1)
    scrap_reply = scrap.build_reply(@student.member)
    scrap_reply.content = "This is a reply"
    scrap_reply.save!
    assert scrap_reply.unread?(scrap.sender)

    current_user_is @student
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA).once
    get :show, params: { id: scrap_reply.id, from_inbox: 'true', is_inbox: 'true', filters_params: filters_params }
    assert_response :success
    assert scrap_reply.reload.read?(@student)
    assert_equal scrap_reply, assigns(:scrap)
    assert_equal messages_path( { organization_level: true, tab: MessageConstants::Tabs::INBOX }.merge(filters_params)), assigns(:back_link)[:link]
    assert assigns(:inbox)
  end

  def test_destroy_scrap_from_mentoring_area
    scrap = messages(:mygroup_student_1)
    current_user_is @mentor
    assert_no_difference 'Scrap.count' do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Connection::Activity.count' do
          delete :destroy, xhr: true, params: { id: scrap.id, group_id: @group.id}
        end
      end
    end
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert_equal scrap.ref_obj, assigns(:group)
    assert_equal scrap.ref_obj, RecentActivity.last.ref_obj
    assert scrap.reload.deleted?(@mentor.member)
  end

  def test_destroy_scrap_from_inbox
    scrap = messages(:mygroup_student_1)
    current_user_is @mentor
    assert_no_difference 'Scrap.count' do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Connection::Activity.count' do
          delete :destroy, params: { id: scrap.id, group_id: @group.id}
        end
      end
    end
    assert_redirected_to messages_path
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert_equal scrap.ref_obj, RecentActivity.last.ref_obj, assigns(:group)
    assert_equal "The message has been deleted", flash[:notice]
    assert scrap.reload.deleted?(@mentor.member)
  end

  def test_destroy_scrap_with_replies_from_inbox
    scrap = messages(:mygroup_student_1)
    scrap_reply = scrap.build_reply(@mentor.member)
    scrap_reply.content = "This is a reply"
    scrap_reply.save!

    current_user_is @mentor
    assert_no_difference 'Scrap.count' do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Connection::Activity.count' do
          delete :destroy, params: { id: scrap.id, group_id: @group.id}
        end
      end
    end
    assert_response :redirect # Not redirected to messages_path
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert_equal scrap.ref_obj, RecentActivity.last.ref_obj, assigns(:group)
    assert_equal "The message has been deleted", flash[:notice]
    assert scrap.reload.deleted?(@mentor.member)
  end

  def test_destroy_by_sender
    current_user_is @student
    assert_permission_denied do
      delete :destroy, params: { id: messages(:mygroup_student_1).id, group_id: @group.id}
    end
  end

  def test_destroy_by_suspended_sender
    scrap = messages(:mygroup_student_1)
    current_user_is @mentor
    @mentor.update_attribute(:state, User::Status::SUSPENDED)
    assert_no_difference 'Scrap.count' do
      delete :destroy, params: { id: scrap.id, group_id: @group.id}
    end
    assert_redirected_to messages_path
    assert_equal "The message has been deleted", flash[:notice]
    assert scrap.reload.deleted?(@mentor.member)
  end

  def test_destroy_scrap_by_non_owner
    current_user_is :ram
    assert_permission_denied do
      delete :destroy, xhr: true, params: { id: messages(:mygroup_mentor_1).id, group_id: @group.id}
    end
  end

  def test_reply_scrap_from_mentoring_area
    scrap = messages(:mygroup_student_1)
    current_user_is @mentor
    get :reply, xhr: true, params: { id: scrap.id, group_id: @group.id}
    assert_equal scrap, assigns(:scrap)
  end

  def test_reply_scrap_by_non_owner
    current_user_is :ram
    assert_permission_denied do
      get :reply, xhr: true, params: { id: messages(:mygroup_mentor_1).id, group_id: @group.id}
    end
  end

  private

  def create_temporary_scraps
    group = groups(:mygroup)
    group.scraps.destroy_all

    s1 = create_scrap(group: group, sender: members(:f_mentor))

    s2 = nil
    time_traveller(1.days.from_now) do
      s2 = create_scrap(group: group, sender: members(:f_mentor))
    end

    s3 = nil
    time_traveller(3.days.from_now) do
      s3 = create_scrap(group: group, sender: members(:mkr_student))
    end
    s3.parent_id = s3.root_id = s1.id
    s3.attachment = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    s3.save!

    s4 = nil
    time_traveller(2.days.from_now) do
      s4 = create_scrap(group: group, sender: members(:mkr_student))
    end
    [s1, s2, s3, s4]
  end

end