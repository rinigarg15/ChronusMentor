require_relative './../../../../test_helper'

class QaQuestionElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_qa_questions_matching_query
    search_query = "where in this world is coimbatore"

    # without options
    assert_equal_unordered qa_questions(:question_for_stopwords_test, :ceg_1, :ceg_2, :psg_1), QaQuestion.get_qa_questions_matching_query(search_query).to_a

    # with options
    assert_equal [qa_questions(:psg_1)], QaQuestion.get_qa_questions_matching_query(search_query, with: { program_id: programs(:psg).id } ).to_a

    # without options
    assert_empty QaQuestion.get_qa_questions_matching_query("where is user", with: { program_id: programs(:psg).id }, without: { id: qa_questions(:cit_1).id } ).to_a

    # Sort options
    assert_equal qa_questions(:question_for_stopwords_test, :ceg_1, :psg_1, :ceg_2), QaQuestion.get_qa_questions_matching_query(search_query, sort_field: "id", sort_order: "asc").to_a

    # Pagination
    assert_equal [qa_questions(:question_for_stopwords_test)], QaQuestion.get_qa_questions_matching_query(search_query, sort_field: "id", sort_order: "asc", page: 1, per_page: 1).to_a
  end
end