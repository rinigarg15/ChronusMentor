require_relative "./../test_helper.rb"

class MatchReportsControllerTest < ActionController::TestCase

  def setup
    super
    programs(:albers).enable_feature(FeatureName::MATCH_REPORT, true)
  end

  def test_edit_section_settings_denied
    current_user_is :f_mentor

    assert_permission_denied do
      get :edit_section_settings, xhr: true, params: { section: MatchReport::Sections::MentorDistribution }
    end
  end

  def test_index_with_admin_view_id
    current_user_is :f_admin

    get :index, params: { edit_section: true, admin_view_id: 23}
    assert assigns(:edit_section)
    assert_equal "23", assigns(:admin_view_id)
  end

  def test_preview_view_details
    admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)

    current_user_is :f_admin
    get :preview_view_details, xhr: true, params: { role: RoleConstants::MENTOR_NAME, admin_view_id: admin_view.id}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role)
    assert_equal admin_view, assigns(:admin_view)
    assert_equal 1, assigns(:admin_view_filters).keys.size
    assert_equal "Roles", assigns(:admin_view_filters).keys.first
    assert_equal "#{RoleConstants::MENTOR_NAME}".capitalize, assigns(:admin_view_filters).values.first
  end

  def test_edit_section
    program = programs(:albers)
    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(true)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])

    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :f_admin
    get :edit_section_settings, xhr: true, params: { section: MatchReport::Sections::MentorDistribution}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS)
    assert_equal mentor_view, assigns(:mentor_view)
    assert_equal student_views[2], assigns(:mentee_view)
    assert_equal mentor_views, assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
    mentor_view_filters = {"Roles"=>"Mentor", "User Status"=>"Active", "Mentor Availability"=>"Have connection slots greater than 0"}
    mentee_view_filters = {"Roles"=>"Student", "User Status"=>"Active", "User's mentoring connection status"=>"Currently not connected"}
    assert_equal mentor_view_filters, assigns(:mentor_view_filters)
    assert_equal mentee_view_filters, assigns(:mentee_view_filters)
    assert_equal MatchReport::Sections::MentorDistribution, assigns(:section)
  end

  def test_edit_section_mentee_actions
    program = programs(:albers)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])

    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :f_admin
    get :edit_section_settings, xhr: true, params: { section: MatchReport::Sections::MenteeActions}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    assert_nil assigns(:mentor_view)
    assert_equal student_views[0], assigns(:mentee_view)
    assert_equal mentor_views, assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
    mentee_view_filters = {"Roles"=>"Student"}
    assert_nil assigns(:mentor_view_filters)
    assert_equal mentee_view_filters, assigns(:mentee_view_filters)
    assert_equal MatchReport::Sections::MenteeActions, assigns(:section)
  end

  def test_edit_section_html_request
    current_user_is :f_admin
    get :edit_section_settings, params: { section: MatchReport::Sections::MenteeActions}
    assert_redirected_to match_reports_path(edit_section: true, section: MatchReport::Sections::MenteeActions)
  end

  def test_edit_section_new_admin_view
    program = programs(:ceg)
    program.enable_feature(FeatureName::MATCH_REPORT, true)
    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(true)
    new_mentor_view = AdminView.create!(title: "New View", program: program, filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::MENTOR_NAME] } } }.to_yaml)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])
    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :ceg_admin
    get :edit_section_settings, xhr: true, params: { section: MatchReport::Sections::MentorDistribution, admin_view_id: new_mentor_view.id}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    assert_equal_unordered mentor_views + [new_mentor_view], assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
    assert_equal new_mentor_view, assigns(:mentor_view)
    assert_equal student_views[2], assigns(:mentee_view)
    assert_equal MatchReport::Sections::MentorDistribution, assigns(:section)
  end

  def test_update_settings
    program = programs(:albers)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)

    current_user_is :f_admin
    patch :update_section_settings, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, section: MatchReport::Sections::MentorDistribution}
    assert_redirected_to match_report_async_loading_path(remote: true, update_settings: true, section: MatchReport::Sections::MentorDistribution)
    assert_equal mentor_view, program.match_report_admin_views.where(section_type: MatchReport::Sections::MentorDistribution, role_type: RoleConstants::MENTOR_NAME).first.admin_view
    assert_equal student_view, program.match_report_admin_views.where(section_type: MatchReport::Sections::MentorDistribution, role_type: RoleConstants::STUDENT_NAME).first.admin_view
    assert_equal MatchReport::Sections::MentorDistribution, assigns(:section)
  end

  def test_update_settings_mentee_actions
    program = programs(:albers)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::NEVER_CONNECTED_MENTEES)

    current_user_is :f_admin
    patch :update_section_settings, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, section: MatchReport::Sections::MenteeActions}
    assert_redirected_to match_report_async_loading_path(remote: true, update_settings: true, section: MatchReport::Sections::MenteeActions)
    assert_nil program.match_report_admin_views.where(section_type: MatchReport::Sections::MenteeActions, role_type: RoleConstants::MENTOR_NAME).first
    assert_equal student_view, program.match_report_admin_views.where(section_type: MatchReport::Sections::MenteeActions, role_type: RoleConstants::STUDENT_NAME).first.admin_view
    assert_equal MatchReport::Sections::MenteeActions, assigns(:section)
  end

  def test_match_report_async_loading
    program = programs(:albers)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    student_view_user_ids = student_view.generate_view("", "",false).to_a
    UserSearchActivity.expects(:get_search_keywords).with({program_id: program.id, user_id: student_view_user_ids}).once.returns([{keyword: "sample answer text", count: 3}, {keyword: "hyderabad", count: 1}])

    current_user_is :f_admin
    patch :match_report_async_loading, xhr: true, params: { update_settings: true, section: MatchReport::Sections::MenteeActions}
    assert_response :success
    assert_nil program.match_report_admin_views.where(section_type: MatchReport::Sections::MenteeActions, role_type: RoleConstants::MENTOR_NAME).first
    assert_equal student_view, program.match_report_admin_views.where(section_type: MatchReport::Sections::MenteeActions, role_type: RoleConstants::STUDENT_NAME).first.admin_view
    assert_equal MatchReport::Sections::MenteeActions, assigns(:section)
    assert assigns(:skip_hiding_loader)
    assert assigns(:update_settings)
    assert_nil assigns(:mentor_view)
    assert_nil assigns(:mentor_view_users)
    assert_equal MatchReport::Sections::Partials[MatchReport::Sections::MenteeActions][:partial], assigns(:partial)
    assert_equal MatchReport::Sections::Partials[MatchReport::Sections::MenteeActions][:element_id], assigns(:element_id)
    assert_equal student_view, assigns(:mentee_view)
    assert_equal student_view.generate_view("", "",false).to_a, assigns(:mentee_view_users)
    assert_nil assigns(:match_config_question_texts_hash)
    expected_section_data = {filter_data: {profile_questions(:string_q) => 1, profile_questions(:student_multi_choice_q) => 1}, search_data: [{keyword: "sample answer text", count: 3}, {keyword: "hyderabad", count: 1}]}
    assert_equal expected_section_data, assigns(:section_data)
  end

  def test_match_report_async_loading_mentor_distribution
    program = programs(:albers)
    login_as_super_user
    match_config_1 = program.match_configs.create(student_question: role_questions(:single_choice_role_q), mentor_question: role_questions(:single_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    match_config_2 = program.match_configs.create(student_question: role_questions(:student_single_choice_role_q), mentor_question: role_questions(:multi_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(true)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::AVAILABLE_MENTORS)
    match_configs = program.match_configs.order("weight DESC").includes(mentor_question: [:profile_question], student_question: [:profile_question]).select(&:questions_choice_based?)
    MatchConfigDiscrepancyCache.find_by(match_config: match_config_1).update_attributes!(top_discrepancy: [{:discrepancy => 4, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"20+ years"}, {:discrepancy => 2, :student_need_count =>6, :mentor_offer_count =>4, :student_answer_choice =>"6-10 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>2, :student_answer_choice =>"3-5 years"}, {:discrepancy => 2, :student_need_count =>2, :mentor_offer_count =>0, :student_answer_choice =>"0-2 years"}, {:discrepancy => 1, :student_need_count =>4, :mentor_offer_count =>3, :student_answer_choice =>"11-20 years"}])
    MatchConfigDiscrepancyCache.find_by(match_config: match_config_2).update_attributes!(top_discrepancy: [{:discrepancy => 9, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"random"}])
    match_config_question_texts_hash = Hash[match_configs.map{|config| [config.id, config.mentor_question.profile_question.question_text]}]

    current_user_is :f_admin
    patch :match_report_async_loading, xhr: true, params: { update_settings: true, section: MatchReport::Sections::MentorDistribution}
    assert_response :success
    assert_equal student_view, program.match_report_admin_views.where(section_type: MatchReport::Sections::MentorDistribution, role_type: RoleConstants::STUDENT_NAME).first.admin_view
    assert_equal MatchReport::Sections::MentorDistribution, assigns(:section)
    assert assigns(:skip_hiding_loader)
    assert assigns(:update_settings)
    assert_equal mentor_view, assigns(:mentor_view)
    assert_equal mentor_view.generate_view("", "",false).to_a, assigns(:mentor_view_users)
    assert_equal MatchReport::Sections::Partials[MatchReport::Sections::MentorDistribution][:partial], assigns(:partial)
    assert_equal MatchReport::Sections::Partials[MatchReport::Sections::MentorDistribution][:element_id], assigns(:element_id)
    assert_equal student_view, assigns(:mentee_view)
    assert_equal student_view.generate_view("", "",false).to_a, assigns(:mentee_view_users)
    assert_equal match_config_question_texts_hash, assigns(:match_config_question_texts_hash)
    assert_equal [{"discrepancy"=>9, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"random"}, {"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"20+ years"}, {"discrepancy"=>2, "student_need_count"=>2, "mentor_offer_count"=>0, "student_answer_choice"=>"0-2 years"}], assigns(:top_match_configs)
  end

  def test_show_discrepancy_graph_or_table_graph
    current_user_is :f_admin
    program = programs(:albers)
    login_as_super_user
    match_config = program.match_configs.create(student_question: role_questions(:single_choice_role_q), mentor_question: role_questions(:single_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.any_instance.stubs(:get_discrepancy_graph_series_data).returns([["Leadership", "Ownership", "Data driven", "Random"], [{name: "Leadership", data: "Leadership", stack: "mentor", color: "#FFA500" }, {name: "Ownership", data: "Ownership", stack: "mentee", color: "#1ab394" }], 0, 9])
    program.reload
    get :show_discrepancy_graph_or_table, xhr: true, params: { match_config_id: match_config.id, show_graph: true }
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_equal ["Leadership", "Ownership", "Data driven", "Random"], response_body["categories"]
    assert_equal [{"name"=>"Leadership", "data"=>"Leadership", "stack"=>"mentor", "color"=>"#FFA500"}, {"name"=>"Ownership", "data"=>"Ownership", "stack"=>"mentee", "color"=>"#1ab394"}], response_body["series_data"]
    assert_equal 0, response_body["remaining_categories_size"]
    assert_equal 0, response_body["remaining_categories_size"]
    assert_equal match_config.id, response_body["match_config_id"]
  end

  def test_show_discrepancy_graph_or_table_table
    current_user_is :f_admin
    program = programs(:albers)
    login_as_super_user
    mc = program.match_configs.create(student_question: role_questions(:single_choice_role_q), mentor_question: role_questions(:single_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    program.reload
    get :show_discrepancy_graph_or_table, xhr: true, params: { match_config_id: mc.id }
    assert_response :success
    assert_template partial: 'match_reports/mentor_distribution/_show_discrepancy_table'
  end

  def test_index_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      get :index
    end
  end

  def test_index_success
    current_user_is :f_admin
    program = programs(:albers)
    get :index
    match_report = assigns(:match_report)
    assert_equal program, match_report.program
    assert_equal_unordered MatchReport::Sections::NonDefaultSections, match_report.non_default_sections
    assert_equal program, match_report.default_sections_data.first[MatchReport::Sections::CurrentStatus].program
    assert_equal program.created_at, match_report.default_sections_data.first[MatchReport::Sections::CurrentStatus].startDate
    assert match_report.default_sections_data.first[MatchReport::Sections::CurrentStatus].is_a?(MatchReport::CurrentStatus)
  end

  def test_get_discrepancy_table_data
    current_user_is :f_admin
    program = programs(:albers)
    login_as_super_user
    mc = program.match_configs.create(student_question: role_questions(:single_choice_role_q), mentor_question: role_questions(:single_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    program.reload
    MatchReport::Sections::SectionClasses[MatchReport::Sections::MentorDistribution].constantize.any_instance.stubs(:calculate_data_discrepancy).returns([{:discrepancy => 9, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"random"}, {:discrepancy => 4, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"20+ years"}, {:discrepancy => 2, :student_need_count =>2, :mentor_offer_count =>0, :student_answer_choice =>"0-22 years"}, {:discrepancy => 2, :student_need_count =>2, :mentor_offer_count =>0, :student_answer_choice =>"0-28 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-9 years"}, {:discrepancy => 2, :student_need_count =>9, :mentor_offer_count =>0, :student_answer_choice =>"0-20 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-5 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-1 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-11 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-5 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-2 years"}])
    get :get_discrepancy_table_data, xhr: true, params: { match_config_id: mc.id }
    assert_equal [{:discrepancy => 9, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"random"}, {:discrepancy => 4, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"20+ years"}, {:discrepancy => 2, :student_need_count =>2, :mentor_offer_count =>0, :student_answer_choice =>"0-22 years"}, {:discrepancy => 2, :student_need_count =>2, :mentor_offer_count =>0, :student_answer_choice =>"0-28 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-9 years"}, {:discrepancy => 2, :student_need_count =>9, :mentor_offer_count =>0, :student_answer_choice =>"0-20 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-5 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-1 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-11 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>0, :student_answer_choice =>"0-5 years"}], assigns(:discrepancy_data)
    assert_equal 11, assigns(:total_count)
  end

  def test_refresh_top_mentor_recommendations
    program = programs(:albers)
    login_as_super_user
    match_config_1 = program.match_configs.create(student_question: role_questions(:single_choice_role_q), mentor_question: role_questions(:single_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    match_config_2 = program.match_configs.create(student_question: role_questions(:student_single_choice_role_q), mentor_question: role_questions(:multi_choice_role_q), operator: MatchConfig::Operator::lt, threshold: 0.1)
    Program.any_instance.stubs(:only_one_time_mentoring_enabled?).returns(true)
    match_configs = program.match_configs.order("weight DESC").includes(mentor_question: [:profile_question], student_question: [:profile_question]).select(&:questions_choice_based?)
    MatchConfigDiscrepancyCache.find_by(match_config: match_config_1).update_attributes!(top_discrepancy: [{:discrepancy => 4, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"20+ years"}, {:discrepancy => 2, :student_need_count =>6, :mentor_offer_count =>4, :student_answer_choice =>"6-10 years"}, {:discrepancy => 2, :student_need_count =>4, :mentor_offer_count =>2, :student_answer_choice =>"3-5 years"}, {:discrepancy => 2, :student_need_count =>2, :mentor_offer_count =>0, :student_answer_choice =>"0-2 years"}, {:discrepancy => 1, :student_need_count =>4, :mentor_offer_count =>3, :student_answer_choice =>"11-20 years"}])
    MatchConfigDiscrepancyCache.find_by(match_config: match_config_2).update_attributes!(top_discrepancy: [{:discrepancy => 9, :student_need_count =>8, :mentor_offer_count =>4, :student_answer_choice =>"random"}])
    match_config_question_texts_hash = Hash[match_configs.map{|config| [config.id, config.mentor_question.profile_question.question_text]}]
    MatchConfig.any_instance.expects(:refresh_match_config_discrepancy_cache).once

    current_user_is :f_admin
    get :refresh_top_mentor_recommendations, xhr: true, params: { match_config_id: match_config_1.id}
    assert_response :success
    assert_equal match_config_question_texts_hash, assigns(:match_config_question_texts_hash)
    assert_equal [{"discrepancy"=>9, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"random"}, {"discrepancy"=>4, "student_need_count"=>8, "mentor_offer_count"=>4, "student_answer_choice"=>"20+ years"}, {"discrepancy"=>2, "student_need_count"=>2, "mentor_offer_count"=>0, "student_answer_choice"=>"0-2 years"}], assigns(:top_match_configs)
  end
end