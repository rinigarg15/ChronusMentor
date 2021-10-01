require_relative '../test_helper'

class DateAnswerTest < ActiveSupport::TestCase
  def test_validations
    Timecop.freeze
    date_answer = DateAnswer.new
    assert_false date_answer.valid?
    assert_equal ["can't be blank"], date_answer.errors.messages[:answer]
    assert_equal ["can't be blank"], date_answer.errors.messages[:ref_obj]
    
    profile_question = profile_questions(:date_question)
    profile_answer = ProfileAnswer.new(profile_question: profile_question, ref_obj: members(:f_student), answer_text: "12 Aug, 2018")
    date_answer.answer = Date.parse("12 Aug, 2018")
    date_answer.ref_obj = profile_answer
    assert date_answer.valid?
  end
end