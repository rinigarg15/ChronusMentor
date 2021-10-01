require_relative './../test_helper.rb'

class GlobalSearchProgramsControllerTest < ActionController::TestCase
  tests ProgramsController

  def test_search_all
    current_user_is :f_student

    questions = programs(:albers).qa_questions.select{|q| q.user == users(:f_mentor)}
    answers = programs(:albers).qa_answers.select{|ans| ans.user == users(:f_mentor)}
    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => 'good unique name'}
    assert_response :success
    assert_equal_unordered_objects [articles(:kangaroo), users(:f_mentor)] + questions + answers, assigns(:results).collect{|res| res[:active_record]}
    assert_match "MentorRequests.showRequestConnectionPopup", @response.body
  end

  def test_students_included_in_results
    current_user_is :f_student

    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => 'student'}
    assert_response :success
    assert_equal_unordered_objects [users(:f_student)] + QaAnswer.where(user_id: users(:f_student).id).collect{|ans| ans.qa_question}, assigns(:results).collect{|res| res[:active_record]}
  end

  def test_students_not_included_if_not_permitted
    current_user_is :f_student
    remove_role_permission(fetch_role(:albers, :student), 'view_students')

    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => 'student'}
    assert_response :success
    assert_equal_unordered_objects QaAnswer.where(user_id: users(:f_student).id).collect{|ans| ans.qa_question}, assigns(:results).collect{|res| res[:active_record]}
  end

  def test_inactive_users_not_included_in_search_for_non_admins
    current_user_is :psg_mentor
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search
    assert_response :success
    assert !assigns(:results).collect{|res| res[:active_record]}.include?(users(:inactive_user))
  end

  def test_inactive_users_included_in_search_for_admins
    current_user_is :psg_admin
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search
    assert_response :success
    assert assigns(:results).collect{|res| res[:active_record]}.include?(users(:inactive_user))
    assert assigns(:results).collect{|res| res[:active_record]}.include?(users(:psg_student1))
  end

  def test_admin_only_members_not_included_in_results
    current_user_is :f_admin
    assert users(:f_admin).is_admin_only?

    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => users(:f_admin).name}
    assert_response :success
    assert !assigns(:results).collect{|res| res[:active_record]}.include?(users(:f_admin))
  end

  def test_admin_with_other_roles_fetched
    current_user_is :f_admin
    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search
    assert_response :success
    assert assigns(:results).collect{|res| res[:active_record]}.include?(users(:ram))
  end

  def test_search_all_does_not_render_disabled_features
    current_user_is :f_student
    ActiveRecord::Base.stubs(:per_page).returns(10000)

    # Disable article feature.
    programs(:org_primary).enable_feature(FeatureName::ARTICLES, false)
    get :search, params: { :query => 'good unique name'}
    assert_response :success
    # Articles shouldn't be fetched.
    assert_equal_unordered [User, QaQuestion], assigns(:results).collect{|res| res[:active_record]}.collect(&:class).uniq
    assert_select '.vertical_filters' do
      assert_select 'li', :count => 6
      assert_select 'li.gray-bg', :text => /All results/, :count => 1
      assert_select 'li', :text => /Mentors/, :count => 1
      assert_select 'li', :text => /Students/, :count => 1
      assert_select 'li', :text => /#{_Articles}/, :count => 0
      assert_select 'li', :text => /Questions & Answers/, :count => 1
      assert_select 'li', :text => /#{_Resources}/, :count => 1
      assert_select 'li', :text => /Forums/, :count => 1
    end
  end

  def test_search_all_for_student_with_permission_to_view_third_role
    current_user_is :f_student
    add_role_permission(fetch_role(:albers, :student), 'view_users')
    # Disable article feature.
    programs(:org_primary).enable_feature(FeatureName::ARTICLES, false)
    get :search, params: { :query => 'user name'}
    assert_response :success
    # Articles shouldn't be fetched.
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    assert_equal_unordered [User, QaQuestion], assigns(:results).collect{|res| res[:active_record]}.collect(&:class).uniq
    assert_select '.vertical_filters' do
      assert_select 'li', :count => 7
      assert_select 'li.gray-bg', :text => /All results/, :count => 1
      assert_select 'li', :text => /Mentors/, :count => 1
      assert_select 'li', :text => /Students/, :count => 1
      assert_select 'li', :text => /Users/, :count => 1
      assert_select 'li', :text => /#{_Articles}/, :count => 0
      assert_select 'li', :text => /Questions & Answers/, :count => 1
      assert_select 'li', :text => /#{_Resources}/, :count => 1
      assert_select 'li', :text => /Forums/, :count => 1
    end
  end

  def test_mentors_not_included_if_not_permitted
    current_user_is :f_student
    remove_role_permission(fetch_role(:albers, :student), 'view_mentors')

    questions = programs(:albers).qa_questions.select{|q| q.user == users(:f_mentor)}
    answers = programs(:albers).qa_answers.select{|ans| ans.user == users(:f_mentor)}

    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => 'good unique name'}
    assert_response :success
    assert_equal_unordered_objects [articles(:kangaroo)] + questions + answers, assigns(:results).collect{|res| res[:active_record]}
  end

  def test_articles_not_included_if_not_permitted
    current_user_is :f_mentor
    remove_role_permission(fetch_role(:albers, :mentor), 'view_articles')

    questions = programs(:albers).qa_questions.select{|q| q.user == users(:f_mentor)}
    answers = programs(:albers).qa_answers.select{|ans| ans.user == users(:f_mentor)}
    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => 'good unique name'}
    assert_response :success
    assert_equal_unordered_objects questions + answers + [users(:f_mentor)], assigns(:results).collect{|res| res[:active_record]}
  end

  def test_answers_not_included_if_not_permitted
    current_user_is :f_mentor
    remove_role_permission(fetch_role(:albers, :mentor), 'view_questions')

    # Get all records so that we can validate the results
    ActiveRecord::Base.stubs(:per_page).returns(10000)
    get :search, params: { :query => 'good unique name'}
    assert_response :success
    assert_equal_unordered_objects [users(:f_mentor), articles(:kangaroo)], assigns(:results).collect{|res| res[:active_record]}
  end

  private

  def _a_article
    "an article"
  end

  def _article
    "article"
  end

  def _Article
    "Article"
  end

  def _articles
    "articles"
  end

  def _Articles
    "Articles"
  end

  def _Resources
    "Resources"  
  end

end
