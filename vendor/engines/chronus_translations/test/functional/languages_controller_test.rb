
# TODO Hook along with the main rails tests
require_relative '../test_helper'

class LanguagesControllerTest < ActionController::TestCase

  def test_index
    login_as_super_user

    get :index
    assert_response :success
    assert_equal languages(:hindi, :telugu), assigns(:languages)
  end

  def test_new_should_succeed
    login_as_super_user

    get :new
    assert_response :success
    language = assigns(:language)

    assert_equal true, language.new_record?
  end

  def test_create_should_fail
    login_as_super_user
    assert_no_difference 'Language.count' do
      post :create, params: { language: { title: '', display_title: '', language_name: '', enabled: false } }
    end
    assert_response :success
    assert_template "new"
    language = assigns(:language)
    assert_equal true, language.new_record?
    assert_equal 3, language.errors.size
    assert_equal 'Cannot create Language', flash[:error]
  end

  def test_create_should_succeed
    login_as_super_user
    assert_difference 'Language.count', +1 do
      post :create, params: { :language => {
        :title          => 'French',
        :display_title  => 'Frenchulu',
        :language_name  => 'fr',
        :enabled        => false
      }}
    end

    assert_redirected_to languages_path
    language = assigns(:language)

    assert_equal 'French',    language.title
    assert_equal 'Frenchulu', language.display_title
    assert_equal 'fr',        language.language_name
    assert_equal false,       language.enabled

    assert_equal 'Language created successfully', flash[:notice]

  end

  def test_edit
    login_as_super_user

    get :edit, params: { :id => languages(:hindi)}
    assert_response :success
    assert_equal languages(:hindi), assigns(:language)
  end

  def test_update_should_fail
    login_as_super_user
    put :update, params: { :id => languages(:hindi).id,
                 :language => { :display_title => '',
                                :title         => '',
                                :language_name => ''}
                              }
    assert_response :success
    assert_template "edit"
    language = assigns(:language)

    assert_equal 3, language.errors.size
    assert_equal 'Cannot save Language', flash[:error]
  end

  def test_update_should_succeed
    languages(:telugu).destroy
    login_as_super_user
    put :update, params: { :id => languages(:hindi).id, :language => {
      :title          => 'New Hindi',
      :display_title  => 'New Hindilu',
      :language_name  => 'es',
      :enabled        => false
    }}

    assert_redirected_to languages_path
    language = assigns(:language)

    assert_equal 'New Hindi',   language.title
    assert_equal 'New Hindilu', language.display_title
    assert_equal 'es',      language.language_name
    assert_equal false,         language.enabled

    assert_equal 'Language saved successfully', flash[:notice]
  end

  def test_destroy
    login_as_super_user
    assert_difference('Language.count', -1) do
      delete :destroy, params: { :id => languages(:hindi).id}
    end

    assert_redirected_to languages_path
    assert_equal 'Language deleted successfully', flash[:notice]
  end

  def test_set_current_without_login
    programs(:org_foster).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    create_organization_language( {:organization => programs(:org_foster), :enabled => OrganizationLanguage::EnabledFor::ALL, :language => languages(:hindi)})
    current_program_is programs(:foster)
    path = new_language_path
    request.env["HTTP_REFERER"] = path
    put :set_current, params: { :locale => 'de', :redirect_to => path}

    assert_redirected_to path
    assert_equal 'de', get_cookie(:current_locale)
  end

  def test_set_current_without_login_with_get_method
    programs(:org_foster).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    create_organization_language( {:organization => programs(:org_foster), :enabled => OrganizationLanguage::EnabledFor::ALL, :language => languages(:hindi)})
    current_program_is programs(:foster)
    path = new_language_path
    request.env["HTTP_REFERER"] = path
    get :set_current, params: { :locale => 'de', :redirect_to => path}

    assert_redirected_to path
    assert_equal 'de', get_cookie(:current_locale)
  end

  def test_set_current_without_login_with_get_method_with_set_locale
    programs(:org_foster).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    create_organization_language( {:organization => programs(:org_foster), :enabled => OrganizationLanguage::EnabledFor::ALL, :language => languages(:hindi)})
    current_program_is programs(:foster)
    path = new_language_path(set_locale: 'en')
    request.env["HTTP_REFERER"] = path
    get :set_current, params: { :locale => 'de', :redirect_to => path}
    assert_match /set_locale_ignore=en/, path
    assert_redirected_to path
    assert_equal 'de', get_cookie(:current_locale)
  end

  def test_set_current_with_login
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)
    current_user_is users(:f_student)

    put :set_current, params: { :locale => 'de'}

    assert_redirected_to program_root_path
    assert_equal 'de', get_cookie(:current_locale)
    assert_equal :de, Language.for_member(users(:f_student).member)
  end

  def test_set_current_non_org_without_login_with_get_method
    LanguagesController.any_instance.stubs(:is_mobile_app?).returns(true)
    get :set_current_non_org, params: { :locale => 'de'}
    assert_redirected_to mobile_v2_verify_organization_path
    assert_equal 'de', get_cookie(:current_locale)
  end

  def test_set_current_non_org_without_login_with_get_method_and_path
    LanguagesController.any_instance.stubs(:is_mobile_app?).returns(true)
    path = new_language_path
    request.env["HTTP_REFERER"] = path
    get :set_current_non_org, params: { :locale => 'de', :redirect_to => path}
    assert_redirected_to path
    assert_equal 'de', get_cookie(:current_locale)
  end
end
