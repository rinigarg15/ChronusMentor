require_relative './../test_helper.rb'

class DataImportsControllerTest < ActionController::TestCase
  def test_feature_enabled
    current_member_is :f_admin
    current_organization_is :org_primary
    assert_false programs(:org_primary).data_import_enabled?
    assert_permission_denied do
      get :index
    end
  end

  def test_authorization
    current_member_is :f_mentor
    assert_permission_denied do
      get :index
    end
  end

  def test_org_login
    get :index
    assert_redirected_to "http://www." + DEFAULT_DOMAIN_NAME + "/"
  end

  def test_index
    current_member_is :f_admin
    current_organization_is :org_primary
    programs(:org_primary).enable_feature(FeatureName::DATA_IMPORT, true)
    assert programs(:org_primary).data_import_enabled?
    d1 = create_data_import
    d2 = create_data_import(organization_id: programs(:org_anna_univ).id)
    get :index
    assert_response :success
    assert_equal [d1], assigns(:data_imports)
  end
end
