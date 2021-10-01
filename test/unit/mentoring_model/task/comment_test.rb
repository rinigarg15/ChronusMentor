require_relative './../../../test_helper.rb'

class MentoringModel::Task::CommentTest < ActiveSupport::TestCase

  def test_association
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: false})
    assert_equal [comment1], task_1.comments
    comment2 = create_task_comment(task_1, {notify: true})
    assert_equal [comment1, comment2], task_1.comments
    assert_equal group.members.first.member, comment1.sender

    assert_equal comment1.mentoring_model_task, task_1
    assert_equal comment2.mentoring_model_task, task_1
    assert_nil comment1.scrap
    assert_equal Scrap.last, comment2.scrap

    assert_difference 'Scrap.count', 1 do
        MentoringModel::Task::Comment.create_scrap_from_comment(comment1.id)
    end

    assert_equal Scrap.last, comment1.reload.scrap
    assert_equal MentoringModelTaskCommentScrap.last, comment1.mentoring_model_task_comment_scrap
    
    assert_difference 'MentoringModel::Task.count', 0 do
      comment2.destroy
    end
  end

  def test_recent
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)
    comment1 = create_task_comment(task_1, {notify: 0})
    sleep 1.5
    comment2 = create_task_comment(task_1, {notify: 1})
    comment_ids = MentoringModel::Task::Comment.recent.pluck(:id)
    assert comment_ids.index(comment2.id) < comment_ids.index(comment1.id)
  end

  def test_comment_attachment_type_supported
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: 0, attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text")})
    assert comment1.valid?
  end

  def test_comment_attachment_file_name_disallowed
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: 0, attachment: fixture_file_upload(File.join("files", "test_php.txt"), "text/text")})
    assert comment1.valid?
    comment1.attachment_file_name = "test_php.php"
    assert_false comment1.valid?
    assert comment1.errors[:attachment_file_name].present?
  end

  def test_comment_attachment_type_unsupported
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: 0, attachment: fixture_file_upload(File.join("files", "test_php.txt"), "text/text")})
    comment1.attachment_content_type = "application/x-php"
    assert_false comment1.valid?
  end

  def test_comment_attachment_fails_size_gt_20mb
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: 0, attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text")})

    comment1.attachment_file_size = 21.megabytes
    assert_false comment1.valid?
    assert_equal ["should be within 20 MB"], comment1.errors.messages[:attachment_file_size]
  end

  def test_comment_attachment_doesnt_fail_size_lt_5mb
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    task_2 = create_mentoring_model_task(from_template: true)

    assert_equal [], task_1.comments
    assert_equal [], task_2.comments

    comment1 = create_task_comment(task_1, {notify: 0, attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text")})
    comment1.attachment_file_size = 4.megabytes
    assert comment1.valid?
  end

  def test_create_scrap_from_comment
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, content: "Test Comment comment")
    assert_difference 'Scrap.count', 1 do
        MentoringModel::Task::Comment.create_scrap_from_comment(comment1.id)
    end
    scrap = Scrap.last

    assert_equal comment1.sender, scrap.sender
    assert_equal comment1.program, scrap.program
    assert_equal comment1.content, scrap.content
    assert_equal comment1, scrap.comment
    assert_equal groups(:mygroup), scrap.ref_obj
    assert_equal group.members.collect(&:member) - [scrap.sender], scrap.message_receivers.collect(&:member)
  end

  def test_comment_get_attachment
    group = groups(:group_5)
    task_1 = create_mentoring_model_task(from_template: false, group: group, user: group.students.first)
    comment1 = create_task_comment(task_1, {notify: 0, attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text")})
    comment1.attachment = comment1.get_attachment
    assert_equal "text/text", comment1.attachment_content_type
    assert_equal "some_file.txt", comment1.attachment_file_name
  end

  def test_create_scrap_from_comment_with_attachement_and_getting_it_from_s3
    group = groups(:group_5)
    task_1 = create_mentoring_model_task(from_template: false, group: group, user: group.students.first)
    comment1 = create_task_comment(task_1, content: "Test Comment comment", attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    MentoringModel::Task::Comment.any_instance.stubs(:get_attachment).returns(fixture_file_upload(File.join("files", "some_file.txt"), "text/unsupported_content_type"))
    assert_difference 'Scrap.count', 1 do
      MentoringModel::Task::Comment.create_scrap_from_comment(comment1.id)
    end
    scrap = Scrap.last
    assert_equal comment1.attachment_file_size, scrap.attachment_file_size
    assert_equal comment1.attachment_content_type, scrap.attachment_content_type
    assert_equal comment1.content, scrap.content
  end
end