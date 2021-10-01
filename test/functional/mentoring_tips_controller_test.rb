require_relative './../test_helper.rb'

class MentoringTipsControllerTest < ActionController::TestCase
  def setup
    super
    current_program_is :albers

    @tip_role = create_role(:name => 'tips')
    add_role_permission(@tip_role, 'manage_mentoring_tips')
    add_role_permission(@tip_role, RoleConstants::MANAGEMENT_PERMISSIONS.first)

    @tip_user = create_user(:name => 'tip_admin', :role_names => ['tips'])
  end
  
  def test_authentication
    current_user_is :f_student
    assert_permission_denied do
      get :index
    end
  end

  def test_index
    current_user_is @tip_user
    get :index

    assert_response :success
    assert_template 'index'
    assert_equal fetch_mentor_tip(true), assigns(:mentoring_tips)
    assert_equal RoleConstants::MENTOR_NAME, assigns(:filter_field)
    assert_equal [RoleConstants::MENTOR_NAME], assigns(:new_mentoring_tip).role_names
    assert assigns(:new_mentoring_tip).new_record?
  end

  def test_index_mentee_tips
    current_user_is @tip_user
    get :index, params: { :filter => RoleConstants::STUDENT_NAME}

    assert_response :success
    assert_template 'index'
    assert_equal RoleConstants::STUDENT_NAME, assigns(:filter_field)
    assert_equal fetch_student_tip(true), assigns(:mentoring_tips)
    assert_equal [RoleConstants::STUDENT_NAME], assigns(:new_mentoring_tip).role_names
    assert assigns(:new_mentoring_tip).new_record?
  end

  def test_create
    current_user_is :f_admin

    assert_difference "MentoringTip.count" do
      post :create, xhr: true, params: { :mentoring_tip => {:message => "Hi", :role_names_str => RoleConstants::MENTOR_NAME}}
    end
    
    tip = MentoringTip.last
    assert_equal tip, assigns(:mentoring_tip)
    assert_equal "Hi", tip.message
    assert_equal [RoleConstants::MENTOR_NAME], tip.role_names
    assert_match /edit_mentoring_tip_new.*after/, @response.body
  end

  def test_create_failure
    current_user_is :f_admin
    assert_no_difference "MentoringTip.count" do
      post :create, xhr: true, params: { :mentoring_tip => {:message => "", :role_names_str => RoleConstants::MENTOR_NAME}}
    end

    assert_nil assigns(:mentoring_tip).id
  end

  def test_edit
    current_user_is :f_admin
    tip = fetch_mentor_tip

    get :edit, xhr: true, params: { :id => tip.id}
    assert_equal tip, assigns(:mentoring_tip)
    assert_match /mentoring_tip_#{tip.id}.*after/, @response.body
  end

  def test_update
    current_user_is :f_admin
    tip = fetch_mentor_tip
    assert_match /When the time comes.*ceases to exist at all/, tip.message

    post :update, xhr: true, params: { :id => tip.id, :mentoring_tip => {:message => "Hi"}}
    assert_equal tip, assigns(:mentoring_tip)
    assert_equal "Hi", tip.reload.message
    assert_match /mentoring_tip_#{tip.id}.*replaceWith/, @response.body
  end

  def test_update_failure
    current_user_is :f_admin
    tip = fetch_mentor_tip
    assert_match /When the time comes.*ceases to exist at all/, tip.message

    post :update, xhr: true, params: { :id => tip.id, :mentoring_tip => {:message => ""}}
    assert_equal tip, assigns(:mentoring_tip)
    assert_match /When the time comes.*ceases to exist at all/, tip.reload.message
  end

  def test_disable_mentoring_tip
    current_user_is @tip_user

    tip = fetch_mentor_tip
    tip.update_attribute(:enabled, true)
    post :update, xhr: true, params: { :id => tip.id, :mentoring_tip => {:enabled => false}}

    assert_response :success
    assert_equal tip, assigns(:mentoring_tip)
    assert_match /mentoring_tip_#{tip.id}.*replaceWith/, @response.body

    assert_equal tip.reload.enabled?, false
  end

  def test_enable_mentoring_tip
    current_user_is @tip_user
    
    tip = fetch_mentor_tip
    tip.update_attribute(:enabled, false)

    post :update, xhr: true, params: { :id => tip.id, :mentoring_tip => {:enabled => true}}

    assert_response :success
    assert_equal tip, assigns(:mentoring_tip)
    assert_match /mentoring_tip_#{tip.id}.*replaceWith/, @response.body

    assert_equal tip.reload.enabled?, true
  end

  def test_disable_all_enable_all_mentors
    current_user_is @tip_user
    
    tip = fetch_mentor_tip
    # First enable all tips to mentors
    post :update_all, params: { :enable => "true", :filter => RoleConstants::MENTORS_NAME}
    assert_equal tip.reload.enabled, true
    assert_equal fetch_student_tip.enabled, false
    # Now disable all the tips.
    post :update_all, params: { :enable => "false", :filter => RoleConstants::MENTORS_NAME}
    assert_equal tip.reload.enabled, false
    assert_equal fetch_student_tip.enabled, false
  end

  def test_destroy
    current_user_is :f_admin
    m = programs(:albers).mentoring_tips.new(:message => "Hi")
    m.role_names = [RoleConstants::MENTOR_NAME]
    m.save!

    assert_difference "MentoringTip.count", -1 do
      post :destroy, xhr: true, params: { :id => m.id}
    end
    assert_equal m, assigns(:mentoring_tip)
  end

  def test_no_access_for_program_with_disabled_ongoing_mentoring
    current_user_is @tip_user
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :index
    end
  end

  private

  def fetch_mentor_tip(fetch_all = false)
    if fetch_all
      programs(:albers).mentoring_tips.select{|m| m.role_names.include?(RoleConstants::MENTOR_NAME)}
    else
      # Just fetch the first tip
      programs(:albers).mentoring_tips.select{|m| m.role_names.include?(RoleConstants::MENTOR_NAME)}.first
    end
  end

  def fetch_student_tip(fetch_all = false)
    if fetch_all
      programs(:albers).mentoring_tips.select{|m| m.role_names.include?(RoleConstants::STUDENT_NAME)}
    else
      # Just fetch the first tip
      programs(:albers).mentoring_tips.select{|m| m.role_names.include?(RoleConstants::STUDENT_NAME)}.first
    end
  end
end
