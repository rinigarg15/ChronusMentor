require_relative './../../../test_helper.rb'

class MentoringModel::Task::CommentObserverTest < ActiveSupport::TestCase

  def test_after_create_no_scrap_create
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment", notify: true, attachment: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png') )
    comment1.destroy
    assert_nothing_raised do
      assert_no_emails do
        MentoringModel::Task::Comment.delay.create_scrap_from_comment(comment1.id)
      end
    end

    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment", notify: false)
  end

  def test_after_create_no_scrap_create_with_nil
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment", notify: true)
    comment1.destroy
    assert_nothing_raised do
      assert_no_emails do
        MentoringModel::Task::Comment.delay.create_scrap_from_comment(comment1.id)
      end
    end

    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment", notify: false)
  end

  def test_after_create_with_scrap_create_with_nil
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment", notify: true)
    comment1.destroy
    assert_nothing_raised do
      assert_no_emails do
        MentoringModel::Task::Comment.delay.create_scrap_from_comment(comment1.id)
      end
    end

    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment", notify: true)
  end
end