require_relative './../test_helper.rb'

class MentoringModelTaskCommentScrapTest < ActiveSupport::TestCase

  def test_assocication
    group = groups(:mygroup)
    task_1 = create_mentoring_model_task(from_template: false)
    comment1 = create_task_comment(task_1, subject: "Test Comment subject", comment: "Test Comment comment")
    assert_difference 'Scrap.count', 1 do
      assert_difference 'MentoringModelTaskCommentScrap.count', 1 do
        MentoringModel::Task::Comment.delay.create_scrap_from_comment(comment1.id)
     end
    end
    scrap = Scrap.last
    scrap_comment = MentoringModelTaskCommentScrap.last
    assert_equal scrap_comment.scrap, scrap
    assert_equal scrap_comment.comment, comment1
    assert_difference 'Scrap.count', 0 do
      assert_difference 'MentoringModel::Task::Comment.count', 0 do
        scrap_comment.destroy
      end
    end
  end
end
