require_relative './../test_helper.rb'

class ContactAdminSettingsControllerTest < ActionController::TestCase

  def test_only_superuser_allowed
    current_user_is :f_admin

    get :index
    assert_redirected_to super_login_path

    post :create
    assert_redirected_to super_login_path

    contact_admin_setting = ContactAdminSetting.create!(content: "hi", program_id: programs(:albers).id)
    patch :update, params: { id: contact_admin_setting.id }
    assert_redirected_to super_login_path
  end

  def test_index
    login_as_super_user
    current_user_is :f_admin

    assert_nil programs(:albers).contact_admin_setting
    get :index
    assert_response :success
    assert assigns(:contact_admin_setting).new_record?
  end

  def test_index_with_fields_present
    c = ContactAdminSetting.create!(:content => "hi", :program_id => programs(:albers).id)
    login_as_super_user
    current_user_is :f_admin

    get :index
    assert_response :success
    assert_equal c, assigns(:contact_admin_setting)
  end

  def test_create
    login_as_super_user
    current_user_is :f_admin

    assert_difference "ContactAdminSetting.count", 1 do
      post :create, params: { :contact_admin_setting => {:content => "hello"}}
    end

    last = ContactAdminSetting.last

    assert_equal "hello", last.content
    assert_equal "Settings have been saved successfully", flash[:notice]
    assert_redirected_to contact_admin_settings_path
  end

  def test_update
    c = ContactAdminSetting.create!(:content => "hi", :program_id => programs(:albers).id)
    assert_equal "hi", c.content

    login_as_super_user
    current_user_is :f_admin

    assert_no_difference "ContactAdminSetting.count" do
      patch :update, params: { id: c.id, contact_admin_setting: { content: "hello" } }
    end
    assert_equal "hello", programs(:albers).contact_admin_setting.reload.content
    assert_equal "Settings have been saved successfully", flash[:notice]
    assert_redirected_to contact_admin_settings_path
  end

  def test_globalized_columns
    login_as_super_user
    current_user_is :f_admin

    assert_difference "ContactAdminSetting.count" do
      post :create, params: { contact_admin_setting: { label_name: "en_label", content: "en_content" } }
    end
    contact_admin_setting = ContactAdminSetting.last

    assert_equal "en_content", contact_admin_setting.content
    assert_equal "en_label", contact_admin_setting.label_name
    assert_nil contact_admin_setting.contact_url
    assert_equal "Settings have been saved successfully", flash[:notice]

    ContactAdminSettingsController.any_instance.expects(:current_locale).at_least(0).returns("fr-CA")
    I18n.stubs(:locale).returns(:"fr-CA")

    assert_no_difference "ContactAdminSetting.count" do
      patch :update, params: { id: contact_admin_setting.id, contact_admin_setting: { label_name: "fr_label", content: "fr_content" } }
    end
    assert_equal 2, contact_admin_setting.reload.translations.count
    assert_equal "en_label", contact_admin_setting.translations[0].label_name
    assert_equal "en_content", contact_admin_setting.translations[0].content
    assert_equal "fr_label", contact_admin_setting.translations[1].label_name
    assert_equal "fr_content", contact_admin_setting.translations[1].content
    assert_nil contact_admin_setting.contact_url

    assert_no_difference "ContactAdminSetting.count" do
      patch :update, params: { id: contact_admin_setting.id, contact_admin_setting: { label_name: "fr_label", contact_url: "http://www.google.com" }, contact_link: "0" }
    end
    assert_equal 2, contact_admin_setting.reload.translations.count
    assert_equal "http://www.google.com", contact_admin_setting.contact_url
    assert_equal "en_label", contact_admin_setting.translations[0].label_name
    assert_nil contact_admin_setting.translations[0].content
    assert_equal "fr_label", contact_admin_setting.translations[1].label_name
    assert_nil contact_admin_setting.translations[1].content
  end
end