require_relative './../test_helper.rb'

class ApiTestsControllerTest < ActionController::TestCase

  def test_index
    org = programs(:org_primary)
    domain = Program::Domain.where(program_id: org.id).first
    domain.domain = ScannerConstants::PROGRAM_DOMAIN
    domain.subdomain = ScannerConstants::PROGRAM_SUBDOMAIN
    domain.save!
    member = org.members.admins.first
    member.update_attributes!(email: ScannerConstants::ADMIN_EMAIL)
    current_organization_is :org_primary
    get :index
    assert_response :success
    assert assigns(:get_api_links)
    assert_equal ["Users index", "Drafted Connections Index", "Ongoing Connections Index", "Closed Connections Index", "Users show", "Users show with profile fields", "Connections show", "Connections show with connection profile fields", "Mentor Profile Fields Index", "Mentee Profile Fields Index", "Connection Profile Fields Index"], assigns(:get_api_links).keys
    assert assigns(:post_api_links)
    assert_equal ["User Create", "Connection Create"], assigns(:post_api_links).keys
    assert assigns(:put_api_links)
    assert_equal ["User Update", "Connection Update"], assigns(:put_api_links).keys
    assert assigns(:delete_api_links)
    assert_equal ["User Delete", "Connection Delete"], assigns(:delete_api_links).keys
    assert_select 'html' do
      assert_select 'table#get_api' do
        assert_select 'td', text: "Users index"
        assert_select 'td', text: "Drafted Connections Index"
        assert_select 'td', text: "Ongoing Connections Index"
        assert_select 'td', text: "Closed Connections Index"
        assert_select 'td', text: "Users show"
        assert_select 'td', text: "Users show with profile fields"
        assert_select 'td', text: "Connections show"
        assert_select 'td', text: "Connections show with connection profile fields"
        assert_select 'td', text: "Mentor Profile Fields Index"
        assert_select 'td', text: "Mentee Profile Fields Index"
        assert_select 'td', text: "Connection Profile Fields Index"
      end
      assert_select 'table#post_api' do
        assert_select 'td', text: "User Create"
        assert_select 'td', text: "Connection Create"
      end
      assert_select 'table#put_api' do
        assert_select 'td', text: "User Update"
        assert_select 'td', text: "Connection Update"
      end
      assert_select 'table#delete_api' do
        assert_select 'td', text: "User Delete"
        assert_select 'td', text: "Connection Delete"
      end
    end
  end

end