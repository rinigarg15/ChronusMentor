require_relative './../../test_helper.rb'

# Listing and users search related tests.
class IndexAndSearchTest < ActionController::TestCase
  tests UsersController

  def test_mentors_list_with_quick_search_and_without_other_search_filters
    current_user_is :f_admin

    get :index, params: { :sf => {:quick_search => "robert"}}
    assert_response :success
    assert_equal 1, assigns(:users).size
    assert_equal [users(:robert)].collect(&:id), assigns(:users).collect(&:id)

    assert_select "div.filter_pane" do
      assert_select "div#quick_search" do
        assert_select "input#sf_quick_search"
      end
    end

  end

  def test_mentors_list_with_quick_search_and_with_other_search_filters
    current_user_is :f_admin

    loc_ques = profile_answers(:location_chennai_ans).profile_question
    get :index, params: { :sf => {:quick_search => "mentor", :location => {loc_ques.id => {:name => "tamil nadu,india"}}}}
    assert_response :success
    assert_equal 1, assigns(:users).size
    assert_equal [users(:f_mentor)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_should_show_filter_pane_on_search_result
    current_user_is :f_admin
    mentor = users(:f_mentor)
    search_string = mentor.name.split(' ').first
    get :index, params: { :search => search_string}
    assert_response :success

    assert_select "div#mentors_index"
    assert_select "div#sidebarRight"do
      assert_select "div#filter_pane"
    end
  end

  def test_should_not_show_filter_pane_on_empty_search_result
    current_user_is :f_admin
    get :index, params: { :search => "n0suchloser"}
    assert_response :success

    assert_select "div#mentors_index"
    assert_no_select "div#sidebarRight"
  end

  def test_empty_listing_when_no_mentors_in_program_for_admin
    current_user_is :f_admin

    User.expects(:get_filtered_users).returns([].paginate(page: 1, per_page: 10))
    get :index
    assert_response :success
    assert assigns(:users).empty?
    assert_nil assigns(:calendar_availability_default)
    assert_equal "all", assigns(:filter_field)
    assert_nil assigns(:search_query)
    assert_no_select 'div#filter_pane'
    assert_no_select 'div#results_pane'
    assert_select 'div.empty_listing', /There are no mentors in the program yet/ do
      assert_select 'a[href=?]', invite_users_path(:role => RoleConstants::MENTOR_NAME), :text => "Invite Mentors"
      assert_select 'a[href=?]', new_user_path(:role => RoleConstants::MENTOR_NAME), :text => "Add Mentor Profiles"
    end
  end

  def test_empty_listing_when_no_students_in_program_for_admin
    current_user_is :f_admin

    User.expects(:get_filtered_users).returns([].paginate(page: 1, per_page: 10))
    get :index, params: { :view => RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert assigns(:users).empty?
    assert_equal "all", assigns(:filter_field)
    assert_nil assigns(:search_query)
    assert_select 'div.empty_listing', /There are no students in the program yet/ do
      assert_select 'a[href=?]', invite_users_path(:role => RoleConstants::STUDENT_NAME), :text => "Invite Students"
    end
  end

  def test_empty_listing_when_no_mentors_in_program_for_non_admin
    current_user_is :f_student

    User.expects(:get_availability_slots_for).returns({})
    User.expects(:get_filtered_users).returns([].paginate(page: 1, per_page: 10))
    get :index, params: { :filter => 'all'}
    assert_response :success
    assert assigns(:users).empty?
    assert_nil assigns(:search_query)
    assert_equal 'all', assigns(:filter_field)
    assert_no_select 'div#filter_pane'
    assert_no_select 'div#results_pane'
    assert_select 'div.empty_listing', /There are no mentors in the program yet/
  end

  def test_empty_listing_when_no_students_in_program_for_non_admin
    current_user_is :f_admin

    User.expects(:get_filtered_users).returns([].paginate(page: 1, per_page: 10))
    get :index, params: { :view => RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert assigns(:users).empty?
    assert_nil assigns(:search_query)
    assert_select 'div.empty_listing', /There are no students in the program yet/
  end

  def test_should_sort_desc_by_second_name_if_the_program_sort_by_setting_is_last_name
    p = programs(:foster)
    assert_equal(Program::SortUsersBy::LAST_NAME, p.reload.sort_users_by)
    current_user_is :foster_mentor5

    # Collect mentors sorted by last_name, first_name in descending order
    sorted_mentors = wp_collection_from_array((programs(:foster).mentor_users.active - [users(:not_requestable_mentor)]).sort_by{|m| "#{m.last_name} #{m.first_name}".downcase}.reverse, 1)
    get :index, params: { :sort => 'name', :order => 'desc'}
    assert_equal(sorted_mentors.collect(&:id), assigns(:users).collect(&:id))
  end

  def test_should_sort_asc_by_second_name_if_the_program_sort_by_setting_is_last_name
    p = programs(:foster)
    assert_equal(Program::SortUsersBy::LAST_NAME, p.reload.sort_users_by)
    current_user_is :foster_mentor5

    # Collect mentors sorted by last_name, first_name in ascending order
    sorted_mentors = wp_collection_from_array((programs(:foster).mentor_users.active - [users(:not_requestable_mentor)]).sort_by{|m| "#{m.last_name} #{m.first_name}".downcase}, 1)
    get :index, params: { :sort => 'name', :order => 'ASC'}

    assert_equal(sorted_mentors.collect(&:id), assigns(:users).collect(&:id))
  end

  SECOND_TITLE_ACTION_DIV_ID = "action_2"

  def test_mentors_listing
    current_user_is users(:ram)

    # Removing the draft from the collection
    all_mentors = programs(:albers).mentor_users
    all_mentors = all_mentors.sort_by{|m| m.name.downcase}

    # Assign all mentors to albers program
    mentors = wp_collection_from_array(all_mentors, 1)

    # Fetch page 1 records, thus validating pagination too.
    get :index
    assert_response :success
    assert_select 'html'
    assert_arrays_equal mentors.collect(&:id), assigns(:users).collect(&:id)

    assert_select "div#title_actions" do
      assert_select "div.btn-group" do
        assert_select "a[href=?]", new_user_path(:role => RoleConstants::MENTOR_NAME), :text => "Add Mentors Directly"
      end
    end

    assert_no_select "div#mentor_availability_content"

    assert_equal assigns(:user_reference_plural), "Mentors"
    assert_equal assigns(:user_reference), "Mentor"
    assert assigns(:show_filters)
  end

  def test_mentors_listing_for_student_calendar_defaults
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    all_mentors = program.mentor_users.select(&:cached_available_and_can_accept_request?)
    mentors = all_mentors.sort_by { |m| -m.slots_available }.first(PER_PAGE)
    User.where(id: mentors.map(&:id)).update_all("max_connections_limit = max_connections_limit + 1")
    reindex_documents(updated: mentors)

    # Assign all mentors to albers program
    SecureRandom.stubs(:hex).returns("random")

    # Fetch page 1 records, thus validating pagination too.
    Timecop.freeze(Date.parse('2014-07-16')) do
      current_user_is :f_student
      get :index
      assert_response :success
      assert_equal_unordered mentors.map(&:id), assigns(:users).map(&:id)
      assert_equal "Mentors", assigns(:user_reference_plural)
      assert_equal "Mentor", assigns(:user_reference)
      assert assigns(:show_filters)
      assert assigns(:calendar_availability_default)
      assert_equal 1, assigns(:initialize_filter_fields_js).size

      assert_select "div#collapsible_random_content" do
        assert_select "input#calendar_availability_default", :value => 'true'
        assert_select "input#filter_available_for_a_meeting"
        assert_select "input#filter_long_term_availability"
      end
    end
  end

  def test_mentors_listing_for_student_calendar_default_false
    current_user_is users(:f_student)
    programs(:albers).enable_feature(FeatureName::CALENDAR)

    all_mentors = programs(:albers).mentor_users.select{|u| u.active? }
    #all_mentors = all_mentors.sort_by{|m| m.id }

    # Assign all mentors to albers program
    mentors = wp_collection_from_array(all_mentors, 1, 100)
    SecureRandom.stubs(:hex).returns("random")

    # Fetch page 1 records, thus validating pagination too.
    Timecop.freeze(Date.parse('2014-07-16')) do
      get :index, params: { :calendar_availability_default => 'false', :items_per_page => 25, filter: [UserSearch::SHOW_NO_MATCH_FILTER]}
      assert_response :success
      assert_select 'html'
      assert_equal_unordered mentors.collect(&:id), assigns(:users).collect(&:id)

      assert_select "div#collapsible_random_content" do
        assert_select "input#calendar_availability_default", :value => 'false'
        assert_select "input#filter_available_for_a_meeting"
        assert_select "input#filter_long_term_availability"
      end

      assert_equal assigns(:user_reference_plural), "Mentors"
      assert_equal assigns(:user_reference), "Mentor"
      assert assigns(:show_filters)
      assert_nil assigns(:calendar_availability_default)
      assert_equal 0, assigns(:initialize_filter_fields_js).size
    end
  end

  def test_should_not_list_inactive_users
    current_user_is users(:psg_mentor)

    get :index
    assert_response :success
    assert_select 'html'
    assert_arrays_equal((programs(:psg).mentor_users - [users(:inactive_user)]).collect(&:id), assigns(:users).collect(&:id))
  end

  def test_should_show_filter_bar_for_students_on_empty_results
    current_user_is :f_student

    get :index, params: { :search => "n0suchloser"}
    assert_response :success
  end

  def test_should_not_show_filter_bar_for_mentors_on_empty_results
    current_user_is :f_mentor

    get :index, params: { :search => "n0suchloser"}
    assert_response :success
  end

  def test_should_show_filter_bar_for_admins_on_empty_results
    current_user_is :f_admin

    get :index, params: { :search => "n0suchloser"}
    assert_response :success
  end

  def test_should_not_render_add_mentors_link_for_mentors
    current_user_is :f_mentor

    get :index
    assert_response :success

    assert_select "div##{SECOND_TITLE_ACTION_DIV_ID}", 0
    assert_nil assigns(:mentor_groups_map)
  end

  def test_should_not_render_add_mentors_link_or_request_a_mentor_for_mentees
    current_user_is :f_student

    get :index
    assert_response :success

    assert_no_select "div##{SECOND_TITLE_ACTION_DIV_ID}"

    assert_no_select "a[href='/mentor_requests/new']"
    # Making sure no favorites filter is present
    assert_no_select "option[value='favorites']"
  end

  def test_should_render_request_a_mentor_for_mentees_only_in_tightly
    current_user_is :moderated_student

    get :index
    assert_response :success

    # Making sure title level action is present
    assert_select "div#action_1"
    assert_select "a[href=?]", new_mentor_request_path
    assert_equal({}, assigns(:mentor_groups_map))
  end

  def test_index_should_compute_mentor_groups_map
    current_user_is :mkr_student
    get :index
    assert_response :success
    assert_equal( { users(:f_mentor) => [groups(:mygroup)] }, assigns(:mentor_groups_map))
  end

  def test_should_render_favorite_mentors_tightly_when_no_favorites
    current_user_is :moderated_student

    get :index
    assert_response :success
    assert_equal [], assigns(:preferred_mentors)
  end

  def test_should_render_favorite_mentors_tightly
    current_user_is :moderated_student

    create_favorite(:user => users(:moderated_student) , :favorite => users(:moderated_mentor))
    get :index, params: { :filter => "favorites"}
    assert_response :success
    assert assigns(:users).include?(users(:moderated_mentor))
  end

  # There will be no flash message when the user is not prompted
  def test_no_flash_for_tightly_when_no_prompt
    make_member_of(:moderated_program, :f_student)
    current_user_is :f_student

    get :index
    assert_response :success
    assert_no_flash_in_page
  end

  # There will be no flash message when the user is not prompted
  def test_no_flash_for_tightly_when_no_prompt_not_min_preferred_mentors
    make_member_of(:moderated_program, :f_student)
    current_user_is :f_student
    programs(:moderated_program).update_attribute(:min_preferred_mentors, 2)
    create_favorite(:favorite => users(:moderated_mentor))

    get :index
    assert_response :success
    assert_no_flash_in_page
  end

  # There will a flash message when the user is prompted
  def test_will_be_flash_for_tightly_when_prompt_for_mentors_listing_only
    make_member_of(:moderated_program, :f_student)
    programs(:moderated_program).roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attributes(:term_downcase => "alien", :pluralized_term_downcase => "aliens")
    create_favorite(:favorite => users(:moderated_mentor))
    current_user_is :f_student
    User.any_instance.expects(:student_document_available?).returns(true)

    get :index
    assert_response :success
    assert_equal "You have 1 preferred alien. <a href=\"#{new_mentor_request_path}\">Send a request</a> to administrator for alien assignment or continue adding aliens.", flash[:notice]
  end

  def test_no_flash_for_tightly_when_no_prompt_for_students_listing
    make_member_of(:moderated_program, :f_student)
    current_user_is :f_student
    create_favorite(:favorite => users(:moderated_mentor))

    get :index, params: { :view => RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert_no_flash_in_page
  end

  # There will a flash message when the user is prompted
  def test_will_not_be_flash_for_tightly_when_prompt_for_mentors_listing_in_case_mentee_cannot_send_request
    make_member_of(:moderated_program, :f_student)
    current_user_is :f_student
    programs(:moderated_program).update_attribute(:max_connections_for_mentee, 0)
    programs(:moderated_program).roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute(:term, "alien")

    get :index
    assert_response :success
    assert_no_flash_in_page
  end

  # There will be no flash message when the user is not prompted
  def test_no_flash_for_tightly_when_favorites_and_request_sent
    make_member_of(:moderated_program, :f_student)
    current_user_is :f_student

    create_favorite(:favorite => users(:moderated_mentor))
    create_mentor_request(:program => programs(:moderated_program))

    get :index
    assert_response :success
    assert_no_flash_in_page
  end

  def test_students_listing
    current_user_is users(:ram)

    # Assign all students to albers program
    students = wp_collection_from_array(programs(:albers).student_users.sort_by{|m| m.name}, 2)

    # Fetch page 2 records, thus validating pagination too.
    get :index, xhr: true, params: { :view => RoleConstants::STUDENTS_NAME, :page => 2}
    assert_response :success
    assert assigns(:search_query).blank?
    assert_equal "all", assigns(:filter_field)
    assert !assigns(:match_view)
    assert_arrays_equal students.collect(&:id), assigns(:users).collect(&:id)
    assert_nil assigns(:mentor_groups_map)
    assert_equal assigns(:user_reference_plural), "Students"
    assert_equal assigns(:user_reference), "Student"
  end

  def test_connected_students_for_admin
    current_user_is :f_admin

    get :index, params: { :view => RoleConstants::STUDENTS_NAME, :filter => "connected"}
    assert_response :success
    assert_equal_unordered [users(:mkr_student), users(:student_1), users(:student_2), users(:student_3)].collect(&:id), assigns(:users).collect(&:id)
    assert_equal "connected", assigns(:filter_field)
    assert_nil assigns(:search_query)
  end

  def test_unconnected_students_for_admin
    current_user_is :f_admin

    get :index, params: { :view => RoleConstants::STUDENTS_NAME, :filter => UsersIndexFilters::Values::UNCONNECTED}
    assert_response :success
    assert_equal [users(:student_4).id], assigns(:users).collect(&:id) & [users(:mkr_student), users(:student_2), users(:student_3), users(:student_4)].collect(&:id)
    assert_equal UsersIndexFilters::Values::UNCONNECTED, assigns(:filter_field)
    assert_nil assigns(:search_query)
  end

  def test_never_connected_students_for_admin
    current_user_is :f_admin

    get :index, params: { :view => RoleConstants::STUDENTS_NAME, :filter => UsersIndexFilters::Values::NEVERCONNECTED}
    assert_response :success
    assert_equal [], assigns(:users).collect(&:id) & [users(:mkr_student), users(:student_2), users(:student_3)].collect(&:id)
    assert_equal UsersIndexFilters::Values::NEVERCONNECTED, assigns(:filter_field)
    assert_nil assigns(:search_query)
  end

  def test_mentors_listing_for_admin_student
    current_user_is users(:f_student)

    users(:f_student).promote_to_role!([RoleConstants::ADMIN_NAME], users(:f_admin))

    get :index, params: { :page => 2}
    assert_response :success
    assert_template 'index'
    assert_select 'html'
    assert assigns(:match_view)
    assert assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
    assert assigns(:show_filters)
    assert_false assigns(:show_tag_filters)
  end

  def test_mentors_listing_for_admin_student_no_mentor_request_mode
    current_user_is users(:no_mreq_admin)
    make_member_of(:no_mentor_request_program, :f_mentor)

    users(:no_mreq_admin).add_role(RoleConstants::STUDENT_NAME)

    get :index
    assert_response :success
    assert_template 'index'
    assert_false assigns(:match_view)
    assert assigns(:show_filters)
    assert_false assigns(:show_tag_filters)
  end

  def test_students_list_with_sorting_order
    current_user_is users(:ram)

    sorted_students = programs(:albers).student_users.sort_by{|m| m.name.downcase}

    students = wp_collection_from_array(sorted_students)

    # Default order is ascending and field is name
    get :index, params: { :view => RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert_select 'html'
    assert_arrays_equal students.collect(&:id), assigns(:users).collect(&:id)

    # Ascending order sorting
    get :index, params: { :view => RoleConstants::STUDENTS_NAME, :sort => "name", :order => :asc}
    assert_response :success
    assert_select 'html'
    assert !assigns(:match_view)
    assert_arrays_equal students.collect(&:id), assigns(:users).collect(&:id)

    students = wp_collection_from_array(sorted_students.reverse)

    # Descending order sorting
    get :index, params: { :view => RoleConstants::STUDENTS_NAME, :sort => "name", :order => :desc}
    assert_response :success
    assert_select 'html'
    assert_arrays_equal students.collect(&:id), assigns(:users).collect(&:id)

    # Default field is name
    get :index, params: { :view => RoleConstants::STUDENTS_NAME, :order => :desc}
    assert_response :success
    assert_select 'html'
    assert_arrays_equal students.collect(&:id), assigns(:users).collect(&:id)
    assert assigns(:show_filters)
  end

  def test_simple_search_should_not_show_students_from_other_programs
    current_user_is :f_student

    # Search for the student mkr_student's name.
    get :index, params: { :search => 'arun', :view => RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert_equal [users(:arun_albers)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_simple_student_search_with_name
    current_user_is :f_student

    # Search for the student mkr_student's name.
    get :index, params: { :search => users(:mkr_student).name, :view => RoleConstants::STUDENTS_NAME}
    assert_response :success
    assert_equal users(:mkr_student).name, assigns(:search_query)
    assert_equal [users(:mkr_student)].collect(&:id), assigns(:users).collect(&:id)
  end

  def test_simple_mentor_search_with_name
    current_user_is :f_admin

    # Search for the mentor f_mentor's name.
    get :index, params: { :search => users(:f_mentor).name}
    assert_response :success
    assert assigns(:users).collect(&:id).include?(users(:f_mentor).id)
  end

  def test_simple_mentors_search_with_student_name
    current_user_is :f_student

    # Search for mentor with the student mkr_student's name.
    get :index, params: { :search => users(:mkr_student).name}
    assert_response :success
    assert assigns(:users).empty?
  end

  # Search should match a record if it matches any of the keywords.
  def test_search_any_mode
    current_user_is :f_student

    all_mentors = programs(:albers).mentor_users
    mentors_with_both_keywords =
      all_mentors.select{|m| m.name.include?('kal') && m.name.include?('robert')}

    assert mentors_with_both_keywords.empty?

    # Search for mentor with both the keywords.
    get :index, params: { :search => "kal robert"}
    assert_response :success
    assert assigns(:users).any?
  end

  def test_special_empty_mentors_results_message_for_student
    current_user_is :f_student

    # Empty results
    User.expects(:get_availability_slots_for).returns({})
    User.expects(:get_filtered_users).returns([].paginate(:page => 1, :per_page => 10))
    get :index, params: { :search => 'something'}
    assert_response :success
    assert assigns(:users).empty?
    assert_select 'div#mentors_index', /to get help from the program administrators/ do
      assert_select 'a[href=?]', contact_admin_url
    end
  end

  def test_no_special_empty_mentors_results_message_for_non_student
    current_user_is :f_mentor

    # Empty results
    User.expects(:get_filtered_users).returns([].paginate(page: 1, per_page: 10))
    get :index, params: { :search => 'something'}
    assert_response :success
    assert assigns(:users).empty?
    assert_select 'div#mentors_index'  do
      assert_select 'a[href=?]', contact_admin_url, :count => 0
    end
  end

  def test_mentor_search_with_name_and_sort
    current_user_is :f_student

    cus = Member.where("CONCAT_WS(' ', first_name, last_name) like 'mentor_% chronus'").limit(PER_PAGE).order('members.first_name DESC, members.last_name DESC').pluck(:id)
    mentors = cus.collect{|c| programs(:albers).mentor_users.of_member(c).first}
    mentors = wp_collection_from_array(mentors.sort_by{|m| m.name}.reverse)
    get :index, params: { :search => "chronus", :sort => "name", :order => :desc, :filter => 'all'}
    assert_response :success
    assert_equal mentors.collect(&:id), assigns(:users).collect(&:id)
  end

  def test_mentor_listing_does_not_show_match_for_self
    current_user_is :f_mentor_student

    mentors = wp_collection_from_array([users(:f_mentor_student), users(:f_mentor)].collect(&:id))
    User.expects(:get_availability_slots_for).returns({})
    User.expects(:get_filtered_users).returns(mentors)
    get :index
    assert_template 'index'
    assert_select "div#mentor_#{users(:f_mentor).id}" do
      assert_select "span.ct-match-percent"
    end

    assert_select "div#mentor_#{users(:f_mentor_student).id}" do
      assert_select "span.ct-match-percent", :count => 0
    end
  end

  def test_mentor_listing_should_not_render_favorite_mentor_for_self_when_mentor_student_tightly
    make_member_of(:moderated_program, :f_mentor_student)
    current_user_is :f_mentor_student

    # The match storage does have f_mentor_student as a member of moderated_program
    # So, stub matching.
    User.any_instance.expects(:student_document_available?).returns(true)
    User.expects(:get_availability_slots_for).returns({})
    User.expects(:get_filtered_users).returns([users(:f_mentor_student).id])
    get :index, params: { filter: [UserSearch::SHOW_NO_MATCH_FILTER]}

    assert_select "div#mentor_#{users(:f_mentor_student).id}" do
      assert_select "a", text: "Add to preferred mentors", count: 0
    end
  end

  def test_mentors_list_for_student_should_show_match
    current_user_is :f_student

    mentors = wp_collection_from_array(programs(:albers).mentor_users)
    get :index, params: { :filter => 'all'}
    assert assigns(:match_view)
    assert_response :success
    assert_template 'index'
    assert_equal 'match', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert_not_nil assigns(:match_results)
    assert (0..100).include?(assigns(:match_results)[mentors.sample.id])
  end

  def test_match_config_without_questions_does_not_throw_error
    current_user_is :f_student

    create_question(:role_names => [RoleConstants::STUDENT_NAME])
    create_question(:role_names => [RoleConstants::MENTOR_NAME])

    # Make sure there are no match configs generated.
    assert programs(:albers).match_configs.reload.empty?

    # Now delete a few questions that are used in the config. ??
    m_config = programs(:albers).match_configs.first
    assert_nil m_config

    mentors = programs(:albers).mentor_users
    assert_nothing_raised do
      get :index, params: { :filter => 'all'}
    end
    assert assigns(:match_view)
    assert_response :success
    assert_template 'index'
    assert_equal 'match', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    match_results = assigns(:match_results)
    assert_not_nil match_results
    assert mentors.collect(&:id).collect{|m_id| match_results[m_id]}.all?{|score| score.between?(0,100)}
  end

  def test_matched_mentors_list_for_student_with_non_match_sort_order
    current_user_is :f_student

    mentors = wp_collection_from_array(programs(:albers).mentor_users.sort_by{|m| m.name.downcase})
    get :index, params: { :sort => 'name', :order => 'asc', filter: ['all', UserSearch::SHOW_NO_MATCH_FILTER]}
    assert assigns(:match_view)
    assert_response :success
    assert_template 'index'
    assert_equal 'name', assigns(:sort_field)
    assert_equal 'asc', assigns(:sort_order)
    assert_equal mentors.collect(&:id), assigns(:users).collect(&:id)
  end

  def test_mentors_list_for_mentors_should_not_show_match
    current_user_is :f_mentor

    mentors = wp_collection_from_array(programs(:albers).mentor_users.sort_by{|m| m.name.downcase})
    get :index
    assert !assigns(:match_view)
    assert !assigns(:show_filters)
    assert_response :success
    assert_template 'index'
    assert_equal mentors.collect(&:id), assigns(:users).collect(&:id)
  end

  def test_mentors_list_in_tightly_managed_shows_match
    current_user_is :moderated_student

    mentors = wp_collection_from_array(programs(:moderated_program).mentor_users.sort_by{|m| m.name.downcase})
    get :index
    assert assigns(:match_view)
    assert_response :success
    assert_template 'index'
    assert_equal 'match', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert_not_nil assigns(:match_results)
    assert (0..100).include?(assigns(:match_results)[mentors.sample.id])
  end

  def test_mentors_listing_for_students_show_the_available
    current_user_is users(:f_student)

    get :index, params: { :sort => 'name', :order => 'asc'}
    assert_response :success
    assert assigns(:filter_field).include? UsersIndexFilters::Values::AVAILABLE
    assert !assigns(:users).include?(users(:not_requestable_mentor))
  end

  def test_mentors_listing_for_students_show_the_all
    current_user_is users(:f_student)

    get :index, params: { :sort => 'name', :order => 'desc', :filter => 'all', :items_per_page => 40}
    assert_response :success
    assert_equal "all", assigns(:filter_field)
    assert assigns(:users).include?(users(:not_requestable_mentor))
  end

  def test_mentors_list_other_than_students_no_one_can_see_filtering_options
    current_user_is users(:f_mentor)

    mentors = wp_collection_from_array(programs(:albers).mentor_users.sort_by{|m| m.name.downcase})
    # Fetch page 2 records, thus validating pagination too.
    get :index
    assert_response :success
    assert_equal "all", assigns(:filter_field)
    assert_arrays_equal mentors.collect(&:id), assigns(:users).collect(&:id)
    assert_select "div.filter_links", 0
  end
end