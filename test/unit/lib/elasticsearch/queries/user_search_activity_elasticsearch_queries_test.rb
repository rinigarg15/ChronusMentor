require_relative './../../../../test_helper'

class UserSearchActivityElasticsearchQueriesTest < ActiveSupport::TestCase
  def test_get_search_keywords
    assert_equal [{:keyword=>"sample answer text", :count=>1}, {:keyword=>"sample choice text", :count=>1}, {:keyword=>"sample search text", :count=>1}], UserSearchActivity.get_search_keywords({program_id: programs(:albers).id, user_id: [users(:mkr_student).id, users(:f_student).id]})
    assert_equal [{:keyword=>"sample answer text", :count=>1}, {:keyword=>"sample search text", :count=>1}], UserSearchActivity.get_search_keywords({program_id: programs(:albers).id, user_id: [users(:mkr_student).id]})

    profile_question = profile_questions(:string_q)
    options = {user: users(:mkr_student), locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sks", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text, search_text: "sample answer text"}
    search_activity = create_user_search_activity(options)
    reindex_documents(created: search_activity)
    assert_equal [{:keyword=>"sample answer text", :count=>2}, {:keyword=>"sample search text", :count=>1}], UserSearchActivity.get_search_keywords({program_id: programs(:albers).id, user_id: [users(:mkr_student).id]})

    profile_question = profile_questions(:string_q)
    options = {user: users(:mkr_student), locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sksh", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text, search_text: "Hyderabad"}
    search_activity = create_user_search_activity(options)
    reindex_documents(created: search_activity)
    assert_equal_unordered [{:keyword=>"sample answer text", :count=>2}, {:keyword=>"hyderabad", :count=>1}, {:keyword=>"sample search text", :count=>1}], UserSearchActivity.get_search_keywords({program_id: programs(:albers).id, user_id: [users(:mkr_student).id]})

    ["yes", "no", "true", "false", "none", "none of the above", "na", "n.a", "not applicable", "others"].each do |keyword|
      profile_question = profile_questions(:string_q)
      options = {user: users(:mkr_student), locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7skshg", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text, search_text: keyword}
      search_activity = create_user_search_activity(options)
      reindex_documents(created: search_activity)
    end
    assert_equal_unordered [{:keyword=>"sample answer text", :count=>2}, {:keyword=>"hyderabad", :count=>1}, {:keyword=>"sample search text", :count=>1}], UserSearchActivity.get_search_keywords({program_id: programs(:albers).id, user_id: [users(:mkr_student).id]})

    profile_question = profile_questions(:string_q)
      options = {user: users(:mkr_student), locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7skshgg", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text, search_text: "N.A"}
    search_activity = create_user_search_activity(options)
    reindex_documents(created: search_activity)
    assert_equal_unordered [{:keyword=>"sample answer text", :count=>2}, {:keyword=>"hyderabad", :count=>1}, {:keyword=>"sample search text", :count=>1}], UserSearchActivity.get_search_keywords({program_id: programs(:albers).id, user_id: [users(:mkr_student).id]})
  end
end