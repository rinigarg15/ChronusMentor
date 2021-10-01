require_relative './../test_helper.rb'

class SummaryTest < ActiveSupport::TestCase

  def test_belongs_to_connection_question
    assert_equal common_questions(:string_connection_q), summaries(:string_connection_summary_q).connection_question
  end

  def test_validations
    summary_1 = Summary.new
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :connection_question_id, "can't be blank" do
      summary_1.save!
    end

    summary2 = summaries(:string_connection_summary_q_psg)
    summary2.update_attributes(connection_question: nil)
    assert_false summary2.valid?
    assert_equal ["can't be blank"], summary2.errors.messages[:connection_question]
  end
end