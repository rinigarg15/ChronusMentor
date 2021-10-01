require_relative './../../test_helper.rb'

class DateProfileFilterTest < ActiveSupport::TestCase
  include DateProfileFilter

  def test_get_date_query
    date_question = profile_questions(:date_question)
    assert_equal "  where date_answers.answer BETWEEN '2013-01-02' AND '2013-02-02'  ", get_date_query(custom_date_string)
    assert_equal "  where date_answers.answer >= '2013-01-02'  ", get_date_query(from_date_string)
    assert_equal "  where date_answers.answer <= '2013-02-02'  ", get_date_query(to_date_string)
    assert get_date_query("").blank?
    assert get_date_query("hello").blank?
    assert_equal "   date_answers.answer BETWEEN '2013-01-02' AND '2013-02-02'  ", get_date_query(custom_date_string, exclude_where: true)
    assert_equal "  join date_answers on (date_answers.ref_obj_id = profile_answers.id AND date_answers.ref_obj_type = 'ProfileAnswer') where date_answers.answer BETWEEN '2013-01-02' AND '2013-02-02'  ", get_date_query(custom_date_string, join_date_answers: true)
    assert_equal "  join date_answers on (date_answers.ref_obj_id = profile_answers.id AND date_answers.ref_obj_type = 'ProfileAnswer') where date_answers.answer BETWEEN '2013-01-02' AND '2013-02-02' AND profile_questions.id = #{date_question.id} ", get_date_query(custom_date_string, join_date_answers: true, profile_question: date_question)
    assert_equal "query_prefix  join date_answers on (date_answers.ref_obj_id = profile_answers.id AND date_answers.ref_obj_type = 'ProfileAnswer') where date_answers.answer BETWEEN '2013-01-02' AND '2013-02-02' AND profile_questions.id = #{date_question.id} query_suffix", get_date_query(custom_date_string, join_date_answers: true, profile_question: date_question, query_prefix: "query_prefix", query_suffix: "query_suffix")
  end

  def test_profile_question_answer_join_query
    assert_match /profile_answers.ref_obj_id = members.id/, profile_question_answer_join_query("some_object")
    assert_match /profile_answers.ref_obj_id = m.id/, profile_question_answer_join_query("some_object", members: 'm')
    assert_match /profile_answers.ref_obj_type=some_object/, profile_question_answer_join_query("some_object")
  end

  def test_initialize_date_range_for_filter
    assert_equal custom_date_hash, initialize_date_range_for_filter(custom_date_string)
    assert_equal from_date_hash, initialize_date_range_for_filter(from_date_string)
    assert_equal to_date_hash, initialize_date_range_for_filter(to_date_string)
  end

  def test_get_date_range_string_for_variable_days
    Timecop.freeze(Date.parse('2018-01-01'))
    assert_equal custom_date_string, get_date_range_string_for_variable_days(custom_date_string, 7, "custom")
    assert_equal date_string_for_variable_preset[:next_n_days], get_date_range_string_for_variable_days(date_string_for_variable_preset[:next_n_days], nil, "next_n_days")

    assert_equal "01/01/2018 - 01/04/2018 - next_n_days", get_date_range_string_for_variable_days(date_string_for_variable_preset[:next_n_days], 3, "next_n_days")
    assert_equal "12/29/2017 - 01/01/2018 - last_n_days", get_date_range_string_for_variable_days(date_string_for_variable_preset[:last_n_days], 3, "last_n_days")
  end

  private

  def custom_date_string
    "01/02/2013 - 02/02/2013 - custom"
  end

  def date_string_for_variable_preset
    {
      next_n_days: "from - to - next_n_days",
      last_n_days: "from - to - last_n_days",
      before_last_n_days: "from - to - before_last_n_days",
      after_next_n_days: "from - to - after_next_n_days"
    }
  end

  def custom_date_hash
    {
      from_date: Date.parse("2 Jan, 2013").strftime,
      to_date: Date.parse("2 Feb, 2013").strftime,
      preset: "custom"
    }
  end

  def from_date_string
    "01/02/2013 -  - custom"
  end

  def from_date_hash
    {
      from_date: Date.parse("2 Jan, 2013").strftime,
      to_date: nil,
      preset: "custom"
    }
  end

  def to_date_string
    " - 02/02/2013 - custom"
  end

  def to_date_hash
    {
      from_date: nil,
      to_date: Date.parse("2 Feb, 2013").strftime,
      preset: "custom"
    }
  end
end