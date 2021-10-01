require_relative './../test_helper.rb'

class ConfidentialityAuditLogsControllerTest < ActionController::TestCase
  def setup
    super
    current_user_is :f_admin
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
    programs(:albers).save!
    programs(:albers).reload
  end

  # Check unprivileged access
  def test_requires_privilege_to_access
    current_user_is :f_mentor

    assert !users(:f_mentor).can_view_audit_logs?
    assert_permission_denied do
      get :index, params: { :role => 'mentors'}
    end
  end
 
  # Check privileged access
  def test_privileged_user_access
    role = create_role(:name => 'audit_manager')
    audit_manager = create_user(:role_names => ['audit_manager'])
    current_program_is :albers
    current_user_is audit_manager
    add_role_permission(role, 'view_audit_logs')

    assert_nothing_raised do
      get :index, params: { :role => 'mentors'}
      assert_response :success
    end
  end

  # New audit_log
  def test_should_get_new_with_active_log
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is another reason", :group_id => groups(:mygroup).id)
    get :new, params: { :group_id => groups(:mygroup).id}
    assert_redirected_to group_path(groups(:mygroup))
  end

  def test_should_get_new_with_inactive_log
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is another reason", :group_id => groups(:mygroup).id, :created_at => 1.day.ago)
    get :new, params: { :group_id => groups(:mygroup).id}
    assert_response :success
    assert assigns(:confidentiality_audit_log).new_record?
    assert_equal groups(:mygroup), assigns(:group)
  end

  def test_should_get_new_with_no_log
    ConfidentialityAuditLog.destroy_all
    get :new, params: { :group_id => groups(:mygroup).id}
    assert_response :success
    assert assigns(:confidentiality_audit_log).new_record?
    assert_equal groups(:mygroup), assigns(:group)
  end


  #  creation of announcement
  def test_should_create_audit_log
    assert_difference('ConfidentialityAuditLog.count') do
      post :create, params: { :confidentiality_audit_log => {:reason =>"This is a reason"}, :group_id => groups(:mygroup).id}
    end
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal groups(:mygroup), assigns(:group)
    audit_log = ConfidentialityAuditLog.last
    assert_equal programs(:albers), audit_log.program
    assert_equal users(:f_admin), audit_log.user
    assert_equal "This is a reason", audit_log.reason
    assert_equal groups(:mygroup), audit_log.group
  end

  def test_should_not_create_new_log_in_presence_of_an_active_log
    audit_log = programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id, :created_at => 2.minutes.ago)
    assert_difference('ConfidentialityAuditLog.count', 0) do
      post :create, params: { :confidentiality_audit_log => {:reason =>"This is another reason"}, :group_id => groups(:mygroup).id}
    end
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal groups(:mygroup), assigns(:group)
  end

  # creation of announcement without reason
  def test_error_create_audit_log_without_reason
    assert_no_difference('ConfidentialityAuditLog.count') do
      post :create, params: { :group_id => groups(:mygroup).id}
    end
    assert_redirected_to new_confidentiality_audit_log_path(:group_id => groups(:mygroup).id)
    assert_equal "Enter a reason", flash[:error]
  end

  # index action
  def test_listing_of_audit_logs_belonging_to_current_program_only
    a = programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id, :created_at => 1.day.ago)
    b = programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:ram).id, :reason =>"This is another reason", :group_id => groups(:mygroup).id)
    c = programs(:ceg).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id)
    get :index

    assert_equal [b,a] , assigns(:audit_logs)
  end

  def test_confidentiality_log_access
    current_user_is :f_admin
    assert_nothing_raised do
      get :index
      assert_response :success
    end
  end

  def test_confidentiality_log_access_exception_case
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::DISABLED
    programs(:albers).save!
    programs(:albers).reload

    current_user_is :f_admin
    assert_permission_denied do
      get :index
      assert_response :success
    end

    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::OPEN
    programs(:albers).save!
    programs(:albers).reload

    assert_permission_denied do
      get :index
      assert_response :success
    end
  end

  def test_no_access_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_admin
    
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::OPEN
    programs(:albers).save!
    programs(:albers).reload
    
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied do
      get :index
    end
  end
end
