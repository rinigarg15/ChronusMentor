require_relative '../test_helper'

class UserSearchActivityTest < ActiveSupport::TestCase
  def test_validations
    user_search_activity = UserSearchActivity.new
    assert_false user_search_activity.valid?
    assert_equal ["can't be blank"], user_search_activity.errors.messages[:user_id]
    assert_equal ["can't be blank"], user_search_activity.errors.messages[:program_id]

    user_search_activity.user = users(:mkr_student)
    user_search_activity.program = programs(:albers)
    assert user_search_activity.valid?
  end

  def test_add_user_activity
    user = users(:f_student)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE}
    UserSearchActivity.expects(:add_filter_activity).with(user, options)
    UserSearchActivity.expects(:add_search_activity).with(user, options)
    UserSearchActivity.add_user_activity(user, options)
  end

  def test_add_search_activity
    user = users(:f_student)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk"}
    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_search_activity(user, options)
    end
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", quick_search: "search text"}
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_search_activity(user, options)
    end
    activity = UserSearchActivity.last
    assert_equal "de", activity.locale
    assert_equal "search text", activity.search_text
    assert_equal UserSearchActivity::Src::LISTING_PAGE, activity.source
    assert_equal "fght4n7sk", activity.session_id
    assert_nil activity.profile_question_id
    assert_nil activity.question_choice_id
    assert_nil activity.profile_question_text

    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_search_activity(user, options)
    end
    options[:session_id] = "g5j98sdkjb"
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_search_activity(user, options)
    end
  end

  def test_add_filter_activity
    user = users(:f_student)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE}
    UserSearchActivity.expects(:add_custom_profile_filters_activity).with(user, options)
    UserSearchActivity.expects(:add_location_filter_activity).with(user, options)
    UserSearchActivity.add_filter_activity(user, options)
  end

  def test_add_location_filter_activity
    user = users(:f_student)
    profile_question = profile_answers(:location_chennai_ans).profile_question
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk"}
    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_location_filter_activity(user, options)
    end
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", location: {"#{profile_question.id}" => {"name" => "Chennai, Tamilnadu, India"}}}
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_location_filter_activity(user, options)
    end

    activity = UserSearchActivity.last
    assert_equal "de", activity.locale
    assert_equal "Chennai", activity.search_text
    assert_equal UserSearchActivity::Src::LISTING_PAGE, activity.source
    assert_equal "fght4n7sk", activity.session_id
    assert_equal profile_question, activity.profile_question
    assert_equal profile_question.question_text, activity.profile_question_text
    assert_nil activity.question_choice_id

    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_location_filter_activity(user, options)
    end
    options[:session_id] = "g5j98sdkjb"
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_location_filter_activity(user, options)
    end
  end

  def test_add_custom_profile_filters_activity
    user = users(:f_student)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk"}
    UserSearchActivity.expects(:add_filter_activity_for_choice_based_question).never
    UserSearchActivity.expects(:add_filter_activity_for_text_based_question).never
    UserSearchActivity.add_custom_profile_filters_activity(user, options)

    profile_question = profile_questions(:student_multi_choice_q)
    question_choice_1 = question_choices(:student_multi_choice_q_1)
    question_choice_2 = question_choices(:student_multi_choice_q_2)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", custom_profile_filters: {"#{profile_question.id}" => ["#{question_choice_1.id}", "#{question_choice_2.id}"]}}

    UserSearchActivity.expects(:add_filter_activity_for_choice_based_question).with(user, ["#{question_choice_1.id}", "#{question_choice_2.id}"], {profile_question_id: "#{profile_question.id}", profile_question_text: profile_question.question_text, locale: options[:locale], source: options[:source], session_id: options[:session_id]}).once
    UserSearchActivity.expects(:add_filter_activity_for_text_based_question).never
    UserSearchActivity.add_custom_profile_filters_activity(user, options)

    profile_question = profile_questions(:student_string_q)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", custom_profile_filters: {"#{profile_question.id}" => ["sample text"]}}
    UserSearchActivity.expects(:add_filter_activity_for_text_based_question).with(user, ["sample text"], {profile_question_id: "#{profile_question.id}", profile_question_text: profile_question.question_text, locale: options[:locale], source: options[:source], session_id: options[:session_id]}).once
    UserSearchActivity.expects(:add_filter_activity_for_choice_based_question).never
    UserSearchActivity.add_custom_profile_filters_activity(user, options)
  end

  def test_add_filter_activity_for_choice_based_question
    user = users(:f_student)
    profile_question = profile_questions(:student_multi_choice_q)
    question_choice_1 = question_choices(:student_multi_choice_q_1)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text}
    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_filter_activity_for_choice_based_question(user, ["123456"], options)
    end

    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_filter_activity_for_choice_based_question(user, ["#{question_choice_1.id}"], options)
    end

    activity = UserSearchActivity.last
    assert_equal "de", activity.locale
    assert_equal question_choice_1.text, activity.search_text
    assert_equal UserSearchActivity::Src::LISTING_PAGE, activity.source
    assert_equal "fght4n7sk", activity.session_id
    assert_equal profile_question, activity.profile_question
    assert_equal profile_question.question_text, activity.profile_question_text
    assert_equal question_choice_1, activity.question_choice

    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_filter_activity_for_choice_based_question(user, ["#{question_choice_1.id}"], options)
    end
    options[:session_id] = "d6gjw3k5sd"
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_filter_activity_for_choice_based_question(user, ["#{question_choice_1.id}"], options)
    end
  end

  def test_add_filter_activity_for_text_based_question
    user = users(:f_student)
    profile_question = profile_questions(:student_string_q)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text}
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_filter_activity_for_text_based_question(user, "search text", options)
    end
    activity = UserSearchActivity.last
    assert_equal "de", activity.locale
    assert_equal "search text", activity.search_text
    assert_equal UserSearchActivity::Src::LISTING_PAGE, activity.source
    assert_equal "fght4n7sk", activity.session_id
    assert_equal profile_question, activity.profile_question
    assert_equal profile_question.question_text, activity.profile_question_text
    assert_nil activity.question_choice

    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.add_filter_activity_for_text_based_question(user, "search text", options)
    end
    options[:session_id] = "d6gjw3k5sd"
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.add_filter_activity_for_text_based_question(user, "search text", options)
    end
  end

  def test_create_user_search_activity
    user = users(:f_student)
    profile_question = profile_questions(:student_string_q)
    options = {locale: "de", source: UserSearchActivity::Src::LISTING_PAGE, session_id: "fght4n7sk", profile_question_id: profile_question.id, profile_question_text: profile_question.question_text}
    
    assert_difference "UserSearchActivity.count", 1 do
      UserSearchActivity.create_user_search_activity(user, options)
    end

    assert_no_difference "UserSearchActivity.count" do
      UserSearchActivity.create_user_search_activity(user, options)
    end
  end

end