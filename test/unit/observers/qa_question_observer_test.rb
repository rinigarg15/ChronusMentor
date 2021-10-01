require_relative './../../test_helper.rb'

class QaQuestionObserverTest < ActiveSupport::TestCase
	def test_create_ra
    qa_question = nil
    assert_difference 'RecentActivity.count',1 do
      qa_question = create_qa_question(:user => users(:f_student), :program => programs(:albers))
    end
    assert qa_question
    re = RecentActivity.last
    assert_equal qa_question, re.ref_obj
    assert_equal RecentActivityConstants::Type::QA_QUESTION_CREATION,re.action_type
    assert_nil re.for
    assert_equal RecentActivityConstants::Target::ALL, re.target
    assert_equal [qa_question.program], re.programs

    assert_difference('RecentActivity.count', -1) do
      qa_question.destroy
    end
  end
end