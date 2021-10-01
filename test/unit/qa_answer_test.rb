require_relative './../test_helper.rb'

class QaAnswerTest < ActiveSupport::TestCase
  def test_validate_user
    question = create_qa_question(:program => programs(:ceg), :user => users(:arun_ceg))
    user = users(:f_mentor)
    assert_not_equal programs(:ceg), user.program
    qa_answer = QaAnswer.new(:qa_question => question, :user => user, :content => "Answer")
    assert_false qa_answer.valid?
    assert qa_answer.errors[:user]
  end

  def test_ratings
    answer = create_qa_answer
    user = users(:f_admin)
    assert_equal 0, answer.rating
    assert_equal 0, answer.score

    answer.toggle_helpful!(user)
    assert answer.reload.helpful?(user)
    assert_equal 1, answer.score

    answer.toggle_helpful!(user)
    assert !answer.reload.helpful?(user)
    assert_equal 0, answer.score
    # User can unmark helpful only once
    assert !answer.reload.helpful?(user)
    assert_equal 0, answer.score

    # User of some other program cant change rating
    answer.toggle_helpful!(users(:arun_ceg))
    assert_equal 0, answer.reload.score
  end

  def test_latest_first_scope
    fa = QaAnswer.first
    la = QaAnswer.last
    assert_equal fa, QaAnswer.all.first
    assert_equal la, QaAnswer.all.last

    assert_equal la, QaAnswer.latest_first.first
    assert_equal fa, QaAnswer.latest_first.last
    1
  end

  def test_by_user_scope
    assert_equal 0, QaAnswer.by_user(users(:f_mentor)).size
    assert_equal 7, QaAnswer.by_user(users(:f_student)).size

    answer = QaAnswer.first
    answer.user = users(:f_mentor)
    answer.save!

    assert_equal 1, QaAnswer.by_user(users(:f_mentor)).size
    assert_equal 6, QaAnswer.by_user(users(:f_student)).size
  end
end
