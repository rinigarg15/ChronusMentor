require_relative "./../../test_helper.rb"

class AuthConfigsHelperTest < ActionView::TestCase

  def setup
    super
    @auth_configs = programs(:org_primary).auth_configs
    @chronus_auth = @auth_configs.find(&:indigenous?)
  end

  def test_get_auth_config_actions_for_indigenous_auth
    self.stubs(:super_console?).returns(false)

    actions = get_auth_config_actions(@chronus_auth)
    assert_equal 1, actions.size
    assert_select_disable_action(actions[0], @chronus_auth)
  end

  def test_get_auth_config_actions_for_indigenous_auth_when_super_user
    self.stubs(:super_console?).returns(true)

    actions = get_auth_config_actions(@chronus_auth)
    assert_equal 2, actions.size
    assert_select_disable_action(actions[0], @chronus_auth)
    assert_select_password_policy_action(actions[1], @chronus_auth)
  end

  def test_get_auth_config_actions_for_non_indigenous_default_auth_when_super_user
    google_oauth = @auth_configs.find(&:google_oauth?)
    self.stubs(:super_console?).returns(true)

    actions = get_auth_config_actions(google_oauth)
    assert_equal 1, actions.size
    assert_select_disable_action(actions[0], google_oauth)
  end

  def test_get_auth_config_actions_for_custom_auth
    custom_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    self.stubs(:super_console?).returns(false)

    actions = get_auth_config_actions(custom_auth)
    assert_equal 2, actions.size
    assert_select_delete_action(actions[0], custom_auth)
    assert_select_customize_action(actions[1], custom_auth)
  end

  def test_get_auth_config_actions_for_custom_saml_auth_when_super_user
    custom_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    self.stubs(:super_console?).returns(true)

    actions = get_auth_config_actions(custom_auth)
    assert_equal 3, actions.size
    assert_select_delete_action(actions[0], custom_auth)
    assert_select_configure_action(actions[1])
    assert_select_customize_action(actions[2], custom_auth)
  end

  def test_get_auth_config_actions_for_custom_non_saml_auth_when_super_user
    custom_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::OPEN)
    self.stubs(:super_console?).returns(true)

    actions = get_auth_config_actions(custom_auth)
    assert_equal 2, actions.size
    assert_select_delete_action(actions[0], custom_auth)
    assert_select_customize_action(actions[1], custom_auth)
  end

  def test_get_auth_config_actions_for_disabled_auth
    @chronus_auth.disable!
    self.stubs(:super_console?).returns(false)

    actions = get_auth_config_actions(@chronus_auth)
    assert_equal 1, actions.size
    assert_select_enable_action(actions[0], @chronus_auth)
  end

  def test_get_auth_config_link_mobile_class
    assert_equal "", get_auth_config_link_mobile_class(@chronus_auth)

    @chronus_auth.stubs(:remote_login?).returns(true)
    assert_equal "cjs_external_link", get_auth_config_link_mobile_class(@chronus_auth)

    @chronus_auth.stubs(:use_browsertab_in_mobile?).returns(true)
    assert_equal "", get_auth_config_link_mobile_class(@chronus_auth)

    @chronus_auth.stubs(:remote_login?).returns(false)
    assert_equal "", get_auth_config_link_mobile_class(@chronus_auth)
  end

  def test_get_auth_config_button_for_indigenous_auth
    content = get_auth_config_button(@chronus_auth, "cjs-login-modal")

    assert_select_helper_function_block "a[href='javascript:void(0)'][data-toggle='modal'][data-target='#cjs-login-modal']", content, href: "javascript:void(0)" do
      assert_select "div.btn-group" do
        assert_select "div.btn-primary.cui-login-btn-icon" do
          assert_select "img[src='#{ChronusAuth::LOGO}'][width='28'][height='28']"
        end
        assert_select "div.btn-primary.cui-login-btn-label", text: "Email"
      end
      assert_no_select "div.cjs_external_link"
      assert_no_select "div.cui-login-btn-label-only"
    end
  end

  def test_get_auth_config_button_for_linkedin_oauth
    linkedin_oauth = @auth_configs.find(&:linkedin_oauth?)
    content = get_auth_config_button(linkedin_oauth, nil)

    assert_select_helper_function_block "a.cjs_external_link", content, href: login_path(auth_config_id: linkedin_oauth.id) do
      assert_select "div.btn-group" do
        assert_select "div.cui-btn-linkedin.cui-login-btn-icon" do
          assert_select "img[src='#{OpenAuthUtils::Configurations::Linkedin::LOGO}'][width='28'][height='28']"
        end
        assert_select "div.cui-btn-linkedin.cui-login-btn-label", text: "LinkedIn"
      end
    end
  end

  def test_get_auth_config_button_for_google_oauth
    google_oauth = @auth_configs.find(&:google_oauth?)
    content = get_auth_config_button(google_oauth, nil)

    assert_select_helper_function "a.cjs_external_link", content, count: 0
    assert_select_helper_function_block "a", content, href: login_path(auth_config_id: google_oauth.id) do
      assert_select "div.btn-group" do
        assert_select "div.cui-btn-google.cui-login-btn-icon" do
          assert_select "img[src='#{OpenAuthUtils::Configurations::Google::LOGO}'][width='28'][height='28']"
        end
        assert_select "div.cui-btn-google.cui-login-btn-label", text: "Google"
      end
    end
  end

  def test_get_auth_config_button_for_custom_auth
    custom_auth = programs(:org_primary).auth_configs.create!(auth_type: AuthConfig::Type::SAML, title: "Custom Login")
    content = get_auth_config_button(custom_auth, nil)

    assert_select_helper_function_block "a.cjs_external_link", content, href: login_path(auth_config_id: custom_auth.id) do
      assert_select "div.btn-group" do
        assert_select "div", count: 2
        assert_select "div.btn-primary.cui-login-btn-label-only", text: "Custom Login"
      end
    end
  end

  def test_render_login_id_field_for_indigenous_auth
    assert_select_helper_function_block "div.input-group", render_login_id_field(@chronus_auth, "sun@chronus.com") do
      assert_select "span.input-group-addon" do
        assert_select "i.fa-user"
      end
      assert_select "label.sr-only[for='email']", text: "Email"
      assert_select "input[type='email'][name='email'][placeholder='Email'][value='sun@chronus.com'][id='email']"
    end
  end

  def test_render_login_id_field_for_non_indigenous_auth
    @chronus_auth.stubs(:indigenous?).returns(false)

    assert_select_helper_function_block "div.input-group", render_login_id_field(@chronus_auth, nil) do
      assert_select "span.input-group-addon" do
        assert_select "i.fa-user"
      end
      assert_select "label.sr-only[for='email_#{@chronus_auth.id}']", text: "Username"
      assert_select "input[type='text'][name='email'][placeholder='Username'][id='email_#{@chronus_auth.id}']"
      assert_no_select "input[value]"
    end
  end

  def test_render_password_field_for_indigenous_auth
    assert_select_helper_function_block "div.input-group", render_password_field(@chronus_auth) do
      assert_select "span.input-group-addon" do
        assert_select "i.fa-key"
      end
      assert_select "label.sr-only[for='password']", text: "Password"
      assert_select "input[type='password'][name='password'][autocomplete='off'][placeholder='Password'][id='password']"
    end
  end

  def test_render_password_field_for_non_indigenous_auth
    @chronus_auth.stubs(:indigenous?).returns(false)

    assert_select_helper_function_block "div.input-group", render_password_field(@chronus_auth) do
      assert_select "span.input-group-addon" do
        assert_select "i.fa-key"
      end
      assert_select "label.sr-only[for='password_#{@chronus_auth.id}']", text: "Password"
      assert_select "input[type='password'][name='password'][autocomplete='off'][placeholder='Password'][id='password_#{@chronus_auth.id}']"
    end
  end

  private

  def assert_select_enable_action(action, auth_config)
    selector = %Q[a.btn[href="#{toggle_auth_config_path(auth_config, enable: true)}"][data-method="patch"][data-confirm="Are you sure you want to enable '#{auth_config.title}' login?"]]
    assert_select_helper_function selector, action, text: "Enable"
  end

  def assert_select_disable_action(action, auth_config)
    selector = %Q[a.btn[href="#{toggle_auth_config_path(auth_config)}"][data-method="patch"][data-confirm="Are you sure you want to disable '#{auth_config.title}' login?"]]
    assert_select_helper_function selector, action, text: "Disable"
  end

  def assert_select_delete_action(action, auth_config)
    selector = %Q[a.btn[href="#{auth_config_path(auth_config)}"][data-method="delete"][data-confirm="Users will no longer be able to login using '#{auth_config.title}'. Do you want to continue?"]]
    assert_select_helper_function selector, action, text: "Delete"
  end

  def assert_select_customize_action(action, auth_config)
    assert_select_helper_function "a.btn[href='#{edit_auth_config_path(auth_config)}']", action, text: "Customize"
  end

  def assert_select_configure_action(action)
    assert_select_helper_function "a.btn[href='#{saml_auth_config_saml_sso_path(tab: SamlAuthConfigController::SamlHeaders::UPLOAD_IDP_METADATA)}']", action, text: "Configure"
  end

  def assert_select_password_policy_action(action, auth_config)
    assert_select_helper_function "a.btn[href='#{edit_password_policy_auth_config_path(auth_config)}']", action, text: "Password Policy"
  end
end