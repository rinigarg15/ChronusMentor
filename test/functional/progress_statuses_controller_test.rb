require_relative "./../test_helper.rb"

class ProgressStatusesControllerTest < ActionController::TestCase
  def test_org_login_required
    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
    get :show, params: { id: ps.id}
    assert_redirected_to root_organization_url(:subdomain => REDIRECT_SUBDOMAIN, :host => DEFAULT_HOST_NAME)

    current_organization_is :org_primary
    get :show, params: { id: ps.id}
    assert_redirected_to new_session_path
  end

  def test_show_success
    current_member_is :f_student
    ps = ProgressStatus.create!(ref_obj_id: users(:f_admin).id, ref_obj_type: User.name, for: ProgressStatus::For::CsvImports::VALIDATION, maximum: 100)
    ProgressStatus.any_instance.stubs(:percentage).returns(77)
    ProgressStatus.any_instance.stubs(:completed?).returns(true)
    get :show, params: { id: ps.id}
    assert_response :success
    json_response = JSON.parse(response.body).first
    assert json_response["success"]
    assert_equal 77, json_response["percentage"]
    assert json_response["completed"]
  end
end