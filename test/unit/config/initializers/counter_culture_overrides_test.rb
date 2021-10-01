require_relative './../../../test_helper.rb'

class CounterCultureOverridesTest < ActiveSupport::TestCase

  def test_counter_culture_when_create_and_delete_in_transaction
    qa_question = qa_questions(:what)
    assert_equal 1, qa_question.qa_answers_count

    ActiveRecord::Base.transaction do
      create_qa_answer(qa_question: qa_question).destroy
    end
    assert_equal 1, qa_question.reload.qa_answers_count
  end
end