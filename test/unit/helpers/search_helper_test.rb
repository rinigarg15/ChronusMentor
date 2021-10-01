require_relative './../../test_helper.rb'

class SearchHelperTest < ActionView::TestCase

  def setup
    super
    helper_setup
  end

  def test_find_active_tab
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    self.expects(:program_context).at_least(0).returns(@current_program)
    self.expects(:params).at_least(0).returns(@controller.params)
    @controller.params[:controller] = 'programs'
    @controller.params[:action] = 'search'
    view_param_role_names = view_param_users(@current_program)
    assert_equal ResultType::ALL, find_active_tab(view_param_role_names)
    @controller.params[:controller] = 'users'
    @controller.params[:action] = 'index'
    @controller.params[:search] = 'some_query'
    @controller.params[:view] = RoleConstants::MENTOR_NAME
    assert_equal RoleConstants::MENTOR_NAME, find_active_tab(view_param_role_names)

    assert_equal @current_program.roles.last.name, "user"

    @controller.params[:controller] = 'users'
    @controller.params[:action] = 'index'
    @controller.params[:view] = @current_program.roles.last.name
    @controller.params[:search] = 'some_query'
    assert_equal @current_program.roles.last.name, find_active_tab(view_param_role_names)

    @controller.params[:controller] = 'users'
    @controller.params[:action] = 'index'
    @controller.params[:view] = RoleConstants::STUDENT_NAME
    @controller.params[:search] = 'some_query'
    assert_equal RoleConstants::STUDENT_NAME, find_active_tab(view_param_role_names)

    @controller.params[:controller] = 'articles'
    @controller.params[:action] = 'index'
    @controller.params[:search] = 'some_query'
    assert_equal ResultType::ARTICLES, find_active_tab(view_param_role_names)

    @controller.params[:controller] = 'qa_questions'
    @controller.params[:action] = 'index'
    @controller.params[:search] = 'some_query'
    assert_equal ResultType::ANSWERS, find_active_tab(view_param_role_names)

    @controller.params[:controller] = 'groups'
    @controller.params[:action] = 'find_new'
    @controller.params[:search] = 'some_query'
    assert_equal ResultType::GROUPS, find_active_tab(view_param_role_names)

    @controller.params[:controller] = 'resources'
    @controller.params[:action] = 'index'
    @controller.params[:search] = 'some_query'
    assert_equal ResultType::RESOURCES, find_active_tab(view_param_role_names)

    @controller.params[:controller] = 'programs'
    @controller.params[:action] = 'search'
    @controller.params[:filter_view] = 'topic'
    view_param_role_names = view_param_users(@current_program)
    assert_equal ResultType::TOPICS, find_active_tab(view_param_role_names)
  end

  def test_result_count_per_category
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    self.stubs(:global_search_current_user_role_ids).at_least(0).returns(current_user.is_admin? ? 
      @current_program.role_ids : current_user.role_ids)

    assert_equal(
      { RoleConstants::MENTOR_NAME => 0, RoleConstants::STUDENT_NAME => 1, @current_program.roles.last.name => 0,
       ResultType::ARTICLES => 0, ResultType::ANSWERS => 7, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('student')
    )

    assert_equal(
      {RoleConstants::MENTOR_NAME => 0, RoleConstants::STUDENT_NAME => 0, @current_program.roles.last.name => 0,
        ResultType::ARTICLES => 1, ResultType::ANSWERS => 0, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category("Australia Kangaroo")
    )

    assert_equal(
      {RoleConstants::MENTOR_NAME => 3, RoleConstants::STUDENT_NAME => 2, @current_program.roles.last.name => 1,
        ResultType::ARTICLES => 0, ResultType::ANSWERS => 18, ResultType::RESOURCES => 1, ResultType::TOPICS => 0},
      result_count_per_category("user name")
    )

    # Search for data that is in psg program
    assert_equal(
      {RoleConstants::MENTOR_NAME => 0, RoleConstants::STUDENT_NAME => 0, @current_program.roles.last.name => 0,
        ResultType::ARTICLES => 0, ResultType::ANSWERS => 0, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category("mental")
    )

  end

  # Should not render results that the user should not view.
  def test_result_count_per_category_for_permissions
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    add_role_permission(fetch_role(:albers, :mentor), 'view_find_new_projects')
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    self.stubs(:global_search_current_user_role_ids).at_least(0).returns(current_user.is_admin? ? 
      @current_program.role_ids : current_user.role_ids)
    remove_role_permission(fetch_role(:albers, :mentor), 'view_mentors')
    assert_equal(
      {"student" => 1, ResultType::GROUPS => 0,
       ResultType::ARTICLES => 0, ResultType::ANSWERS => 7, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('student')
    )

    remove_role_permission(fetch_role(:albers, :mentor), 'view_students')
    users(:f_mentor).reload
    assert_equal(
      {ResultType::GROUPS => 0, ResultType::ARTICLES => 0, ResultType::ANSWERS => 7, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('student')
    )

    add_role_permission(fetch_role(:albers, :mentor), 'view_users')
    users(:f_mentor).reload
    assert_equal(
      {@current_program.roles.last.name => 1, ResultType::GROUPS => 2, ResultType::ARTICLES => 0, ResultType::ANSWERS => 18, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('user name')
    )

    remove_role_permission(fetch_role(:albers, :mentor), 'view_articles')
    users(:f_mentor).reload
    assert_equal({@current_program.roles.last.name => 0, ResultType::GROUPS => 0, ResultType::ANSWERS => 7, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('student')
    )

    remove_role_permission(fetch_role(:albers, :mentor), 'view_users')
    users(:f_mentor).reload
    assert_equal({ResultType::GROUPS => 0, ResultType::ANSWERS => 7, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('student')
    )

    remove_role_permission(fetch_role(:albers, :mentor), 'view_questions')
    users(:f_mentor).reload
    assert_equal({ResultType::GROUPS => 0, ResultType::RESOURCES => 0, ResultType::TOPICS => 0}, result_count_per_category('student'))

    remove_role_permission(fetch_role(:albers, :mentor), 'view_find_new_projects')
    users(:f_mentor).reload
    assert_equal({ResultType::RESOURCES => 0, ResultType::TOPICS => 0}, result_count_per_category('student'))
  end

  def test_result_count_per_category_for_inactive_members
    @current_organization = programs(:org_anna_univ)
    @current_program = programs(:psg)
    assert_equal programs(:psg), users(:inactive_user).program

    self.expects(:current_user).at_least(0).returns(users(:psg_admin))
    self.stubs(:global_search_current_user_role_ids).at_least(0).returns(current_user.is_admin? ? 
      @current_program.role_ids : current_user.role_ids)

    assert_equal(
      {RoleConstants::MENTOR_NAME => 1, RoleConstants::STUDENT_NAME => 0,
       ResultType::ARTICLES => 0, ResultType::ANSWERS => 0, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('inactive')
    )
    self.expects(:current_user).at_least(0).returns(users(:psg_mentor))
    self.stubs(:global_search_current_user_role_ids).at_least(0).returns(current_user.is_admin? ? 
      @current_program.role_ids : current_user.role_ids)
    assert_equal(
      {RoleConstants::MENTOR_NAME => 0, RoleConstants::STUDENT_NAME => 0,
        ResultType::ARTICLES => 0, ResultType::ANSWERS => 0, ResultType::RESOURCES => 0, ResultType::TOPICS => 0},
      result_count_per_category('inactive')
    )
  end

  def test_category_filters
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    self.expects(:find_active_tab).at_least(0).returns("mentors")
    self.expects(:_Articles).at_least(0).returns("mangoes")
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))

    content = category_filters('some query',
      {RoleConstants::MENTOR_NAME => 1, RoleConstants::STUDENT_NAME => 2, ResultType::ARTICLES => 0, ResultType::ANSWERS => 3, ResultType::RESOURCES => 0, ResultType::TOPICS => 0})
    set_response_text(content)
    assert_select "ul.links" do
      assert_select "a[href=?]", search_path(:query => 'some query'), :text => 'All results (6)'
      assert_select "li.gray-bg" do
        assert_select "a[href=?]", users_path(:view => RoleConstants::MENTORS_NAME, :search => 'some query', src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
          :text => 'Mentors (1)'
      end

      assert_select "a[href=?]", users_path(:view => RoleConstants::STUDENTS_NAME, :search => 'some query', src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
          :text => 'Students (2)'

      assert_select "li" do
        assert_select "a.disabled[href=?]", "javascript:void(0)", :text => 'mangoes (0)'
      end

      assert_select "a[href=?]", qa_questions_path(:search => 'some query'), :text => 'Questions & Answers (3)'
    end
  end

  def test_category_filters_with_customized_terms
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    self.expects(:find_active_tab).at_least(0).returns("mentors")
    self.expects(:_Articles).at_least(0).returns("mangoes")
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    customized_term = @current_program.roles.find_by(name: @current_program.roles.last.name).customized_term
    customized_term.update_attributes(:term => "advisor", :pluralized_term => "Advisors", :pluralized_term_downcase => "advisors")
    customized_term = @current_program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term
    customized_term.update_attributes(:term => "guru", :pluralized_term => "Gurus", :pluralized_term_downcase => "gurus")
    customized_term = @current_program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term
    customized_term.update_attributes(:term => "coachee", :pluralized_term => "Coachees", :pluralized_term_downcase => "coachees")
    content = category_filters('some query',
      {RoleConstants::MENTOR_NAME => 1, RoleConstants::STUDENT_NAME => 2, @current_program.roles.last.name => 2, ResultType::ARTICLES => 0, ResultType::ANSWERS => 3, ResultType::RESOURCES => 0,  ResultType::TOPICS => 0})
    set_response_text(content)
    assert_select "ul.links" do
      assert_select "a[href=?]", search_path(:query => 'some query'), :text => /All results/
      assert_select "li.gray-bg" do
        assert_select "a[href=?]", users_path(:view => RoleConstants::MENTORS_NAME, :search => 'some query', src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
          :text => 'Gurus (1)'
      end

      assert_select "a[href=?]", users_path(:view => RoleConstants::STUDENTS_NAME, :search => 'some query', src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
          :text => 'Coachees (2)'

      assert_select "li" do
        assert_select "a.disabled[href=?]", "javascript:void(0)", :text => 'mangoes (0)'
      end

      assert_select "a[href=?]", qa_questions_path(:search => 'some query'), :text => 'Questions & Answers (3)'
    end
  end

    def test_category_filters_for_permissions
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    @results = [1] #dummy
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    self.stubs(:global_search_current_user_role_ids).at_least(0).returns(current_user.is_admin? ? 
      @current_program.role_ids : current_user.role_ids)
    self.expects(:find_active_tab).at_least(0).returns(ResultType::ALL)
    term = @current_program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term
    self.expects(:_Articles).at_least(0).returns("mango")

    remove_role_permission(fetch_role(:albers, :mentor), 'view_mentors')
    remove_role_permission(fetch_role(:albers, :mentor), 'view_students')
    remove_role_permission(fetch_role(:albers, :mentor), 'view_articles')
    remove_role_permission(fetch_role(:albers, :mentor), 'view_questions')

    content = category_filters('some query',
      {RoleConstants::MENTOR_NAME => 1, RoleConstants::STUDENT_NAME => 1,
        ResultType::ARTICLES => 0, ResultType::ANSWERS => 3, ResultType::RESOURCES => 0, ResultType::TOPICS => 0})
    set_response_text(content)
    assert_select ".vertical_filters" do
      assert_select "ul.links" do
        # Only 'All' link.
        assert_select 'li', :count => 3
        assert_select 'a', :count => 3
        assert_select 'li' do
          assert_select "a[href=?]", search_path(:query => 'some query'), :text => /All results/
        end
      end
    end
  end

  def test_category_filters_for_permissions_with_third_role
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    @results = [1] #dummy
    self.expects(:current_user).at_least(0).returns(users(:f_mentor))
    self.expects(:find_active_tab).at_least(0).returns(ResultType::ALL)
    term = @current_program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term
    term.update_attributes(:term => "guru", :pluralized_term => "Gurus", :pluralized_term_downcase => "gurus")
    self.expects(:_Articles).at_least(0).returns("mango")

    remove_role_permission(fetch_role(:albers, :mentor), 'view_mentors')
    remove_role_permission(fetch_role(:albers, :mentor), 'view_students')
    add_role_permission(fetch_role(:albers, :mentor), 'view_users')
    remove_role_permission(fetch_role(:albers, :mentor), 'view_articles')
    remove_role_permission(fetch_role(:albers, :mentor), 'view_questions')

    content = category_filters('some query',
      {RoleConstants::MENTOR_NAME => 1, RoleConstants::STUDENT_NAME => 2, @current_program.roles.last.name => 1,
        ResultType::ARTICLES => 0, ResultType::ANSWERS => 3, ResultType::RESOURCES => 0,  ResultType::TOPICS => 0})
    set_response_text(content)
    assert_select ".vertical_filters" do
      assert_select "ul.links" do
        # Only 'All' link.
        assert_select 'li', :count => 4
        assert_select 'a', :count => 4
        assert_select 'li' do
          assert_select "a[href=?]", search_path(:query => 'some query'), :text => /All results/
          assert_select "a[href=?]", users_path(:view => @current_program.roles.last.name, :search => 'some query', src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ), :text => 'Users (1)'
        end
      end
    end
  end

  def test_disabled_features_not_shown_in_categories
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    @current_program.organization.enable_feature(FeatureName::ARTICLES, false)
    @current_program.organization.enable_feature(FeatureName::ANSWERS, false)
    @current_program.reload
    assert !@current_organization.has_feature?(FeatureName::ARTICLES)
    assert !@current_organization.has_feature?(FeatureName::ANSWERS)

    self.expects(:find_active_tab).at_least(0).returns(RoleConstants::STUDENTS_NAME)
    self.expects(:_Articles).at_least(0).returns("mango")

    content = category_filters('some query',
      {RoleConstants::MENTOR_NAME => 1, RoleConstants::STUDENT_NAME => 2, @current_program.roles.last.name => 4,
        ResultType::ARTICLES => 3, ResultType::ANSWERS => 2, ResultType::RESOURCES => 0,  ResultType::TOPICS => 0})
    set_response_text(content)
    assert_select ".vertical_filters" do
      assert_select "ul.links" do
        assert_select "a[href=?]", search_path(:query => 'some query'), :text => /All results/
        assert_select "a[href=?]", users_path(:search => 'some query', :view => RoleConstants::MENTORS_NAME, src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
            :text => 'Mentors (1)'
        assert_select 'li.gray-bg' do
          assert_select "a[href=?]", users_path(:view => RoleConstants::STUDENTS_NAME, :search => 'some query', src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
              :text => 'Students (2)'
        end
        assert_select "a[href=?]", users_path(:search => 'some query', :view => @current_program.roles.last.name, src: EngagementIndex::Src::BrowseMentors::SEARCH_BOX ),
            :text => 'Users (4)'
        assert_select "a[href=?]", articles_path(:search => 'some query'),
            :text => 'Articles (3)', :count => 0
        assert_select "a[href=?][class=disabled]", "javascript:void(0)", :text => 'Questions & Answers (2)', :count => 0
      end
    end
  end

  def test_constraints_for
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    assert ResultType.constraints_for(ResultType::ALL, programs(:albers), true).empty?
    assert_equal(
      {:classes => [User], :with => {:role_ids => [fetch_role(:albers, :mentor).id]}},
      ResultType.constraints_for(RoleConstants::MENTOR_NAME, programs(:albers), true)
    )

    assert_equal(
      {:classes => [User], :with => {:role_ids => [@current_program.roles.last.id]}},
      ResultType.constraints_for(@current_program.roles.last.name, programs(:albers), true)
    )

    assert_equal(
      {:classes => [User], :with => {:role_ids => [fetch_role(:albers, :student).id]}},
      ResultType.constraints_for(RoleConstants::STUDENT_NAME, programs(:albers), true)
    )

    assert_equal(
      {:classes => [User], :with => {:role_ids => [fetch_role(:albers, :mentor).id], :state => User::Status::ACTIVE}},
      ResultType.constraints_for(RoleConstants::MENTOR_NAME, programs(:albers), false)
    )

    assert_equal(
      {:classes => [User], :with => {:role_ids => [fetch_role(:albers, :student).id], :state => User::Status::ACTIVE}},
      ResultType.constraints_for(RoleConstants::STUDENT_NAME, programs(:albers), false)
    )

    assert_equal({:classes => [Article]}, ResultType.constraints_for(ResultType::ARTICLES, programs(:albers), true))
    assert_equal({:classes => [QaQuestion]}, ResultType.constraints_for(ResultType::ANSWERS, programs(:albers), true))
  end

  def test_search_results_wrapper
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    self.expects(:params).at_least(0).returns(@controller.params)
    @controller.params[:controller] = 'users'
    @controller.params[:action] = 'index'
    @controller.expects(:tab_info).at_least(0).returns({})
    @controller.expects(:activate_tab).at_least(0).returns(nil)
    self.expects(:find_active_tab).at_least(0).returns(RoleConstants::MENTORS_NAME)
    self.expects(:_Articles).at_least(0).returns("mango")
    self.expects(:render).at_least(0).returns("")
    self.expects(:logged_in_program?).at_least(0).returns(true)
    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    self.stubs(:global_search_current_user_role_ids).at_least(0).returns(current_user.is_admin? ? 
      @current_program.role_ids : current_user.role_ids)

    stub_view_flow_for_content_tag do
      search_results_wrapper('mentor') do
        'hello'
      end
    end

    assert @no_page_actions
  end

  def test_search_results_wrapper_for_non_logged_in_members
    @current_organization = programs(:org_primary)
    @current_program = programs(:albers)

    self.expects(:params).at_least(0).returns(@controller.params)
    @controller.params[:controller] = 'users'
    @controller.params[:action] = 'index'
    @controller.expects(:tab_info).at_least(0).returns({})
    @controller.expects(:activate_tab).at_least(0).returns(nil)
    self.expects(:find_active_tab).at_least(0).returns(RoleConstants::MENTORS_NAME)
    self.expects(:render).at_least(0).returns("")
    self.expects(:logged_in_program?).at_least(0).returns(false)

    assert !@no_crumbs

    stub_view_flow_for_content_tag do
      search_results_wrapper('mentor') do
        'hello'
      end
    end

    assert_nil @no_crumbs
    assert_nil @no_page_actions
  end

  def test_view_param_users
    program = programs(:albers)
    assert_equal view_param_users(program), {RoleConstants::MENTOR_NAME => RoleConstants::MENTORS_NAME, RoleConstants::STUDENT_NAME => RoleConstants::STUDENTS_NAME, program.roles.last.name => program.roles.last.name }
    program = programs(:psg)
    assert_equal view_param_users(program), {RoleConstants::MENTOR_NAME => RoleConstants::MENTORS_NAME, RoleConstants::STUDENT_NAME => RoleConstants::STUDENTS_NAME }
  end

private

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _Resources
    "Resources"
  end

end
