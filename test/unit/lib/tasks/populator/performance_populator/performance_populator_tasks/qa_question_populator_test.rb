require_relative './../../../../../../test_helper'

class QaQuestionPopulatorTest < ActiveSupport::TestCase
  def test_add_qa_questions
    program = programs(:albers)
    to_add_student_ids = program.users.active.select(:id).select{|user|  user.is_student?}.first(5).collect(&:id)
    to_remove_student_ids = program.qa_questions.pluck(:user_id).uniq.last(5)
    populator_add_and_remove_objects("qa_question", "user", to_add_student_ids, to_remove_student_ids, {program: program})
  end
end