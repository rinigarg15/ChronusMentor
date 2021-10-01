require_relative './../../test_helper.rb'

# Functional tests for search with filters
class SearchFunctionalTest < ActionController::TestCase
  tests UsersController

  def setup
    super
    abstract_preferences(:ignore_1).destroy!
    abstract_preferences(:ignore_3).destroy!
  end

  def test_filter_by_education_school
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:multi_education_q).id.to_s => 'American'}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor), users(:mentor_3)], assigns(:users)
    assert_equal [ { label: 'Entire Education', reset_suffix: "profile_question_#{profile_questions(:multi_education_q).id}" } ], assigns(:my_filters)
  end

  def test_filter_by_education_degree
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:multi_education_q).id.to_s => 'Arts'}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor), users(:mentor_3)], assigns(:users)
    assert_equal [ { label: 'Entire Education', reset_suffix: "profile_question_#{profile_questions(:multi_education_q).id}" } ], assigns(:my_filters)
  end

  def test_filter_by_education_degree_or_school
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:multi_education_q).id.to_s => 'Arts American'}}}
    assert_response :success
    assert_equal_unordered(
      [users(:f_mentor), users(:mentor_3)], assigns(:users)
    )
    assert_equal [ { label: 'Entire Education', reset_suffix: "profile_question_#{profile_questions(:multi_education_q).id}" } ], assigns(:my_filters)
  end

  def test_filter_by_experience_job_title
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:multi_experience_q).id.to_s => 'developer'}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor)], assigns(:users)
    assert_equal [ { label: 'Work Experience', reset_suffix: "profile_question_#{profile_questions(:multi_experience_q).id}" } ], assigns(:my_filters)
  end

  def test_filter_by_experience_company
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:multi_experience_q).id.to_s => 'Mannar Microsoft'}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor)], assigns(:users)
    assert_equal [ { label: 'Work Experience', reset_suffix: "profile_question_#{profile_questions(:multi_experience_q).id}" } ], assigns(:my_filters)
  end

  def test_filter_by_question_string_type
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:string_q).id.to_s => 'Bike race'}}}
    assert_response :success
    assert_equal [users(:mentor_3)], assigns(:users)
    assert_equal [
      {label: profile_questions(:string_q).question_text,
        reset_suffix: "profile_question_#{profile_questions(:string_q).id}"}
    ],
      assigns(:my_filters)
  end

  def test_filter_by_question_string_type_partial_text
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:string_q).id.to_s => 'race'}}}
    assert_response :success
    assert_equal [users(:mentor_3)], assigns(:users)
    assert_equal [
      {label: profile_questions(:string_q).question_text,
        reset_suffix: "profile_question_#{profile_questions(:string_q).id}"}
    ],
      assigns(:my_filters)
  end

  def test_filter_by_question_string_type_not_case_sensitive
    current_user_is :f_student
    assert_equal "Bike race", users(:mentor_3).answer_for(profile_questions(:string_q)).answer_text

    get :index, xhr: true, params: { sf: {pq: {profile_questions(:string_q).id.to_s => 'bIKE RACE'}}}
    assert_response :success
    assert_equal [users(:mentor_3)], assigns(:users)
    assert_equal [
      {label: profile_questions(:string_q).question_text,
        reset_suffix: "profile_question_#{profile_questions(:string_q).id}"}
    ],
      assigns(:my_filters)
  end

  def test_filter_by_question_string_type_when_empty
    current_user_is :f_student

     get :index, xhr: true, params: { items_per_page: 10000, sf: {pq: {profile_questions(:string_q).id.to_s => ''}}}
    assert_response :success

    # Just check a few users to make sure the empty text is not considered
    assert assigns(:users).include?(users(:f_mentor))
    assert assigns(:users).include?(users(:robert))
    assert_empty assigns(:my_filters)
  end

  def test_filter_by_question_single_choice_type
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {
        pq: {profile_questions(:single_choice_q).id.to_s => [question_choices(:single_choice_q_1).id.to_s]}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor)], assigns(:users)
    assert_equal [
      {label: profile_questions(:single_choice_q).question_text,
        reset_suffix: "profile_question_#{profile_questions(:single_choice_q).id}"}
    ],
      assigns(:my_filters)
  end

  def test_filter_by_question_single_choice_type_multile_answers
    current_user_is :f_student

    # No one has opt_2 as answer. Still, we must get those who have opt_1 and
    # opt_3
    get :index, xhr: true, params: { sf: {
        pq: {profile_questions(:single_choice_q).id.to_s => question_choices(:single_choice_q_1, :single_choice_q_2, :single_choice_q_3).collect(&:id).map(&:to_s)}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor), users(:robert)], assigns(:users)
  end

  def test_filter_by_question_multi_choice_type_1
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {
        pq: {profile_questions(:multi_choice_q).id.to_s => [question_choices(:multi_choice_q_2).id.to_s]}}}
    assert_response :success
    assert_equal_unordered [users(:mentor_3)], assigns(:users)
  end

  def test_filter_by_question_multi_choice_type_2
    current_user_is :f_student

    get :index, xhr: true, params: { sf: {
        pq: {profile_questions(:multi_choice_q).id.to_s => [question_choices(:multi_choice_q_3).id.to_s]}}}
    assert_response :success
    assert_equal_unordered [users(:f_mentor)], assigns(:users)
  end

  def test_filter_by_location_must_return_result
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.

    get :index, xhr: true, params: { items_per_page: 10000, sf: {
        location: {loc_ques.id => {name: locations(:delhi).full_address}}}}
    assert_response :success
    assert assigns(:users).include?(users(:robert))
    assert_equal [ { label: "Location", reset_suffix: "profile_question_#{loc_ques.id}" } ], assigns(:my_filters)
  end

  def test_filter_by_location_with_empty_radius_must_return_result
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.

    get :index, xhr: true, params: { items_per_page: 10000, sf: {
        location: {loc_ques.id => {name: locations(:delhi).full_address}}}}
    assert_response :success
    assert_equal_unordered [users(:robert)], assigns(:users)
    assert_equal [ { label: "Location", reset_suffix: "profile_question_#{loc_ques.id}" } ], assigns(:my_filters)
  end

  def test_filter_by_location_empty
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.

    get :index, xhr: true, params: { items_per_page: 10000, sf: {
        location: {loc_ques.id => {name: "", radius: 0}}}}
    assert_response :success

    # Pick some random 3 mentors from different locations. They all must be
    # there in the results.
    users_from_different_locs = [users(:f_mentor_student), users(:robert), users(:mentor_3)]
    assert_equal_unordered(users_from_different_locs,
      (assigns(:users) & users_from_different_locs))
    assert_empty assigns(:my_filters)
  end

  def test_filter_by_location_with_radius
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.

    get :index, xhr: true, params: { items_per_page: 10000, sf: {
        location: {loc_ques.id => {name: locations(:chennai).full_address}}}}
    assert_response :success

    # Pondicherry is not farther than 100 miles from Chennai. So, it should turn
    # up in the results
    assert assigns(:users).include?(users(:f_mentor))
    assert !(assigns(:users).include?(users(:f_mentor_student)))
  end

  def test_multiple_filters_case_1
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.

    get :index, xhr: true, params: { items_per_page: 10000, sf: {
      pq: {profile_questions(:multi_education_q).id.to_s => 'Arts', profile_questions(:experience_q).id.to_s => 'Microsoft'},
      location: {loc_ques.id => {name: locations(:chennai).full_address, radius: 100}}
    }}

    assert_response :success
    # :robert is the only person matching all the criteria passed.
    assert_equal [users(:f_mentor)], assigns(:users)
  end

  def test_multiple_filters_case_2
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.
    # Robert does not have 'Microsoft experience'. So, he gets filtered OUT.
    get :index, xhr: true, params: { items_per_page: 10000, sf: {
      pq: {profile_questions(:multi_education_q).id.to_s => 'Arts', profile_questions(:experience_q).id.to_s => 'Microsofts'},
      location: {loc_ques.id => {name: locations(:chennai).full_address, radius: 100}}
    }}

    assert_response :success
    assert assigns(:users).empty?
    assert_equal_unordered [
      {label: 'Entire Education', reset_suffix: "profile_question_#{profile_questions(:multi_education_q).id}"},
      {label: 'Current Experience', reset_suffix: "profile_question_#{profile_questions(:experience_q).id}"},
      {label: "Location", reset_suffix: "profile_question_#{loc_ques.id}"}
    ], assigns(:my_filters)
  end

  def test_multiple_filters_case_3
    current_user_is :f_student

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    # Set a large per_page so that we get all results without pagination.

    # f_mentor is in Chennai, has the answer 'Stand, Run'
    get :index, xhr: true, params: { items_per_page: 10000, sf: {
      pq: {profile_questions(:multi_choice_q).id.to_s => [question_choices(:multi_choice_q_3).id.to_s]},
      location: {loc_ques.id => {name: locations(:chennai).full_address}}
    }}

    assert_response :success
    assert_equal [users(:f_mentor)], assigns(:users)
  end
end