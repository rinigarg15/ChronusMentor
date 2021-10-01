require_relative './../../test_helper.rb'

class ActsAsSummarizableTest < ActiveSupport::TestCase
  def test_set_unset_summary
    summaries(:string_connection_summary_q).destroy!
    question = common_questions(:string_connection_q)
    assert_difference 'Summary.count', 1 do
      question.set_unset_summary
    end

    assert_difference 'Summary.count', -1 do
      question.set_unset_summary(false)
    end
  end
end
