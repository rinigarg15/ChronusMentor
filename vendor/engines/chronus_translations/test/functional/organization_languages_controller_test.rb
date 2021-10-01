# TODO Hook along with the main rails tests
require_relative '../test_helper'

class OrganizationLanguagesControllerTest < ActionController::TestCase

  def test_index
    current_member_is :f_admin

    get :index
    assert_response :success
    assert_equal organization_languages(:hindi, :telugu), assigns(:organization_languages)
    assert_no_select "th", text: "Programs Enabled For"
  end

  def test_index_with_super_console
    current_member_is :f_admin
    login_as_super_user

    get :index
    assert_response :success
    assert_equal organization_languages(:hindi, :telugu), assigns(:organization_languages)
    assert_select "th", text: "Programs Enabled For"
  end

  def test_index_with_super_console_for_standalone_org
    current_member_is :foster_admin
    login_as_super_user

    get :index
    assert_response :success
    assert_equal [], assigns(:organization_languages)
    assert_no_select "th", text: "Programs Enabled For"
  end

  def test_new
    current_member_is :f_admin

    get :new, params: { language_id: languages(:hindi).id}
    assert_response :success
    organization_language = assigns(:organization_language)

    assert_equal true, organization_language.new_record?
    assert_no_select "*[name='organization_language[enabled_program_ids][]']"
  end

  def test_new_with_super_console
    current_member_is :f_admin
    login_as_super_user

    get :new, params: { language_id: languages(:hindi).id}
    assert_response :success
    organization_language = assigns(:organization_language)

    assert_equal true, organization_language.new_record?
    assert_select "*[name='organization_language[enabled_program_ids][]']"
  end

  def test_new_with_super_console_for_standalone_org
    current_member_is :foster_admin
    login_as_super_user

    get :new, params: { language_id: languages(:hindi).id}
    assert_response :success
    organization_language = assigns(:organization_language)

    assert_equal true, organization_language.new_record?
    assert_no_select "*[name='organization_language[enabled_program_ids][]']"
  end

  def test_edit
    current_member_is :f_admin

    get :edit, params: { id: organization_languages(:hindi)}
    assert_response :success
    assert_equal organization_languages(:hindi), assigns(:organization_language)
    assert_no_select "*[name='organization_language[enabled_program_ids][]']"
  end

  def test_edit_with_super_console
    current_member_is :f_admin

    get :edit, params: { id: organization_languages(:hindi)}
    assert_response :success
    assert_equal organization_languages(:hindi), assigns(:organization_language)
    assert_no_select "*[name='organization_language[enabled_program_ids][]']"
  end


  def test_update_status_availability_none_for_existing_organization_language
    current_member_is :f_admin
    assert_difference('ProgramLanguage.count', -5) do
      post :update_status, params: { organization_language: { language_id: languages(:hindi).id, enabled: OrganizationLanguage::EnabledFor::NONE.to_s }}
    end
    assert_redirected_to organization_languages_path
    assert_equal 'The Language Settings has been successfully updated.', flash[:notice]
  end

  def test_update_status_availability_none_for_new_organization_language
    current_member_is :f_admin
    new_lang = create_language
    assert_no_difference('ProgramLanguage.count') do
      post :update_status, params: { organization_language: { language_id: new_lang.id, enabled: OrganizationLanguage::EnabledFor::NONE.to_s }}
    end
    assert_redirected_to organization_languages_path
    assert_equal 'The Language Settings has been successfully updated.', flash[:notice]
  end

  def test_update_status_availability_none_for_new_organization_language_with_super_console
    current_member_is :f_admin
    login_as_super_user

    new_lang = create_language
    assert_no_difference('ProgramLanguage.count') do
      post :update_status, params: { organization_language: { language_id: new_lang.id, enabled: OrganizationLanguage::EnabledFor::NONE.to_s, enabled_program_ids: [programs(:albers).id.to_s] }}
    end
    assert_redirected_to organization_languages_path
    assert_equal 'The Language Settings has been successfully updated.', flash[:notice]
  end

  def test_update_status_availability_only_admin_for_existing_organization_language
    current_member_is :f_admin
    assert_no_difference('OrganizationLanguage.count') do
      post :update_status, params: { organization_language: { language_id: languages(:hindi).id, enabled: OrganizationLanguage::EnabledFor::ADMIN.to_s }}
    end
    assert_redirected_to organization_languages_path
    assert organization_languages(:hindi).enabled_for_admin?
    assert_equal 'The Language Settings has been successfully updated.', flash[:notice]
  end

  def test_update_status_availability_only_admin_for_existing_organization_language_with_super_console
    current_member_is :f_admin
    login_as_super_user

    assert_no_difference('OrganizationLanguage.count') do
      assert_difference('ProgramLanguage.count', -4) do
        post :update_status, params: { organization_language: { language_id: languages(:hindi).id, enabled: OrganizationLanguage::EnabledFor::ADMIN.to_s, enabled_program_ids: [programs(:albers).id.to_s] }}
      end
    end
    assert_redirected_to organization_languages_path
    assert organization_languages(:hindi).enabled_for_admin?
    assert_equal 'The Language Settings has been successfully updated.', flash[:notice]
  end


  def test_update_status_availability_all_for_new_organization_language
    org = programs(:org_primary)
    current_member_is :f_admin
    org.organization_languages.destroy_all

    assert_difference('OrganizationLanguage.count', +1) do
      post :update_status, params: { organization_language: {language_id: languages(:hindi).id, enabled: OrganizationLanguage::EnabledFor::ALL.to_s }}
    end
    assert_redirected_to organization_languages_path
    assert org.reload.organization_languages[0].enabled?
    assert_equal 'The Language Settings has been successfully updated.', flash[:notice]
  end
end
