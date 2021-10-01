require_relative './../../../../../../test_helper'

class QaAnswerPopulatorTest < ActiveSupport::TestCase

  def test_add_qa_answers
    program = programs(:albers)
    to_add_qa_question_ids = program.qa_question_ids
    to_remove_qa_question_ids = program.qa_answers.pluck(:qa_question_id).uniq.last(5)
    populator_add_and_remove_objects("qa_answer", "student", to_add_qa_question_ids, to_remove_qa_question_ids, program: program)
  end
end