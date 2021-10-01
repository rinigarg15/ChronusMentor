require_relative './../test_helper.rb'

class MemberPagesControllerTest < ActionController::TestCase
  tests PagesController

  def test_index_should_not_render_program_pages
    current_organization_is :org_primary
    pages = []
    3.times { |i| pages << create_program_page(:title => "Page #{i}") }

    get :index
    assert_response :success
    assert_equal("General Overview", assigns(:page).title)
    assert_equal programs(:org_primary).pages, assigns(:pages)
    assert_no_page_banner
  end

  def test_index_and_show_page_should_be_accessible_without_login
    current_organization_is :org_anna_univ
    page = programs(:org_anna_univ).pages.first

    get :show, params: { :id => page.id}
    assert_response :success
    assert_select "nav#sidebarLeft" do
      assert_select "a[href=\"#{login_path(mode: 'strict')}\"]"
    end

    get :index
    assert_response :success
    assert_no_page_banner
  end

  def test_should_render_program_links
    current_organization_is :org_anna_univ
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    get :show, params: { :id => p2.id}

    assert_response :success
    # Tests the page links
    assert_select 'nav#sidebarLeft' do
      assert_select "ul" do
        assert_select "li" do
          assert_select "a[href=?]", about_path, :text => p1.title
        end
        assert_select "li.active" do
          assert_select "a[href=?]", page_path(p2, src: "tab"), :text => p2.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p3, src: "tab"), :text => p3.title
        end
        assert_select "li" do
          assert_select "a[href=?]", programs_pages_path, :text => "Programs"
        end
      end
    end
  end

  def test_should_not_render_program_listing_link
    programs(:org_anna_univ).update_attribute(:programs_listing_visibility, Organization::ProgramsListingVisibility::ONLY_LOGGED_IN_USERS)
    current_organization_is :org_anna_univ
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    get :show, params: { :id => p2.id}

    assert_response :success
    # Tests the page links
    assert_select 'nav#sidebarLeft' do
      assert_select "ul" do
        assert_select "li" do
          assert_select "a[href=?]", about_path, :text => p1.title
        end
        assert_select "li.active" do
          assert_select "a[href=?]", page_path(p2, src: "tab"), :text => p2.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p3, src: "tab"), :text => p3.title
        end
        assert_no_select "a[href='/pages/programs']"
      end
    end
  end

  def test_does_not_render_programs_if_standalone
    current_organization_is :org_foster

    page = Page.create!(title: "Page", content: 'Hello', program: programs(:org_foster))

    get :show, params: { :id => page.id}
    assert_response :success
    assert_equal page, assigns(:page)
    assert_select 'nav#sidebarLeft' do
      assert_select "a[href=?]", programs_pages_path, :count => 0
    end
  end

  def test_programs
    current_organization_is :org_anna_univ
    programs(:org_anna_univ).customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM).update_attribute :pluralized_term, "Schools"
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    get :programs
    assert_response :success

    # Tests the page links
    assert_select 'nav#sidebarLeft' do
      assert_select "ul" do
        assert_select "li" do
          assert_select "a[href=?]", about_path, :text => p1.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p2, src: "tab"), :text => p2.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p3, src: "tab"), :text => p3.title
        end
        assert_select "li.active" do
          assert_select "a[href=?]", programs_pages_path, :text => "Schools"
        end
      end
    end

    assert_select "a[href=?]", new_membership_request_path(:root => programs(:ceg).root)
  end

  def test_programs_for_logged_in_user_join_links_for_other_programs
    current_member_is :anna_univ_mentor

    program = programs(:org_anna_univ)
    programs(:org_anna_univ).customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM).update_attribute :pluralized_term, "Schools"

    p1, p2, p3 = program.pages[0, 3]

    get :programs
    assert_response :success

    # Tests the page links
    assert_select 'div.pages_submenu' do
      assert_select "ul" do
        assert_select "li" do
          assert_select "a[href=?]", page_path(p1), :text => p1.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p2), :text => p2.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p3), :text => p3.title
        end
        assert_select "li.active" do
          assert_select "a[href=?]", programs_pages_path, :text => "Schools"
        end
      end
    end

    assert_select "a[href=?]", new_membership_request_path(:root => programs(:psg).root), :count => 0
  end

  def test_programs_for_logged_in_user_no_join_link
    current_member_is :anna_univ_mentor
    programs(:org_anna_univ).customized_terms.find_by(term_type: CustomizedTerm::TermType::PROGRAM_TERM).update_attribute :pluralized_term, "Schools"
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    get :programs
    assert_response :success

    # Tests the page links
    assert_select 'div.pages_submenu' do
      assert_select "ul" do
        assert_select "li" do
          assert_select "a[href=?]", page_path(p1), :text => p1.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p2), :text => p2.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p3), :text => p3.title
        end
        assert_select "li.active" do
          assert_select "a[href=?]", programs_pages_path, :text => "Schools"
        end
      end
    end

    assert_select "a[href=?]", new_membership_request_path(:root => programs(:ceg).root), :count => 0
    assert_select "a[href=?]", new_membership_request_path(:root => programs(:psg).root), :count => 0
  end

  def test_show_for_unloggedin_user
    current_organization_is :org_anna_univ
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    p3.title = 'Great'
    p3.content = 'Greatest of greatest'
    p3.save!

    get :show, params: { :id => p3.id}
    assert_response :success

    # Tests the page links
    assert_select 'nav#sidebarLeft' do
      assert_select "ul" do
        assert_select "li" do
          assert_select "a[href=?]", about_path, :text => p1.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p2, src: "tab"), :text => p2.title
        end
        assert_select "li" do
          assert_select "a[href=?]", page_path(p3, src: "tab"), :text => "Great"
        end
      end
    end
    assert_select "div.inner_main_content" do
      assert_select "div.page_content_text", :text => "Greatest of greatest"
      assert_select "script", text: "\n//<![CDATA[\n\n  jQuery(document).ready(function(){\n    OverViewPage.updatePlayStoreLink(\"https://play.google.com/store/apps/details?id=com.chronus.mentorp&amp;referrer=utm_source%3D#{programs(:org_anna_univ).url}%26utm_medium%3Doverview_page\");\n  });\n\n//]]>\n"
    end

    # There should be no edit button
    assert_no_select "div#title_actions > div#action_2"
    assert_no_page_banner
  end

  def test_only_admin_should_be_able_to_edit_a_page
    current_member_is :anna_univ_mentor
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    assert_permission_denied do
      get :edit, params: { :id => p2.id}
    end
  end

    def test_only_admin_should_be_able_to_delete_a_page
    current_member_is :anna_univ_mentor
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    assert_permission_denied do
      post :destroy, params: { :id => p2.id}
    end
  end

  def test_should_update_a_page
    current_member_is :anna_univ_admin
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    post :update, params: { :id => p2.id, :page => {:title => 'new title', :content => 'new content'}}
    assert_redirected_to page_path(p2.id)
    assert_equal(p2, assigns(:page))
    assert_equal("new title", assigns(:page).title)
    assert_equal("new content", assigns(:page).content)
  end

  def test_should_delete_a_page
    current_member_is :anna_univ_admin
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    assert_difference 'Page.count', -1 do
      post :destroy, params: { :id => p2.id}
    end
    assert_redirected_to pages_path
  end

  def test_when_there_are_no_pages
    current_member_is :f_admin
    programs(:org_primary).pages.destroy_all
    assert programs(:org_primary).pages.empty?
    get :index
    assert_response :success
    assert assigns(:admin_view)
    assert_select "div.no_pages", :text => "There are no pages! Add page"
  end

  def test_only_admin_should_see_the_edit_link_and_add_link
    current_member_is :anna_univ_admin
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    get :show, params: { :id => p2.id}
    assert_response :success
    assert_select "div.page_content" do
      assert_select "a[href=?]", edit_page_path(p2.id), :text => "Edit"
      assert_select "a", :text => "Delete"
    end
    assert_select "a.add_new_page_button"
  end

  def test_empty_page_content
    current_member_is :anna_univ_admin
    page = create_program_page(:content => "", :program => programs(:org_anna_univ))
    get :show, params: { :id => page.id}
    assert_response :success
    assert_select "div.inner_main_content" do
      assert_select "div.empty_content"
    end
  end

  def test_should_get_edit_only_for_admin
    current_member_is :anna_univ_admin
    p1 = programs(:org_anna_univ).pages[0]

    get :edit, params: { :id => p1.id}
    assert_response :success
    assert_page_banner
    assert_ckeditor_rendered
  end

  def test_should_not_get_edit_only_for_non_admins
    current_member_is :anna_univ_mentor
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    assert_permission_denied do
      get :edit, params: { :id => p2.id}
    end
  end

  def test_should_get_new
    current_member_is :f_admin

    get :new
    assert_response :success
    assert_template "edit"
    assert_equal(programs(:org_primary).id, assigns(:page).program_id)
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
    current_member_is :anna_univ_mentor
    assert_permission_denied { get :new }
  end

  def test_should_create_program_page
    current_member_is :anna_univ_admin
    new_page_title = "Page new title"
    new_page_content = "Kontent image"
    post :create, params: { :page => {
      :title => new_page_title,
      :content => new_page_content
    }}
    page = assigns(:page)
    assert_equal(programs(:org_anna_univ), page.program)
    assert_equal(new_page_title, page.title)
    assert_equal(new_page_content, page.content)
    assert_redirected_to page_path(page)
  end

  def test_should_render_new_page_on_page_save_error
    current_member_is :anna_univ_admin
    new_page_content = "Kontent image"
    post :create, params: { :page => {
      :content => new_page_content
    }}
    assert_response :success
    assert_template "edit"
    page = assigns(:page)
    assert_equal(programs(:org_anna_univ), page.program)
    assert_equal(new_page_content, page.content)
    assert_equal(["can't be blank"], page.errors[:title])
    assert_page_banner
    assert_ckeditor_rendered
  end

  def test_should_render_edit_page_on_trying_to_save_a_page_without_title
    current_member_is :anna_univ_admin
    p1 = programs(:org_anna_univ).pages[0]
    p2 = programs(:org_anna_univ).pages[1]
    p3 = programs(:org_anna_univ).pages[2]

    post :update, params: { :id => p2.id, :page => {
      :content => "Abc",
      :title => ""
    }}
    assert_response :success
    assert_template "edit"
    page = assigns(:page)
    assert_equal("Abc", page.content)
    assert_equal(["can't be blank"], page.errors[:title])
    assert_page_banner
    assert_ckeditor_rendered
  end

  private

  def assert_page_banner
    assert_select 'div.title_description', text: "The 'Program Overview' pages serve as the welcome pages of your program. Add program specific information and/or general guidelines for members of the program."
    assert_equal "The 'Program Overview' pages serve as the welcome pages of your program. Add program specific information and/or general guidelines for members of the program.", assigns(:title_description)
  end

  def assert_no_page_banner
    assert_no_select 'div.title_description'
    assert_nil assigns(:title_description)
  end

  def create_test_pages(number = 3)
    pages = []
    number.times { |i| pages << create_program_page(:title => "Page #{i}", :content => "This is the #{i} test content") }
    pages
  end

  def create_program_page(options = {})
    options[:program] ||= programs(:albers)
    options[:title] ||= "Page title"
    options[:content] ||= "Dummy Content"
    Page.create!(options)
  end
end
