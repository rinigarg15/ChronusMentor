# encoding: utf-8

require_relative './../test_helper.rb'

class PagesControllerTest < ActionController::TestCase
  def setup
    super
    current_program_is(@cur_program || :albers)
    page_role = create_role(:name => 'page_manager')
    add_role_permission(page_role, 'manage_custom_pages')
    @page_admin = create_user(:role_names => ['page_manager'])
  end

  def test_index_should_render_program_and_organization_pages
    pages = []
    3.times { |i| pages << create_page(:title => "Page #{i}") }

    get :index
    assert_response :success
    assert_equal("Page 0", assigns(:page).title)
    assert_equal pages, assigns(:pages)
    assert_no_page_banner
  end

  def test_handle_set_locale
    programs(:org_primary).enable_feature(FeatureName::LANGUAGE_SETTINGS)

    get :index, params: { set_locale: "de"}
    assert_match(/Hindi \(Hindilu\)\<span class="fa arrow/, response.body)
    assert_match(/Čóɳťáčť Administrator/, response.body)
    assert_equal 'de', get_cookie(:current_locale)
  end

  def test_index_should_render_the_first_page
    Page.destroy_all
    3.times { |i| create_page(:title => "Page #{i}") }
    get :index
    assert_response :success
    assert_equal("Page 0", assigns(:page).title)
    assert_no_page_banner
  end

  def test_show_standalone_program
    program = programs(:foster)
    organization = program.organization
    assert organization.standalone?
    organization_pages = organization.pages
    3.times { |i| create_page(title: "Page #{i}", program: program) }
    page = organization.pages.first

    current_program_is :foster
    get :show, params: { id: page.id}
    assert_response :success
    assert_equal page, assigns(:page)
    assert_equal organization_pages, assigns(:pages)
    assert_equal 6, assigns(:base_pages_scope).size
  end

  def test_index_and_show_page_should_be_accessible_without_login
    page = create_page # this create an albers program  page
    get :show, params: { :id => page.id}
    assert_response :success

    get :index
    assert_response :success
    assert_no_page_banner
  end

  def test_should_show_page
    current_program_is :foster
    pages = 3.times.map do |i|
      create_page(title: "Page #{i}", content: "This is the #{i} test content", program: programs(:org_foster))
    end

    get :show, params: { :id => pages[0].id}

    # The contents should be of page 0.
    assert_select "div.inner_main_content" do
      assert_select "div.page_content_text", :text => "This is the 0 test content"
      assert_select "script", text: "\n//<![CDATA[\n\n  jQuery(document).ready(function(){\n    OverViewPage.updatePlayStoreLink(\"https://play.google.com/store/apps/details?id=com.chronus.mentorp&amp;referrer=utm_source%3D#{programs(:org_foster).url}%26utm_medium%3Doverview_page\");\n  });\n\n//]]>\n"
    end
    assert_select "div#page_canvas"

    # There should be no edit button
    assert_no_select "div#title_actions > div#action_2"
    assert_no_page_banner
  end

  def test_should_not_show_other_sub_program_page_in_multi_program_organization
    current_program_is :psg
    page = create_page(
      :title => "Page",
      :content => "This is the test content",
      :program => programs(:ceg)
    )

    get :show, params: { :id => page.id}
    assert_redirected_to root_path
  end

  def test_should_redirect_to_about_page_when_invalid_page_is_accessed
    current_program_is :ceg

    get :show, params: { :id => 0}
    assert_redirected_to about_path
    assert_equal "The page you are trying to access doesn't exist.", flash[:error]
  end

  def test_should_redirect_to_root_page_when_non_admin_user_access_program_level_drafted_page
    page = create_page(published: false)
    current_user_is :f_mentor

    get :show, params: { :id => page.id}
    assert_redirected_to root_path
    assert_equal "The page you are trying to access doesn't exist.", flash[:error]
  end

  def test_should_redirect_to_root_path_when_non_admin_access_org_level_drafted_page
    page = create_page(program: programs(:org_primary), published: false)
    current_user_is :f_mentor

    get :show, params: { :id => page.id, :organization_level => true, :redirected => true}
    assert_redirected_to root_path
    assert_equal "The page you are trying to access doesn't exist.", flash[:error]
  end

  def test_should_redirect_to_login_page_when_non_logged_in_user_access_page_that_is_visible_to_logged_in_user_only
    page = create_page(visibility: Page::Visibility::LOGGED_IN)
    program = programs(:albers)
    program.enable_feature(FeatureName::LOGGED_IN_PAGES)

    get :show, params: { :id => page.id}
    assert_redirected_to login_path
    assert_equal "Please log in to access the page.", flash[:error]
  end

  def test_should_display_page_when_accessed_page_that_is_visible_to_logged_in_user_only_and_program_doesnot_support_loggedin_page_feature
    page = create_page(visibility: Page::Visibility::LOGGED_IN)
    program = programs(:albers)
    program.enable_disable_feature(FeatureName::LOGGED_IN_PAGES, false)

    get :show, params: { :id => page.id}
    assert_response :success
  end

  def test_should_display_page_when_accessed_page_that_is_visible_to_all_users
    page = create_page
    get :show, params: { :id => page.id}
    assert_response :success
  end

  def test_should_redirect_to_org_page_when_accessed_in_sub_program_in_multi_program_organization
    current_program_is :psg
    page = create_page(:title => "Page", :content => "This is the test content", :program => programs(:org_anna_univ))

    get :show, params: { :id => page.id}
    assert_redirected_to page_url(page.id, :organization_level => true, :redirected => true)
  end

  def test_only_admin_should_be_able_to_edit_a_page
    current_user_is :f_mentor
    pages = create_test_pages

    assert_permission_denied do
      get :edit, params: { :id => pages[1].id}
    end
  end

  def test_programs_reordering_should_list_mentoring_tracks_only
    current_user_is :f_admin

    get :programs_reordering

    assert_equal programs(:org_primary).tracks.ordered.pluck(:id).uniq, assigns(:programs).collect(&:id)
  end

  def test_programs_reordering_should_list_mentoring_tracks_only_for_career_development_organization
    current_user_is :nch_admin

    get :programs_reordering

    assert_equal programs(:org_nch).tracks.ordered.pluck(:id).uniq, assigns(:programs).collect(&:id)
  end


  def test_only_admin_should_be_able_to_delete_a_page
    current_user_is :f_mentor
    pages = create_test_pages
    assert_permission_denied do
      post :destroy, params: { :id => pages[1].id}
    end
  end

  def test_should_update_a_page
    current_user_is @page_admin
    pages = create_test_pages

    assert_equal("Page 1", pages[1].title)
    assert_equal("This is the 1 test content", pages[1].content)
    post :update, params: { :id => pages[1].id, :page => {:title => 'new title', :content => 'new content'}}
    assert_redirected_to page_path(pages[1].id)
    assert_equal(pages[1].id, assigns(:page).id)
    assert_equal("new title", assigns(:page).title)
    assert_equal("new content", assigns(:page).content)
  end

  def test_should_update_a_page_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    pages = create_test_pages
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")
    assert_no_difference "VulnerableContentLog.count" do
      post :update, params: { :id => pages[1].id, :page => {:title => 'new title', :content => 'new content<script>alert(10);</script>'}}
    end
  end

  def test_should_update_a_page_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    pages = create_test_pages
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")
    assert_difference "VulnerableContentLog.count" do
      post :update, params: { :id => pages[1].id, :page => {:title => 'new title', :content => 'new content<script>alert(10);</script>'}}
    end
  end

  def test_should_publish_a_page
    current_user_is @page_admin
    pages = create_test_pages
    page = pages[1]

    assert_equal("Page 1", page.title)
    assert_equal("This is the 1 test content", page.content)
    page.update_attribute(:published, false)
    put :publish, params: { :id => page.id}
    assert_redirected_to page_path(page.id)
    assert_equal(page.id, assigns(:page).id)
    assert assigns(:page).published?
  end

  def test_should_delete_a_page
    current_user_is @page_admin
    page = create_page
    assert_difference 'Page.count', -1 do
      post :destroy, params: { :id => page.id}
    end
    assert_redirected_to pages_path
  end

  def test_when_there_are_no_pages
    current_user_is @page_admin
    programs(:org_primary).pages.destroy_all
    assert programs(:org_primary).pages.empty?

    get :index, params: { login_mode: "signup"}
    assert_response :success
    assert_select "div.no_pages", text: "There are no pages! Add page"
    assert_equal "signup", assigns(:login_mode)
    assert_no_match(/login_mode=strict/, @response.body)
  end

  def test_only_admin_should_see_the_edit_link_and_add_link
    current_user_is @page_admin
    pages = create_test_pages

    get :show, params: { :id => pages[0].id}
    assert_response :success
    assert_select "div.page_content" do
      assert_select "a[href=?]", edit_page_path(pages[0].id), :text => "Edit"
      assert_select "a", :text => "Delete"
    end
    assert_select "a.add_new_page_button"
  end

  def test_non_logged_in_users_should_see_join_button_in_the_pages
    page = create_page
    get :index
    assert_response :success

    # The login link on the program header should have the special param
    assert_select "nav#chronus_header" do
      assert_select "ul#header_actions" do
        assert_select "a[href=?]", login_path(mode: 'strict'), text: "Login"
      end
    end
    assert_no_page_banner
  end

  def test_users_should_not_see_header_if_white_label_enabelled
    org = programs(:org_primary)
    org.white_label = true
    org.save!

    page = create_page
    get :index
    assert_response :success
    assert_no_select  ".cui-powered-by-label"
  end

  def test_users_should_see_updated_favicon
    org = programs(:org_primary)
    org.favicon_link = "https://s3.amazonaws.com/chronus-mentor-assets/spe/images/spe_favicon.ico"
    org.save!

    page = create_page
    get :index
    assert_response :success
    assert_match  /spe_favicon.ico/, response.body
  end

  def test_non_logged_in_users_should_not_see_join_button_in_the_pages_when_disabled
    mentor_role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.save
    mentee_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)
    mentee_role.membership_request = false
    mentee_role.save

    page = create_page
    get :index
    assert_response :success

    # The login link on the program header should have the special param
    assert_select "nav#chronus_header" do
      assert_select "ul#header_actions" do
        assert_select "a[href=?]", login_path(mode: 'strict'), text: "Login"
      end
    end
    assert_no_page_banner
  end

  def test_should_not_show_join_button_for_logged_in_users
    current_user_is :f_mentor
    page = create_page
    get :show, params: { :id => page.id}
    assert_response :success
    assert_select "div.pages_submenu" do
      assert_select "ul" do
        assert_select "li[class=?]", "join_button clearfix", 0
      end
    end
    assert_page_title("Program Overview pages")
  end

  def test_empty_page_content
    current_user_is @page_admin
    page = create_page(:content => "")
    get :show, params: { :id => page.id}
    assert_response :success
    assert_select "div.inner_main_content" do
      assert_select "div.empty_content"
    end
  end

  PAGE_TITLE = "Monkey Overview"
  DUMMY_CONTENT = "Test is this"
  def test_should_get_edit_only_for_admin
    current_user_is @page_admin
    page = create_page(:title => PAGE_TITLE, :content => DUMMY_CONTENT)
    get :edit, params: { :id => page.id}
    assert_response :success
    assert_page_banner
    assert_ckeditor_rendered
  end

  def test_should_not_get_edit_only_for_non_admins
    current_user_is :f_mentor
    page = create_page(:title => PAGE_TITLE, :content => DUMMY_CONTENT)
    assert_permission_denied do
      get :edit, params: { :id => page.id}
    end
  end

  def test_should_get_new
    current_user_is @page_admin
    3.times { |i| create_page(:title => "Page #{i}") }
    get :new
    assert_response :success
    assert_template "edit"
    assert_equal(programs(:albers).id, assigns(:page).program_id)
    assert_select ".pages_submenu" do
      assert_select "ul" do
        assert_select "li#new_page" do
          assert_select "a[href=?]", new_page_path
        end
      end
    end
    assert_page_banner
    assert_ckeditor_rendered
  end

  def test_should_not_get_new_for_non_admins
    current_user_is :f_mentor
    assert_permission_denied { get :new }
  end

  def test_should_create_page
    current_user_is @page_admin
    new_page_title = "Page new title"
    new_page_content = "Kontent image"
    post :create, params: { :page => {
      :title => new_page_title,
      :content => new_page_content
    }}
    page = assigns(:page)
    assert_equal(programs(:albers), page.program)
    assert_equal(new_page_title, page.title)
    assert_equal(new_page_content, page.content)
    assert_redirected_to page_path(page)
  end

  def test_should_create_page_with_vulnerable_content_with_version_v1
    current_user_is :f_admin
    new_page_title = "Page new title"
    new_page_content = "Kontent image<script>alert(10);</script>"
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v1")

    assert_no_difference "VulnerableContentLog.count" do
      post :create, params: { :page => {
        :title => new_page_title,
        :content => new_page_content
      }}
    end
  end

  def test_should_create_page_with_vulnerable_content_with_version_v2
    current_user_is :f_admin
    new_page_title = "Page new title"
    new_page_content = "Kontent image<script>alert(10);</script>"
    programs(:org_primary).security_setting.update_attribute(:sanitization_version, "v2")

    assert_difference "VulnerableContentLog.count" do
      post :create, params: { :page => {
        :title => new_page_title,
        :content => new_page_content
      }}
    end
  end

  def test_mobile_prompt_access_denied
    @controller.stubs(:set_previous_url_mobile_prompt)
    current_user_is :f_admin
    assert_permission_denied do
      get :mobile_prompt
      assert_false @controller.mobile_browser?
    end
  end

  def test_mobile_prompt
    @controller.stubs(:set_previous_url_mobile_prompt)
    @controller.expects(:show_mobile_prompt).never
    @controller.expects(:handle_terms_and_conditions_acceptance).never
    @controller.expects(:handle_pending_profile_or_unanswered_required_qs).never
    stub_mobile_browser
    session[:return_to_url] = "random_url"
    current_user_is :f_admin
    get :mobile_prompt
    assert_equal "random_url", assigns(:return_to_url)
    assert_equal true, assigns(:single_page_layout)
    assert_equal true, assigns(:mobile_prompt)
  end

  def test_mobile_prompt_with_mobile_app_login
    stub_mobile_browser
    current_user_is :f_admin
    get :mobile_prompt, params: { mobile_app_login: true, auth_config_id: 1, token_code: "gth", uniq_token: "uniq_token"}
    assert_equal new_session_url(token_code: "gth", auth_config_id: 1, uniq_token: "uniq_token"), assigns(:return_to_url)
    assert assigns(:mobile_app_login)
  end

  def test_mobile_prompt_with_no_session_url
    @controller.stubs(:set_previous_url_mobile_prompt)
    stub_mobile_browser(false)
    current_user_is :f_admin
    get :mobile_prompt
    assert_equal "http://primary.#{DEFAULT_DOMAIN_NAME}/p/albers/", assigns(:return_to_url)
    assert_equal true, assigns(:single_page_layout)
    assert_equal true, assigns(:mobile_prompt)
  end

  def test_mobile_prompt_end_user
    @controller.stubs(:set_previous_url_mobile_prompt)
    stub_mobile_browser(false)
    session[:return_to_url] = "random_url"
    current_user_is :f_mentor
    get :mobile_prompt
    assert_equal "random_url", assigns(:return_to_url)
    assert_equal true, assigns(:single_page_layout)
    assert_equal true, assigns(:mobile_prompt)
  end

  def test_mobile_prompt_not_mobile_browser
    @controller.stubs(:mobile_browser?).returns(false)
    current_user_is :f_mentor
    get :mobile_prompt, params: { mobile_app_login: true }
    assert_redirected_to new_session_url
  end

  def test_should_create_organization_page_if_standalone
    current_user_is :foster_admin

    new_page_title = "Page new title"
    new_page_content = "Kontent image"
    assert_difference "programs(:org_foster).pages.reload.size" do
      post :create, params: { :page => {
        :title => new_page_title,
        :content => new_page_content
      }}
    end

    page = assigns(:page)
    assert_redirected_to page_path(page)
    assert_equal programs(:org_foster), page.program
    assert_equal new_page_title, page.title
    assert_equal new_page_content, page.content
  end

  def test_should_render_new_page_on_page_save_error
    current_user_is @page_admin
    new_page_content = "Kontent image"
    post :create, params: { :page => {
      :content => new_page_content
    }}
    assert_response :success
    assert_template "edit"
    page = assigns(:page)
    assert_equal(programs(:albers), page.program)
    assert_equal(new_page_content, page.content)
    assert_equal(["can't be blank"], page.errors[:title])
    assert_page_banner
    assert_ckeditor_rendered
  end

  def test_should_render_edit_page_on_trying_to_save_a_page_without_title
    page = create_test_pages.first
    current_user_is @page_admin

    post :update, params: { :id => page.id, :page => {
      :content => "Abc",
      :title => ""
    }}
    assert_response :success
    assert_template "edit"
    page = assigns(:page)
    assert_equal(programs(:albers), page.program)
    assert_equal("Abc", page.content)
    assert_equal(["can't be blank"], page.errors[:title])
    assert_page_banner
    assert_ckeditor_rendered
  end

  def test_presence_of_logged_in_div_for_logged_in_user
    current_user_is users(:f_admin)
    get :index

    assert_response :success
    assert_select 'div#logged_in'
    assert_no_select 'div#non_logged_in'
  end

  def test_presence_of_non_logged_in_div_for_unlogged_in_user
    current_program_is programs(:albers)
    get :index

    assert_response :success
    assert_select 'div#non_logged_in'
    assert_no_select 'div#logged_in'
  end

  def test_terms_and_privacy_links
    current_program_is programs(:albers)
    get :index

    assert_response :success
    assert_select 'ul.nav.metismenu', :text => /Terms & Conditions/
    assert_select 'ul.nav.metismenu', :text => /Privacy Policy/
  end

  def test_footer_without_footer_white_labelling
    org = programs(:org_primary)
    org.white_label = true
    org.save!

    current_program_is programs(:albers)
    get :index

    assert_response :success
    assert_no_match /Powered by Chronus/, response.body
  end

  def test_programs
    @controller.expects(:can_view_programs_listing_page?).at_least(1).returns(true)
    current_program_is programs(:albers)
    get :programs

    assert_response :success
    assert assigns(:only_login)
  end

  def test_programs_redirect_on_programs_listing_visibility
    @controller.expects(:can_view_programs_listing_page?).at_least(1).returns(false)
    current_program_is programs(:albers)
    get :programs

    assert_redirected_to about_path
    assert_equal "The page you are trying to access doesn't exist.", flash[:error]
  end

  def test_programs_pages_banner_fallback_when_logo_is_absent
    organization = programs(:org_primary)
    program = programs(:albers)
    setup_banner_fallback(organization, program)

    current_program_is program
    get :programs
    assert_response :success
    assert assigns(:only_login)
    assert_select ".clearfix.row.hidden-xs div.program_logo_or_banner", count: organization.programs.size
    assert_select ".clearfix.row.hidden-xs div.program_logo_or_banner img[src='#{TEST_ASSET_HOST + organization.banner_url}']", count: organization.programs.size - 1
    assert_select ".clearfix.row.hidden-xs div.program_logo_or_banner img[src='#{TEST_ASSET_HOST + program.logo_url}']", count: 1
  end

  def test_custom_footer
    p = programs(:albers)
    p.organization.update_attribute(:footer_code, "This is custom footer")
    current_program_is p
    get :index

    assert_response :success
    assert_select 'div#page-wrapper', :text => /This is custom footer/
  end

  def test_show_single_column_layout
    get :index
    assert_response :success
    assert_nil @controller.view_context.instance_variable_get('@show_side_bar')
    assert_select 'html' do
      assert_select 'div#wrapper' do
        assert_select 'nav#sidebarLeft'
        assert_select 'div#page-wrapper' do
          assert_select 'div#inner_content' do
            assert_select 'div#page_canvas'
          end
        end

        assert_select 'div#sidebarRight', :count=> 0
      end
    end
  end

  def test_sort
    @controller.expects(:current_root).at_least(0).returns(nil)
    current_member_is :f_admin

    current_order = programs(:org_primary).pages.collect(&:id)
    assert current_order.size > 1

    post :sort, xhr: true, params: { :new_order => current_order.reverse}

    assert_equal current_order.reverse, programs(:org_primary).reload.pages.collect(&:id)
  end

  def test_reorder_programs
    @controller.expects(:current_root).at_least(0).returns(nil)
    current_member_is :f_admin

    current_order = programs(:org_primary).programs.ordered.map(&:id)
    assert current_order.size > 1

    put :reorder_programs, xhr: true, params: { :new_order => current_order.reverse}

    assert_equal current_order.reverse, programs(:org_primary).reload.programs.ordered.map(&:id)
  end

  def test_auto_logout_should_not_load_in_mobile_app
    login_as :f_admin
    @controller.stubs(:is_mobile_app?).returns(true)

    current_program_is :albers
    get :index

    assert_response :success
    assert_no_match /Warning! Your Session is About to Expire/, @response.body
    assert_equal(users(:f_admin), assigns(:current_user))

    # Should load if it is not a mobile app
    @controller.stubs(:is_mobile_app?).returns(false)
    get :index

    assert_response :success
    assert_match /Warning! Your Session is About to Expire/, @response.body
    assert_equal(users(:f_admin), assigns(:current_user))
  end

  private

  def assert_page_banner
    assert_select 'div.title_description', text: "The 'Program Overview' pages serve as the welcome pages of your program. Add program specific information and/or general guidelines for members of the program."
    assert_equal "The 'Program Overview' pages serve as the welcome pages of your program. Add program specific information and/or general guidelines for members of the program.", assigns(:title_description)
  end

  def assert_no_page_banner
    assert_no_select "div.title_description"
    assert_nil assigns(:title_description)
  end

  def create_test_pages(number = 3)
    pages = []
    number.times { |i| pages << create_page(:title => "Page #{i}", :content => "This is the #{i} test content") }
    pages
  end

  def create_page(options = {})
    default = {
      program: programs(:albers),
      title: "Page title",
      content: "Dummy Content"
    }
    Page.create!(default.merge(options))
  end

  def stub_mobile_browser(ios = true)
    if ios
      useragent = "Mozilla/5.0 (iPhone; U; CPU iPhone OS 9_0 like Mac OS X; en-us) AppleWebKit/532.9 (KHTML, like Gecko) Version/4.0.5 Mobile/8A293 Safari/6531.22.7"
      browser = Browser.new(useragent)
      @controller.stubs(:browser).returns(browser)
      assert @controller.mobile_browser?
    else
      useragent = "Mozilla/5.0 (Linux; U; Android 5.1; en-us; Nexus S Build/JRO03E) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"
      browser = Browser.new(useragent)
      @controller.stubs(:browser).returns(browser)
      @request.stubs(:user_agent).returns(useragent)
      assert @controller.mobile_browser?
    end
  end
end
