require_relative './../../../test_helper.rb'

class MentoringModel::Task::CommentsControllerTest < ActionController::TestCase

  def test_create
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK_COMMENT).once
    assert_difference 'MentoringModel::Task::Comment.count', 1 do
      post :create, xhr: true, params: { task_id: task_1.id, group_id: group.id, mentoring_model_task_comment: {content: "This is test content", notify: 0}, format: :js}
    end
    comment = MentoringModel::Task::Comment.last
    assert_equal task_1, comment.mentoring_model_task
    assert_equal "This is test content", comment.content
    assert_equal users(:f_mentor).member, comment.sender
    assert_nil comment.scrap
    assert_equal [comment], assigns(:comments_and_checkins)
  end

  def test_create_for_non_audit_message
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    current_user_is :f_mentor
    assert_false group.program.organization.audit_user_communication?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK_COMMENT).once
    assert_difference 'MentoringModel::Task::Comment.count', 1 do
      assert_no_difference 'Scrap.count' do
        assert_difference("ActionMailer::Base.deliveries.size", 0) do
          post :create, xhr: true, params: { task_id: task_1.id, group_id: group.id, mentoring_model_task_comment: {content: "This is test content", notify: 0}, format: :js}
        end
      end
    end
    comment = MentoringModel::Task::Comment.last
    assert_equal task_1, comment.mentoring_model_task
    assert_equal "This is test content", comment.content
    assert_equal users(:f_mentor).member, comment.sender
    assert_nil comment.scrap
    assert_equal [comment], assigns(:comments_and_checkins)
  end

  def test_create_for_audit_message
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    current_user_is :f_mentor
    group.program.organization.update_attribute(:audit_user_communication, true)
    assert group.program.organization.audit_user_communication?

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK_COMMENT).once
    assert_difference 'Scrap.count', 1 do
      assert_difference 'MentoringModel::Task::Comment.count', 1 do
        assert_difference("ActionMailer::Base.deliveries.size", 1) do
          post :create, xhr: true, params: { task_id: task_1.id, group_id: group.id, mentoring_model_task_comment: {content: "This is test content", notify: 0}, format: :js, home_page_view: true}
        end
      end
    end
    comment = MentoringModel::Task::Comment.last
    assert_equal task_1, comment.mentoring_model_task
    assert_equal "This is test content", comment.content
    assert_equal users(:f_mentor).member, comment.sender
    assert_equal Scrap.last, comment.scrap
    assert_equal [comment], assigns(:comments_and_checkins)
    assert assigns(:home_page_view)
  end

  def test_create_with_multiline_content
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK_COMMENT).once
    assert_difference 'MentoringModel::Task::Comment.count', 1 do
      post :create, xhr: true, params: { task_id: task_1.id, group_id: group.id, mentoring_model_task_comment: {content: "test1\ntest2\n\r\ntest3", notify: 0}, format: :js}
    end
    assert_match /test1.*br.*test2.*br.*br.*test3/, response.body
  end

  def test_destroy_by_owner
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, {notify: false, sender: members(:f_mentor)})
    current_user_is :f_mentor

    assert_difference 'MentoringModel::Task::Comment.count', -1 do
      post :destroy, xhr: true, params: { :id => comment1.id, :task_id => task_1.id, :group_id => group.id, home_page_view: true}
    end
    assert assigns(:home_page_view)
  end

  def test_destroy_by_non_owner
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, {notify: false, sender: members(:f_student)})
    current_user_is :f_mentor

    assert_permission_denied do
      post :destroy, xhr: true, params: { :id => comment1.id, :task_id => task_1.id, :group_id => group.id}
    end
  end

  def test_create_failure_with_unsupported_file
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK_COMMENT).never
    assert_no_difference 'MentoringModel::Task::Comment.count', 1 do
      post :create, xhr: true, params: { task_id: task_1.id, group_id: group.id, mentoring_model_task_comment: {content: "This is test content", notify: 0, :attachment => fixture_file_upload(File.join('files', 'test_php.php'), 'application/x-php')}, format: :js}
    end
    assert_equal assigns(:error_message), "Attachment content type is restricted and Attachment file name is invalid"
  end

  def test_create_failure_with_big_file
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    current_user_is :f_mentor

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_TASK_COMMENT).never
    assert_no_difference 'MentoringModel::Task::Comment.count', 1 do
      post :create, xhr: true, params: { task_id: task_1.id, group_id: group.id, mentoring_model_task_comment: {content: "This is test content", notify: 0, :attachment => fixture_file_upload(File.join('files', 'TEST.JPG'), 'image/jpeg')}, format: :js}
    end
    assert_equal assigns(:error_message), "Attachment file size should be within #{AttachmentSize::END_USER_ATTACHMENT_SIZE/ONE_MEGABYTE} MB"
  end

end