require_relative './../test_helper.rb'

class QaQuestionTest < ActiveSupport::TestCase

  def test_latest_answer_by_user
    user = users(:f_admin)
    question = create_qa_question
    assert_nil question.latest_qa_answer_by(user)
    answer1 = create_qa_answer(:user => user, :qa_question => question)
    assert_equal answer1, question.latest_qa_answer_by(user)
    answer2 = create_qa_answer(:user => user, :qa_question => question)
    assert_equal answer2, question.latest_qa_answer_by(user)
  end

  def test_user_follows_a_question
    user = users(:f_admin)
    question = create_qa_question(:user => user)
    # Creater follows the question
    assert question.follow?(user)
    assert_equal [user], question.followers
    question.toggle_follow!(user)
    question.reload
    assert_false question.follow?(user)
    assert_equal [], question.followers
    question.toggle_follow!(user)
    question.reload
    assert question.follow?(user)
    assert_equal [user], question.followers
  end

  def test_similar_qa_questions_with_stopwords
    #"is" is a stopword. So when we search the similar questions for qa_questions(:what), only why should be returned. 
    qa_questions = []
    qa_questions << qa_questions(:why)
    assert_equal qa_questions, qa_questions(:what).similar_qa_questions.to_a
  end

  def test_similar_qa_questions_with_proper_escape
    qa = create_qa_question(summary: "title with / in it")
    assert_nothing_raised { qa.similar_qa_questions }
  end

  def test_user_belongs_to_program
    user = users(:f_admin)
    assert_not_equal programs(:ceg), user.program
    question = QaQuestion.new(:program => programs(:ceg), :user => user, :summary => "Hello", :description => "How are you?")
    assert_false question.valid?
    assert question.errors[:user]
  end

  def test_question_has_summary
    question = QaQuestion.new(:program => programs(:albers), :user => users(:f_admin), :summary => "Hello", :description => "How are you?")
    assert question.valid?
    question.summary = nil
    assert_false question.valid?
  end

  def test_destroys_answers
    question = create_qa_question
    answer_1 = create_qa_answer(:qa_question => question)
    answer_2 = create_qa_answer(:qa_question => question)
    assert_equal_unordered [answer_1, answer_2], question.qa_answers
    assert_difference('QaAnswer.count', -2) do
      question.destroy
    end
  end

  def test_create_qa_question
    question = create_qa_question(:user => users(:f_student), :program => programs(:albers), :summary => "hello", :description => "how are you?")
    assert question
    assert_equal users(:f_student), question.user
    assert_equal users(:f_student), question.followers.first
    assert_equal programs(:albers), question.program
    assert_equal "hello", question.summary
    assert_equal "how are you?", question.description
  end

  def test_human_name
    assert_equal "Answer", QaQuestion.human_name
  end

  def test_dependent_destroy_of_answers
    qa_question = create_qa_question(:user => users(:f_student))
    QaAnswer.destroy_all
    qa_answer = create_qa_answer(:qa_question => qa_question, :user => users(:f_admin))
    assert_equal qa_question, qa_answer.qa_question
    qa_question.destroy
    assert_equal QaAnswer.count, 0
  end

  def test_total_likes_for_a_question
    user = users(:f_mentor)
    qa_question = create_qa_question(:user => user)
    qa_answer1 = qa_question.qa_answers.build(:content => "aparna")
    qa_answer1.user = user
    qa_answer1.score = 1
    qa_answer1.save!
    qa_answer2 = qa_question.qa_answers.build(:content => "chugh")
    qa_answer2.score = 2
    qa_answer2.user = user
    qa_answer2.save!
    assert_equal qa_question.total_likes, 3
  end

  def test_stop_words
    qa_with_is = QaQuestion.all.select{|q| q.summary.match(/is/) || q.description.match(/is/)}
    qa_with_coimbatore = QaQuestion.all.select{|q| q.summary.match(/coimbatore/) || q.description.match(/coimbatore/)}
    assert_not_equal qa_with_is, qa_with_coimbatore
    assert_equal QaQuestion.get_qa_questions_matching_query("coimbatore").records, QaQuestion.get_qa_questions_matching_query("coimbatore is").records
  end
end
