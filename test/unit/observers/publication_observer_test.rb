require_relative './../../test_helper.rb'

class PublicationObserverTest < ActiveSupport::TestCase
  def test_after_destroy_on_question_type_change
    question = profile_questions(:multi_publication_q)
    answer = profile_answers(:profile_answers_7)
    assert_equal 2, question.profile_answers.reload.size
    assert_equal 2, answer.publications.size
    question.update_attributes!(question_type: ProfileQuestion::Type::MULTI_STRING)
    assert_equal 0, question.profile_answers.reload.size
  end

  def test_after_destroy_updates_answer_text
    question = profile_questions(:multi_publication_q)
    answer = profile_answers(:profile_answers_7)
    assert_equal 2, answer.publications.size
    assert_equal "Useful publication, Publisher, http://publication.url, Good unique name, Very useful publication\n Mentor publication, Publisher, http://publication.url, Good unique name, Very useful publication", answer.answer_text
    publications(:pub_2).destroy
    assert_equal 1, answer.reload.publications.size
    assert_equal "Useful publication, Publisher, http://publication.url, Good unique name, Very useful publication", answer.answer_text
    assert_equal 2, question.profile_answers.reload.size
  end
end
