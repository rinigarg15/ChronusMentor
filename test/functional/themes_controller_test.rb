require_relative './../test_helper.rb'

class ThemesControllerTest < ActionController::TestCase

  # This test checks how the index page is rendered to the super user.
  def test_index_page_rendered_super_user
    current_member_is :f_admin
    login_as_super_user
    get :index
    assert_response :success
    assert_equal 2, assigns(:themes).size
    assert_select "a", text: "Add theme"

    css_file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    post :create, params: { theme: { name: 'Green theme', css: css_file }, scope: "global" }
    programs(:org_primary).reload
    get :index
    assert_equal 3, assigns(:themes).size
    assert_select 'a.edit_link', text: 'Edit', count: 2
    assert_select 'a.delete_link', text: 'Delete', count: 2
    assert_select 'a.use_theme', count: 2
  end

  #This test checks what all are the actions allowed for the admin for the default theme
  def test_index_page_rendered_for_admin_with_only_default_theme
    current_member_is :f_admin
    get :index
    assert_response :success
    assert_no_select "a.edit_link"
    assert_no_select "a.delete_link"
    assert_select 'a.use_theme', count: 1
  end

  #This test checks what all actions are allowed for the admin
  def test_index_page_rendered_for_admin_two_themes
    create_theme

    current_member_is :f_admin
    get :index
    assert_response :success
    assert_equal 3, assigns(:themes).size
    assert_no_select 'a.edit_link'
    assert_no_select 'a.delete_link'
    assert_select 'a.use_theme', count: 2
    assert_equal themes(:wcag_theme), assigns(:current_theme)
    assert_equal programs(:org_primary), assigns(:current_program_or_organization)
    assert_false assigns(:is_themes_sub_program_view)
  end

  def test_index_page_rendered_for_admin_with_only_default_theme_for_foster_admin
    current_user_is :foster_admin
    get :index
    assert_response :success
    assert_no_select 'a.edit_link'
    assert_no_select 'a.delete_link'
    assert_select 'a.use_theme', count: 1
    assert_equal themes(:wcag_theme), assigns(:current_theme)
    assert_equal programs(:org_foster), assigns(:current_program_or_organization)
    assert_false assigns(:is_themes_sub_program_view)
  end

  #This test checks what all actions are allowed for the admin
  def test_index_page_rendered_for_program_admin
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_select 'a.edit_link', text: 'Edit', count: 0
    assert_select 'a.delete_link', text: 'Delete', count: 0
    assert_select 'a.use_theme'

    assert_equal themes(:wcag_theme), assigns(:current_theme)
    assert_equal programs(:albers), assigns(:current_program_or_organization)
    assert assigns(:is_themes_sub_program_view)
  end

  #This test checks what all actions are allowed for the admin
  def test_index_page_rendered_for_program_admin_two_themes
    program = programs(:albers)
    theme = create_theme(program: program)
    program.activate_theme(theme)

    current_user_is :f_admin
    get :index
    assert_response :success
    assert_equal 3, assigns(:themes).size
    assert_no_select 'a.edit_link'
    assert_no_select 'a.delete_link'
    assert_select 'a.use_theme', count: 2
    assert_equal theme, assigns(:current_theme)
    assert_equal program, assigns(:current_program_or_organization)
    assert assigns(:is_themes_sub_program_view)
  end

  def test_index_not_rendered_for_mentor
    current_member_is :f_mentor
    assert_permission_denied { get :index }
  end

  def test_index_not_rendered_for_mentee
    current_member_is :f_student
    assert_permission_denied { get :index }
  end

  def test_new_renders_for_admin_as_super_user
    current_member_is :f_admin
    login_as_super_user
    get :new
    assert_response :success
    assert_template 'new'
  end

  def test_new_redirected_for_admin
    current_member_is :f_admin
    get :new
    assert_redirected_to super_login_path
  end

  def test_new_should_set_program_id_if_present
    current_member_is :f_admin
    login_as_super_user
    get :new
    assert_equal members(:f_admin).organization.id, assigns(:theme).program_id
    assert_response :success
    assert_select "input[id=\"scope_global\"][name=\"scope\"][type=\"radio\"][value=\"global\"]"
    assert_select "input[checked=\"checked\"][id=\"scope_private\"][name=\"scope\"][type=\"radio\"][value=\"private\"]"
  end

  def test_new_not_rendered_for_mentor_as_super_user
    current_member_is :f_mentor
    login_as_super_user
    assert_permission_denied  {get :new}
  end

  def test_edit_not_rendered_for_admin
    theme = create_theme

    current_member_is :f_admin
    get :edit, params: { id: theme.id }
    assert_redirected_to super_login_path
  end

  def test_edit_rendered_for_super_user
    current_member_is :f_admin
    login_as_super_user
    get :edit, params: { id: Theme.first.id }
    assert_response :success
  end

  def test_destroy_not_rendered_for_admin
    theme = create_theme

    current_member_is :f_admin
    get :destroy, params: { id: theme.id }
    assert_redirected_to super_login_path
  end

  # When super user clicks update button without making any changes
  def test_update_by_super_user_with_no_params
    current_member_is :f_admin
    login_as_super_user

    ss = create_theme
    put :update, params: { id: ss.id }
    assert_redirected_to themes_path
  end

  #Tests the creation of a global theme
  def test_create_global_theme_success
    current_member_is :f_admin
    login_as_super_user
    css_file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')

    post :create, params: { theme: { name: 'Green theme', css: css_file }, scope: "global" }
    assert_redirected_to themes_path
    assert Theme.last.program.nil?
  end

  # Tests the creation of a theme private to a program
  def test_create_private_theme_success
    current_member_is :f_admin
    login_as_super_user
    css_file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')

    post :create, params: { theme: { name: 'Green theme', css: css_file }, scope: "private" }
    assert_redirected_to themes_path
    assert_equal Theme.last.program, programs(:org_primary)
  end

  # Test the creation failure scenario when the uploaded file is not a css file
  def test_create_failure
    current_member_is :f_admin
    login_as_super_user
    css_file = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')

    post :create, params: { theme: { name: 'Green theme', css: css_file }, scope: 'global' }
    assert_response :success
    assert_template 'new'
    assert_equal ["file type is wrong"], assigns(:theme).errors[:css_content_type]
  end

  def test_create_with_invalid_theme_vars
    Theme.any_instance.unstub(:check_theme_var_list)
    current_member_is :f_admin
    login_as_super_user
    css_file = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    assert_no_difference "Theme.count" do
      post :create, params: { theme: { name: 'Green theme', css: css_file }, scope: 'global' }
    end
    assert_response :success
    assert_template 'new'
    assert_equal ["Important styles are missing."], assigns(:theme).errors[:vars_list]
  end

  # Test the update failure scenario when the uploaded file is not a css file
  def test_update_failure
    current_member_is :f_admin
    login_as_super_user
    ss = create_theme
    css_file_png = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')

    put :update, params: { id: ss.id, theme: { css: css_file_png }, scope: 'global' }
    assert_response :success
    assert_template 'edit'
    assert_equal ["file type is wrong"], assigns(:theme).errors[:css_content_type]
  end

  def test_update_with_invalid_theme_vars
    Theme.any_instance.unstub(:check_theme_var_list)
    current_member_is :f_admin
    login_as_super_user
    ss = create_theme
    css_file_png = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')

    put :update, params: { id: ss.id, theme: { css: css_file_png }, scope: 'global' }
    assert_response :success
    assert_template 'edit'
    assert_equal ["Important styles are missing."], assigns(:theme).errors[:vars_list]
  end

  # Test the assignment of active theme for a program
  def test_update_active_theme_for_a_org
    org = programs(:org_primary)
    with_cache do
      current_member_is :f_admin
      login_as_super_user
      ss = create_theme
      modern_green = org.active_theme
      assert_equal 'Default', modern_green.name
      get :index
      assert_equal true, ActionController::Base.new.fragment_exist?(CacheConstants::Programs::THEME_STYLESHEET.call(org.id))
      GlobalizationUtils.run_in_locale(:es) do
        assert_equal true, ActionController::Base.new.fragment_exist?(CacheConstants::Programs::THEME_STYLESHEET.call(org.id))
      end
      put :update, params: { id: ss.id , activate: "true" }
      assert_equal false, ActionController::Base.new.fragment_exist?(CacheConstants::Programs::THEME_STYLESHEET.call(org.id))
      GlobalizationUtils.run_in_locale(:es) do
        assert_equal false, ActionController::Base.new.fragment_exist?(CacheConstants::Programs::THEME_STYLESHEET.call(org.id))
      end
      assert_redirected_to themes_path
      org.reload
      assert_equal org.active_theme, ss
    end
  end

  # Test the assignment of active theme for a program
  def test_update_active_theme_for_a_program
    current_user_is :f_admin
    login_as_super_user
    ss = create_theme

    programs(:albers).update_attributes(theme_id: nil)
    assert_nil programs(:albers).active_theme

    put :update, params: { id: ss.id , activate: "true" }
    assert_redirected_to themes_path
    assert_equal programs(:albers).reload.active_theme, ss
  end

  def test_update_all_programs
    org = programs(:org_primary)
    current_member_is :f_admin
    login_as_super_user
    ss = create_theme

    put :update, params: { id: ss.id , activate: "true" , program: "Yes"}
    assert_redirected_to themes_path
    org.programs.each do |program|
      assert_equal program.reload.active_theme, ss
    end
  end

  #Updating the css file
  def test_update_css_file
    current_member_is :f_admin
    login_as_super_user
    ss = create_theme
    assert_equal 'test_file.css', ss.reload.css_file_name
    new_css_file = fixture_file_upload(File.join('files', 'test_file_1.css'), 'text/css')

    put :update, params: { id: ss.id, theme: { css: new_css_file } }
    assert_redirected_to themes_path
    # assert_equal '', flash[:notice]
    assert_equal 'test_file_1.css', ss.reload.css_file_name
  end

  def test_update_css_file_with_cache
    org = programs(:org_primary)
    with_cache do
      current_member_is :f_admin
      login_as_super_user

      ss = create_theme
      put :update, params: { id: ss.id, activate: "true" }

      get :index
      assert_equal true, ActionController::Base.new.fragment_exist?(CacheConstants::Programs::THEME_STYLESHEET.call(org.id))

      assert_equal 'test_file.css', ss.reload.css_file_name
      new_css_file = fixture_file_upload(File.join('files', 'test_file_1.css'), 'text/css')
      put :update, params: { id: ss.id, theme: { css: new_css_file } }
      assert_equal false, ActionController::Base.new.fragment_exist?(CacheConstants::Programs::THEME_STYLESHEET.call(org.id))
      assert_redirected_to themes_path
    end
  end

  # Testing the deletion scenario
  def test_delete_private_theme
    current_member_is :f_admin
    login_as_super_user

    ss = create_theme
    put :update, params: { id: ss.id, activate: 'true' }
    programs(:org_primary).reload
    assert_equal programs(:org_primary).active_theme, ss
    assert_difference 'Theme.count', -1 do
      post :destroy, params: { id: ss.id }
      assert_redirected_to themes_path
    end
    programs(:org_primary).reload
    assert_equal programs(:org_primary).active_theme, Theme.global.default.first
  end

  def test_delete_global_theme
    current_member_is :f_admin
    login_as_super_user

    ss = create_theme(program: nil)
    put :update, params: { id: ss.id, activate: 'true' }
    programs(:org_primary).active_theme = ss
    programs(:org_primary).save!
    programs(:org_primary).reload
    assert_equal ss, programs(:org_primary).active_theme
    assert_difference 'Theme.count', -1 do
      post :destroy, params: { id: ss.id }
      assert_redirected_to themes_path
    end
    programs(:org_primary).reload
    assert_equal Theme.global.default.first, programs(:org_primary).active_theme
    assert_equal themes(:wcag_theme), programs(:org_anna_univ).active_theme
  end

  def test_build_new_theme
    login_as_super_user
    post :build_new, params: { theme: {
      "button-bg-color" => "black",
      "button-font-color" => "green",
      "header-bg-color" => "black",
      "header-font-color" => "green"
    }}
    assert_response :success
    assert_equal "text/css", response.content_type
    assert_equal "attachment; filename=\"theme.css\"", response.header["Content-Disposition"]
  end
end
