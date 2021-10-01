require_relative './../test_helper.rb'

class ReportsControllerTest < ActionController::TestCase
  include HealthReportsHelper
  include GroupsReportExtensions
  include Report::Customization

  def setup
    super
    report_role = create_role(:name => 'report_role')
    add_role_permission(report_role, 'view_reports')
    @report_manager = create_user(:role_names => ['report_role'])
    current_program_is :albers
    current_user_is @report_manager
  end

  def test_view_reports_permission
    current_user_is users(:f_student)
    programs(:albers).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :index
    end
    assert_permission_denied do
      get :executive_summary
    end
    assert_permission_denied do
      get :outcomes_report
    end
    assert_permission_denied do
      get :demographic_report
    end
    assert_permission_denied do
      get :health_report
    end
    assert_permission_denied do
      get :groups_report
    end
    assert_permission_denied do
      get :activity_report
    end
  end

  def test_index
    user = users(:f_admin)
    program = user.program
    current_program_is program
    current_user_is user

    categories = [
      {
        category: Category::HEALTH,
        name: "Health Reports",
        description: "Collection of reports that help in assessing the health of the program from matching, mentoring connection, activity and survey point of view",
        icon: "fa fa-medkit"
      },
      {
        category: Category::OUTCOME,
        name: "Outcome Reports",
        description: "Collection of reports that provide insight into the outcomes of the program",
        icon: "fa fa-line-chart"
      },
      {
        category: Category::USER,
        name: "User Reports",
        description: "Collection of reports that provide insight into the distribution of users",
        icon: "fa fa-user"
      },
    ]

    get :index

    assert_response :success
    assert_equal categories, assigns(:categories)
  end

  def test_categorized_health_report
    user = users(:f_admin)
    program = user.program
    setup_program_for_reports(program)

    EngagementSurvey.any_instance.stubs(:total_responses).returns(1)
    MeetingFeedbackSurvey.any_instance.stubs(:total_responses).returns(1)
    User.any_instance.expects(:can_view_match_report?).returns(true)
    current_user_is user
    get :categorized, params: { category: Category::HEALTH}
    assert_response :success
    assert_equal Category::HEALTH, assigns(:category)
    assert_equal "Health Reports", assigns(:title)
    assert_equal "Collection of reports that help in assessing the health of the program from matching, mentoring connection, activity and survey point of view", assigns(:title_description)

    reports_by_subcategory_hash = assigns(:reports_by_subcategory_hash)
    expected_subcategories = {
      "enrollment" => [ReportItem::MEMBERSHIP_REQUESTS, ReportItem::INVITATION],
      "matching" => [ReportItem::MATCH_REPORT, ReportItem::MENTOR_REQUESTS, ReportItem::MENTOR_OFFERS, ReportItem::MEETING_REQUESTS],
      "post_matching" => [ReportItem::MENTORING_CONNECTION_ACTIVITY, ReportItem::ACTIVITY_REPORT_DESCRIPTION, ReportItem::MENTORING_CALENDAR, ReportItem::CONTRACT_MANAGEMENT, ReportItem::MEETING_CALENDAR],
      "meeting_surveys" => [ReportItem::MEETING_SURVEY],
      "engagement_surveys" => [ReportItem::ENGAGEMENT_SURVEY]
    }
    assert_equal expected_subcategories.keys, reports_by_subcategory_hash.keys
    expected_subcategories.each do |expected_subcategory, expected_items|
      assert_equal expected_items.count, reports_by_subcategory_hash[expected_subcategory].count
    end

    reports_attributes_list = assigns(:reports_attributes_list)
    collections_hash = reports_attributes_list.select { |report_hash| report_hash[:collection].present? }
    normal_reports_hash = reports_attributes_list - collections_hash
    assert_equal 13, reports_attributes_list.count
    assert_equal 2, collections_hash.count
    assert_equal [
      "Membership Requests",
      "Invitations",
      "Match Report",
      "Meeting Requests",
      "Mentoring Requests",
      "Mentoring Offers",
      "Meeting Report",
      "Mentoring Connection Report",
      "Mentoring Connection Activity Report",
      "Mentoring Calendar Report",
      "Mentor Check-in Report"
    ], normal_reports_hash.map { |report_hash| report_hash[:title].call(program) }

    surveys_by_type = Survey.by_type(program)
    assert_select '#reports' do
      assert_select '.list_content' do
        assert_select 'div.p-l-xs.p-b-sm' do
          assert_select "a", text: "Membership Requests"
          assert_select "a", text: "Invitations"
          assert_select "a", text: "Mentoring Requests"
          assert_select "a", text: "Mentoring Offers"
          assert_select "a", text: "Meeting Requests"
          assert_select "a", text: "Mentoring Connection Report"
          assert_select "a", text: "Mentoring Connection Activity Report"
          assert_select "a", text: "Mentoring Calendar Report"
          assert_select "a", text: "Mentor Check-in Report"
          assert_select "a", text: "Meeting Report"
          assert_select 'a', text: surveys_by_type[EngagementSurvey.name].first.name.term_titleize
          assert_select 'a', text: surveys_by_type[MeetingFeedbackSurvey.name].first.name.term_titleize
        end
      end
    end
  end

  def test_categorized_outcomes_report
    user = users(:f_admin)
    program = user.program
    setup_program_for_reports(program)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)

    ProgramSurvey.any_instance.stubs(:total_responses).returns(1)
    EngagementSurvey.any_instance.stubs(:total_responses).returns(1)
    MeetingFeedbackSurvey.any_instance.stubs(:total_responses).returns(1)
    current_user_is user
    get :categorized, params: { category: Category::OUTCOME}
    assert_response :success
    assert_equal Category::OUTCOME, assigns(:category)
    assert_equal "Outcome Reports", assigns(:title)
    assert_equal "Collection of reports that provide insight into the outcomes of the program", assigns(:title_description)

    reports_by_subcategory_hash = assigns(:reports_by_subcategory_hash)
    expected_subcategories = {
      "program_outcomes" => [ReportItem::PROGRAM_OUTCOMES],
      "program_surveys" => [ReportItem::PROGRAM_SURVEY],
      "meeting_survey_outcome" => [ReportItem::MEETING_SURVEY],
    }
    assert_equal expected_subcategories.keys, reports_by_subcategory_hash.keys
    expected_subcategories.each do |expected_subcategory, expected_items|
      assert_equal expected_items.count, reports_by_subcategory_hash[expected_subcategory].count
    end

    reports_attributes_list = assigns(:reports_attributes_list)
    collections_hash = reports_attributes_list.select { |report_hash| report_hash[:collection].present? }
    normal_reports_hash = reports_attributes_list - collections_hash
    assert_equal expected_subcategories.count, reports_attributes_list.count
    assert_equal 2, collections_hash.count
    assert_equal ["Program Outcomes Report"], normal_reports_hash.map { |report_hash| report_hash[:title].call(program) }

    surveys_by_type = Survey.by_type(program)
    assert_select '#reports' do
      assert_select '.list_content' do
        assert_select 'div.p-l-xs.p-b-sm' do
          assert_select "a", text: "Program Outcomes Report"
          assert_select 'a', text: surveys_by_type[MeetingFeedbackSurvey.name].first.name.term_titleize
          assert_select 'a', text: surveys_by_type[ProgramSurvey.name].first.name.term_titleize
        end
        assert_select 'span.font-bold', count: (surveys_by_type.slice(ProgramSurvey.name, MeetingFeedbackSurvey.name).values.flatten.count + 1)
      end
    end
  end

  def test_categorized_user_report
    user = users(:f_admin)
    program = user.program
    setup_program_for_reports(program)

    current_user_is user
    get :categorized, params: { category: Category::USER}
    assert_response :success
    assert_equal Category::USER, assigns(:category)
    assert_equal "User Reports", assigns(:title)
    assert_equal "Collection of reports that provide insight into the distribution of users", assigns(:title_description)

    reports_by_subcategory_hash = assigns(:reports_by_subcategory_hash)
    expected_subcategories = {
      "utility" => [ReportItem::DEMOGRAPHIC],
      "user_view" => [ReportItem::USER_VIEWS]
    }
    assert_equal expected_subcategories.keys, reports_by_subcategory_hash.keys
    expected_subcategories.each do |expected_subcategory, expected_items|
      assert_equal expected_items.count, reports_by_subcategory_hash[expected_subcategory].count
    end

    reports_attributes_list = assigns(:reports_attributes_list)
    collections_hash = reports_attributes_list.select { |report_hash| report_hash[:collection].present? }
    normal_reports_hash = reports_attributes_list - collections_hash
    assert_equal 2, reports_attributes_list.count
    assert_equal 1, collections_hash.count
    assert_equal ["Geographic Distribution Report"], normal_reports_hash.map { |report_hash| report_hash[:title].call(program) }

    admin_views = program.admin_views.defaults_first
    assert_select '#reports' do
      assert_select '.list_content' do
        assert_select 'div.p-l-xs.p-b-sm' do
          assert_select "a", text: "Geographic Distribution Report"
          assert_select 'a', text: admin_views.first.title
        end
        assert_select 'i.fa-user-circle', count: admin_views.count
      end
    end
  end

  def test_outcomes_report
    program = programs(:albers)
    current_user_is users(:f_admin)
    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    survey = program.surveys.where(name: "Introduce yourself")[0]
    survey_question = survey.survey_questions.where(question_text: "Where are you from?")[0]
    survey_question.update_attribute(:positive_outcome_options, "Earth")
    Timecop.freeze do
      assert_false program.calendar_enabled?
      assert program.ongoing_mentoring_enabled?
      get :outcomes_report
      assert_false assigns(:show_flash_mentoring_sections)
      assert_equal SurveyQuestion.where(program_id: program.id, survey_id: program.surveys.of_engagement_type.map(&:id)).where("positive_outcome_options IS NOT ?", nil).reject{|q| q.positive_outcome_options.blank? }.map(&:survey).uniq, assigns(:positive_outcome_surveys)
      assert_equal program.created_at, assigns(:program_start_date)
      assert_equal program.created_at, assigns(:start_date)
      assert_equal Time.now, assigns(:end_date)
      assert_equal [survey], assigns(:positive_outcome_surveys)
    end
  end

  def test_outcomes_report_pdf_banner_fallback_when_logo_is_absent
    program = programs(:albers)
    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    organization = program.organization
    setup_banner_fallback(organization, nil)

    Timecop.freeze do
      date_range = "#{DateTime.localize(program.created_at, format: :full_display_no_time)} - #{DateTime.localize(Time.now, format: :full_display_no_time)}"
      start_date = date_range.split(DATE_RANGE_SEPARATOR)[0].to_datetime
      end_date = date_range.split(DATE_RANGE_SEPARATOR)[1].to_datetime

      # Wicked PDF tries to fetch css by sending http request which fails in test
      Theme.any_instance.stubs(:css?).returns(false)
      @controller.expects(:current_program).at_least(0).returns(program)
      current_user_is :f_admin
      get :outcomes_report, params: { format: :pdf, debug: true, date_range: date_range, filters: "", enabled: { users: "111", total: "1001", closed: "1001", positive: "1001" } }
      assert_response :success
      assert_select ".media-left.program_logo_or_banner img[src='#{TEST_ASSET_HOST + organization.banner_url}']", count: 1
    end
  end

  def test_detailed_user_outcomes_report_permission
    program = programs(:albers)
    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    current_user_is users(:f_student)
    assert_permission_denied do
      get :detailed_user_outcomes_report
    end
  end

  def test_detailed_user_outcomes_report
    program = programs(:albers)
    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)

    current_user_is users(:f_admin)
    Timecop.freeze do
      get :detailed_user_outcomes_report
      assert_equal program.created_at, assigns(:program_start_date)
      assert_equal program.created_at, assigns(:start_date)
      assert_equal Time.now, assigns(:end_date)
    end
  end

  def test_outcomes_report_for_flash_mentoring
    program = programs(:albers)
    current_user_is users(:f_admin)

    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    program.enable_feature(FeatureName::CALENDAR, true)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    get :outcomes_report
    assert assigns(:show_flash_mentoring_sections)
    assert_equal SurveyQuestion.where(program_id: program.id, survey_id: program.surveys.of_meeting_feedback_type.map(&:id)).where("positive_outcome_options IS NOT ?", nil).reject{|q| q.positive_outcome_options.blank? }.map(&:survey).uniq, assigns(:positive_outcome_surveys)
  end

  def test_index_no_default_program_outcomes_report
    current_user_is users(:f_admin)
    get :index
    assert_response :success
    assert_select 'a', :text => "Program Outcomes Report", :count => 0
  end

  def test_pdf_for_outcomes_report
    program = programs(:albers)
    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    Timecop.freeze do
      date_range = DateTime.localize(program.created_at, format: :full_display_no_time) + " - " + DateTime.localize(Time.now, format: :full_display_no_time)
      start_date = date_range.split(DATE_RANGE_SEPARATOR)[0].to_datetime
      end_date = date_range.split(DATE_RANGE_SEPARATOR)[1].to_datetime

      # Wicked PDF tries to fetch css by sending http request which fails in test
      Theme.any_instance.stubs(:css?).returns(false)
      @controller.expects(:current_program).at_least(0).returns(program)
      current_user_is :f_admin
      get :outcomes_report, params: { format: :pdf, date_range: date_range, filters: "", enabled: { users: "111", total: "1001", closed: "1001", positive: "1001" } }
      assert_response :success
      assert_equal "Program Outcomes Report", assigns(:title)
      assert_not_nil assigns(:user_outcomes_report)
      assert_not_nil assigns(:active_connection_outcomes_report)
      assert_not_nil assigns(:closed_connection_outcomes_report)
      assert_not_nil assigns(:positive_connection_outcomes_report)
    end
  end

  ##############################################################################
  # EXECUTIVE SUMMARY
  ##############################################################################

  def test_executive_summary_fetches_proper_data
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_primary).enable_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT)
    invalidate_albers_calendar_meetings
    # Adding admin role to a student to generate an admin_student
    users(:rahim).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    time_now = Time.now.utc.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    start_time = Time.now.utc.change(usec: 0) - 2.days - 50.minutes
    end_time = start_time + 30.minutes
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), start_time, end_time, options = {duration: 30.minutes})
    update_recurring_meeting_start_end_date(meetings(:student_2_not_req_mentor), (start_time - 20.minutes), (end_time - 30.minutes), options = {duration: 20.minutes})
    mentoring_slots(:f_mentor).update_attributes(:start_time => 50.minutes.ago - 2.days, :end_time => 20.minutes.ago - 2.days)

    users(:f_student).suspend_from_program!(users(:f_admin), "Sorry")

    mentor_requests = []
    mentor_requests << create_mentor_request(:student => users(:student_1), :mentor => users(:mentor_1))
    mentor_requests << create_mentor_request(:student => users(:student_2), :mentor => users(:mentor_2))

    current_user_is users(:f_admin)

    get :executive_summary
    assert_response :success
    assert_page_title "Executive Summary Report"
    assert_template 'executive_summary'
    assert_select 'html'

    assert users(:f_admin).view_management_console?

    # Excluding suspended users
    assert_equal 43, assigns(:total_users_count)

    # Users in multiple roles
    assert_equal 1, assigns(:multi_roles_users_count)

    # users count by role
    assert_equal 22, assigns(:users_count_hash)["mentor"]
    assert_equal 20, assigns(:users_count_hash)["student"]
    assert_equal 1, assigns(:users_count_hash)["user"]
    assert_equal 1, assigns(:users_count_hash)["report_role"]

    assert_equal 17, assigns(:pending_requests_cnt)
    assert_equal 6, assigns(:active_groups_cnt)
    assert_equal 1, assigns(:closed_groups_cnt)

    # Mentoring Sessions Data
    assert_equal 0, assigns(:last_month_session_stats)[:hours_available]
    assert_equal 0, assigns(:last_month_session_stats)[:hours_blocked]

    assert_floats_equal 0.5, assigns(:this_month_session_stats)[:hours_available]
    assert_floats_equal 3.833, assigns(:this_month_session_stats)[:hours_blocked]

    assert_equal 0, assigns(:next_month_session_stats)[:hours_available]
    assert_equal 2.5, assigns(:next_month_session_stats)[:hours_blocked]
    assert_tab TabConstants::MANAGE
  end

  def test_executive_summary_without_mentor_requests
    program = programs(:no_mentor_request_program)
    program.enable_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT)
    current_user_is :no_mreq_admin
    student_only = create_user(:role_names => [RoleConstants::STUDENT_NAME], :name => 'stud', :program => program)
    mentor_only = create_user(:role_names => [RoleConstants::MENTOR_NAME], :name => 'mentor', :program => program)
    create_group(:students => [student_only], :mentor => mentor_only, :program => program)

    get :executive_summary
    assert_response :success
    assert_page_title "Executive Summary Report"
    assert_template 'executive_summary'
    assert_select 'html'

    assert users(:no_mreq_admin).view_management_console?
    assert_select "td", :text => "Pending mentor requests", :count => 0

    assert_nil assigns(:pending_requests_cnt)
    assert_equal 2, assigns(:active_groups_cnt)
    assert_tab TabConstants::MANAGE
  end

  def test_empty_graphs
    # programs(:ceg) has no mentor_request and no groups
    current_user_is users(:ceg_admin)
    programs(:ceg).enable_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT)
    get :executive_summary
    assert_response :success
    assert_select 'html' do
      assert_select '.graph_column' do
        assert_select '.no_graph', :count => 1, :text => 'No data available'
      end
    end
  end

  ##############################################################################
  # HEALTH REPORT
  ##############################################################################

  def test_program_health_report
    HealthReport::Growth.any_instance.expects(:no_graph_data?).at_least(1).returns(false)
    get :health_report
    assert_response :success
    assert_page_title "Program Health Report"
    assert_template 'health_report'
    assert_select 'html'

    assert_select '#health_report' do
      assert_select '#health_report_growth_chart', :count => 1
    end

    assert @report_manager.view_management_console?
  end

  def test_pdf_export_for_health_report
    current_user_is users(:f_admin)
    p = programs(:albers)

    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
    get :health_report, params: { :format => 'pdf'}

    assert_response :success
    report = assigns(:health_report)
    assert_equal "Program Health Report", assigns(:title)
    assert_not_nil report
  end

  def test_health_report_js
    current_user_is users(:f_admin)
    p = programs(:albers)

    get :health_report, xhr: true, params: { :report => 'engagement'}

    assert_response :success
    report = assigns(:health_report)
    assert_not_nil report
    assert_not_nil report.engagement.cumulative_value
  end

  def test_health_report_js_permission_denied
    current_user_is users(:f_admin)
    p = programs(:albers)

    assert_raise(TypeError) do
      get :health_report, xhr: true, params: { :report => 'something'}
    end
  end

  def test_activity_report_with_no_filters
    current_user_is users(:f_admin)

    get :activity_report
    assert_response :success
    assert_page_title "Activity Report"

    assert_select "#title_actions" do
      assert_select "#action_1" do
        assert_select "i.fa-file-excel-o"
      end
    end

    report = assigns(:program_health_report)
    assert_not_nil report

    assert_select '#health_report' do
      assert_select '#health_report_program_activity_trend_chart', :count => 1
      assert_select '#health_report_program_activity_summary_table', :count => 1
      assert_select '#health_report_program_activity_summary_chart', :count => 1
      assert_select '#health_report_mentoring_activity_trend_chart', :count => 1
      assert_select '#health_report_mentoring_activity_summary_table', :count => 1
      assert_select '#health_report_ongoing_mentoring_activity_summary_chart', :count => 1
      assert_select '#health_report_community_activity_trend_chart', :count => 1
      assert_select '#health_report_community_activity_summary_table', :count => 1
    end

    assert @report_manager.view_management_console?
  end

  def test_activity_report_with_filters
    current_user_is users(:f_admin)
    p = programs(:albers)

    role_filter = "all"
    date_range_filter = "#{(p.created_at).strftime(date_range_format)} - #{(Time.now).strftime(date_range_format)}"
    get :activity_report, params: { :date_range_filter => date_range_filter, :role_filter => role_filter}
    assert_response :success
    assert_page_title "Activity Report"

    assert_select "#title_actions" do
      assert_select "#action_1" do
        assert_select "i.fa-file-excel-o"
      end
    end

    assert_select "#title_actions" do
      assert_select "#action_1" do
        assert_select 'a', :href => activity_report_path(:format => :csv, :role_filter => role_filter, :date_range_filter => date_range_filter)
      end
    end

    report = assigns(:program_health_report)
    assert_not_nil report

    assert_select '#health_report' do
      assert_select '#health_report_program_activity_trend_chart', :count => 1
      assert_select '#health_report_program_activity_summary_table', :count => 1
      assert_select '#health_report_program_activity_summary_chart', :count => 1
      assert_select '#health_report_mentoring_activity_trend_chart', :count => 1
      assert_select '#health_report_mentoring_activity_summary_table', :count => 1
      assert_select '#health_report_ongoing_mentoring_activity_summary_chart', :count => 1
      assert_select '#health_report_community_activity_trend_chart', :count => 1
      assert_select '#health_report_community_activity_summary_table', :count => 1
    end

    assert @report_manager.view_management_console?
  end

  def test_activity_report_with_date_range_filter_timezones
    current_user_is users(:f_admin)
    p = programs(:albers)

    members(:f_admin).update_attribute(:time_zone, "Asia/Tokyo")
    get :activity_report, params: { :date_range_filter => "02/02/2010 - 03/03/2011"}
    assert_response :success
    assert_equal "+09:00", assigns(:start_time).zone
    assert_equal "+09:00", assigns(:end_time).zone
  end

  def test_activity_report_with_date_range_filter_timezones_in_pdf
    current_user_is users(:f_admin)
    p = programs(:albers)

    members(:f_admin).update_attribute(:time_zone, "Asia/Tokyo")
    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
    get :activity_report, params: { :format => 'pdf', :date_range_filter => "02/02/2010 - 03/03/2011"}
    assert_response :success
    assert_equal "+09:00", assigns(:start_time).zone
    assert_equal "+09:00", assigns(:end_time).zone
  end

  def test_csv_export_for_activity_report_if_ongoing_mentoring_enabled
    current_user_is users(:f_admin)
    p = programs(:albers)
    p.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    p.reload

    get :activity_report, params: { :format => 'csv',
      :date_range_filter => "#{(p.created_at).strftime(date_range_format)} - #{(Time.now).strftime(date_range_format)}",
      :role_filter => "all"
    }

    assert_response :success
    report = assigns(:program_health_report)
    assert_not_nil report
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body.split("\n")
    assert_match /Activity summary/, csv_response[0]
    assert_match /Total Registered Users/, csv_response[1]
    assert_match /Total Active Users/, csv_response[2]
    assert_match /Total users in mentoring connections/, csv_response[3]
    assert_match /Total active users in mentoring connections/, csv_response[4]
    assert_match /Total Unique Community Visitors/, csv_response[5]
    assert_match /Total Unique Resource Visitors/, csv_response[6]
    assert_match /Total Unique Question & Answer Visitors/, csv_response[9]
  end

  def test_csv_export_for_activity_report_if_ongoing_mentoring_disabled
    current_user_is users(:f_admin)
    p = programs(:albers)
    p.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    p.reload

    get :activity_report, params: { :format => 'csv',
      :date_range_filter => "#{(p.created_at).strftime(date_range_format)} - #{(Time.now).strftime(date_range_format)}",
      :role_filter => "all"
    }
    
    assert_response :success
    report = assigns(:program_health_report)
    assert_not_nil report
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body.split("\n")
    assert_match /Activity summary/, csv_response[0]
    assert_match /Total Registered Users/, csv_response[1]
    assert_match /Total Active Users/, csv_response[2]
    assert_no_match(/Total users in mentoring connections/, csv_response[3])
    assert_no_match(/Total active users in mentoring connections/, csv_response[4])
    assert_match /Total Unique Community Visitors/, csv_response[3]
    assert_match /Total Unique Resource Visitors/, csv_response[4]
    assert_match /Total Unique Question & Answer Visitors/, csv_response[7]
  end

  def test_pdf_for_activity_report
    current_user_is users(:f_admin)
    p = programs(:albers)

    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
    get :activity_report, params: { :format => 'pdf',
      :date_range_filter => "#{(p.created_at).strftime(date_range_format)} - #{(Time.now).strftime(date_range_format)}",
      :role_filter => "all"
    }

    assert_response :success
    report = assigns(:program_health_report)
    assert_equal "Activity Report", assigns(:title)
    assert_not_nil report
  end

  def test_groups_report_permission_denied
    Program.any_instance.stubs(:show_groups_report?).returns(false)
    current_user_is users(:f_admin)
    assert_permission_denied do
      get :groups_report
    end
  end

  def test_groups_report
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program = programs(:albers)

    current_user_is users(:f_admin)
    get :groups_report, params: { "filters"=>{"filters_applied"=>"true", "view"=>"", "sort"=>"mentors", "order"=>"desc", "src"=>"", "tab"=>"", "sub_filter"=>{"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, "search_filters"=>{"v2_tasks_status"=>"", "survey_status"=>{"survey_id"=>"", "survey_task_status"=>""}, "survey_response"=>{"survey_id"=>""}, "profile_name"=>"", "started_date"=>"", "close_date"=>""}, "member_filters"=>{"5"=>"", "6"=>""}, "date_range"=>"12/14/2013 - 03/14/2014"}}

    assert_response :success
    assert_page_title "Mentoring Connection Activity Report"
    assert_equal program.report_view_columns.for_groups_report, assigns(:report_view_columns)
    assert_equal ReportViewColumn::GroupsReport::Key::MENTORS, assigns(:sort_param)
    assert_equal "desc", assigns(:sort_order)
    assert_equal "Sat, 14 Dec 2013 00:00:00 +0000".to_datetime, assigns(:start_date)
    assert_equal "Sat, 14 Mar 2014 23:59:59 +0000".to_datetime.end_of_day, assigns(:end_date)
    assert assigns(:chart_updated)
    assert assigns(:add_closed_filter)
    assert assigns(:closed_filter)
    assert assigns(:is_manage_connections_view)
    assert_equal 0, assigns(:filters_count)
    assert_equal_hash({"v2_tasks_status"=>"", "profile_name"=>"", "started_date"=>"", "close_date"=>""}, assigns(:search_filters))
    assert_equal_hash({"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, assigns(:sub_filter))
    assert_equal_hash({}, assigns(:member_filters))
    assert_equal 7, assigns(:point_interval)
  end

  def test_groups_report_for_started_on_filter
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program = programs(:albers)
    start_date = (5.days.ago).to_time
    end_date = (10.days.from_now).to_time
    date_input = start_date.strftime("%m/%d/%Y") + " - " + end_date.strftime("%m/%d/%Y")
    members(:f_admin).update_attribute(:time_zone, "Asia/Kolkata")

    start_time = (Time.now.utc-10.days).to_time
    end_time = (Time.now.utc + 10.days).to_time
    date_range = start_time.strftime("%m/%d/%Y") + " - " + end_time.strftime("%m/%d/%Y")

    current_user_is users(:f_admin)
    get :groups_report, params: { "filters"=>{"filters_applied"=>"true", "view"=>"", "sort"=>"mentors", "order"=>"desc", "src"=>"", "tab"=>"", "sub_filter"=>{"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, "search_filters"=>{milestone_status: "", profile_name: "", started_date:  date_input}, "member_filters"=>{"5"=>"", "6"=>""}, "point_interval" => 1, "date_range"=> date_range}, "root"=>"p1"}
    assert_response :success
    assert_equal 1, assigns(:filters_count)
    assert_equal_hash({milestone_status: "", profile_name: "", started_date:  date_input}, assigns(:search_filters))
    assert_equal_hash({"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, assigns(:sub_filter))
    assert_equal_hash({}, assigns(:member_filters))
    assert_equal "+05:30", assigns(:started_start_time).zone
    assert_in_delta start_time.beginning_of_day.to_datetime.change(offset: "+05:30"), assigns(:start_date)
    assert_in_delta end_time.end_of_day.to_datetime.change(offset: "+05:30"), assigns(:end_date)
    expected_group_ids = groups(:mygroup, :group_2, :group_3, :group_4, :group_5, :group_inactive).collect { |grp| grp.id }
    assert_equal_unordered expected_group_ids, assigns(:groups).collect { |grp| grp.id }
    assert_equal 1, assigns(:point_interval)
  end

  def test_groups_report_for_active_groups_only
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    start_date = (5.days.ago).to_time
    end_date = (10.days.from_now).to_time
    date_input = start_date.strftime("%m/%d/%Y") + " - " + end_date.strftime("%m/%d/%Y")
    members(:f_admin).update_attribute(:time_zone, "Asia/Kolkata")

    start_time = (Time.now.utc-10.days).to_time
    end_time = (Time.now.utc + 10.days).to_time
    date_range = start_time.strftime("%m/%d/%Y") + " - " + end_time.strftime("%m/%d/%Y")

    g = groups(:mygroup)
    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    g.update_attributes!(closed_at: Time.now.utc + 2.day)

    g = groups(:group_2)
    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    g.update_attributes!(closed_at: Time.now.utc-12.days)

    g = groups(:group_3)
    g.update_attributes!(published_at: Time.now.utc + 12.days)

    current_user_is users(:f_admin)
    get :groups_report, params: { "filters"=>{"filters_applied"=>"true", "view"=>"", "sort"=>"mentors", "order"=>"desc", "src"=>"", "tab"=>"", "sub_filter"=>{"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, "search_filters"=>{milestone_status: "", profile_name: "", started_date:  date_input}, "member_filters"=>{"5"=>"", "6"=>""}, "point_interval" => 1, "date_range" => date_range}, "root"=>"p1"}
    assert_response :success
    expected_group_ids = groups(:mygroup, :group_5, :group_inactive, :group_4).collect { |grp| grp.id }
    assert_equal_unordered expected_group_ids, assigns(:groups).collect { |grp| grp.id }
  end

  def test_groups_report_for_close_date_filter
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program = programs(:albers)
    start_date = (5.days.ago).to_time
    end_date = (10.days.from_now).to_time
    date_input = start_date.strftime("%m/%d/%Y") + " - " + end_date.strftime("%m/%d/%Y")

    start_time = (Time.now.utc-10.days).to_time
    end_time = (Time.now.utc + 10.days).to_time
    date_range = start_time.strftime("%m/%d/%Y") + " - " + end_time.strftime("%m/%d/%Y")

    members(:f_admin).update_attribute(:time_zone, "Asia/Tokyo")

    current_user_is users(:f_admin)
    get :groups_report, params: { "filters"=>{"filters_applied"=>"true", "view"=>"", "sort"=>"mentors", "order"=>"desc", "src"=>"", "tab"=>"", "sub_filter"=>{"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, "search_filters"=>{milestone_status: "", profile_name: "", close_date:  date_input}, "member_filters"=>{"5"=>"", "6"=>""}, "date_range"=> date_range}, "root"=>"p1"}
    assert_response :success
    assert_equal "+09:00", assigns(:close_start_time).zone
    assert_equal 1, assigns(:filters_count)
    assert_equal_hash({milestone_status: "", profile_name: "", close_date:  date_input}, assigns(:search_filters))
    assert_equal_hash({"not_started"=>"10", "inactive"=>"1", "active"=>"0", "closed"=>"2"}, assigns(:sub_filter))
    assert_equal_hash({}, assigns(:member_filters))
    assert_in_delta start_time.beginning_of_day.to_datetime.change(offset: "+0900"), assigns(:start_date)
    assert_in_delta end_time.end_of_day.to_datetime.change(offset: "+0900"), assigns(:end_date)
    assert_equal_unordered [groups(:group_4).id, groups(:group_2).id], assigns(:groups).collect { |grp| grp.id }
  end

  def test_update_groups_report_columns
    program = programs(:albers)
    current_user_is users(:f_admin)

    post :groups_report, params: { :format => :js, :columns => ["group", "mentors", "mentees"]}
    assert_response :success
    assert_equal 3, program.report_view_columns.for_groups_report.count
    assert assigns(:chart_updated)
  end

  def test_groups_report_export_csv
    program = programs(:albers)
    current_user_is users(:f_admin)

    get :groups_report, params: { :format => :csv}
    assert_response :success
    assert_equal program.report_view_columns.for_groups_report, assigns(:report_view_columns)
    assert_nil assigns(:groups)
    assert_equal ReportViewColumn::GroupsReport::Key::GROUP, assigns(:sort_param)
    assert_equal "asc", assigns(:sort_order)
  end

  def test_edit_groups_report_view
    program = programs(:albers)
    current_user_is users(:f_admin)

    get :edit_groups_report_view
    assert_response :success
    assert_equal program.report_view_columns.for_groups_report, assigns(:report_view_columns)
    assert_select "#cjs_edit_columns_form" do
      assert_select "#cjs_groups_report_multiselect"
    end
  end

  def test_demographic_report
    program = programs(:albers)
    location_question = program.organization.profile_questions.find_by(question_text: "Location")
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    mentor_member_ids = RoleReference.where(role_id: mentor_role.id, ref_obj_type: User.name).collect(&:ref_obj).map(&:member_id)
    student_member_ids = RoleReference.where(role_id: student_role.id, ref_obj_type: User.name).collect(&:ref_obj).map(&:member_id)
    mentor_locations = location_question.profile_answers.where(ref_obj_type: Member.name, ref_obj_id: mentor_member_ids).collect(&:location)
    student_locations = location_question.profile_answers.where(ref_obj_type: Member.name, ref_obj_id: student_member_ids).collect(&:location)

    assert_false (mentor_locations + student_locations).include?(locations(:ukraine))
    assert_false (mentor_locations + student_locations).include?(locations(:pondicherry))
    members(:f_admin).profile_answers.create!(profile_question: location_question, location: locations(:ukraine))
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], users(:ram).role_names
    members(:ram).profile_answers.create!(profile_question: location_question, location: locations(:pondicherry))
    members(:rahim).profile_answers.create!(profile_question: location_question, location: locations(:pondicherry))

    current_user_is users(:f_admin)
    get :demographic_report
    assert_response :success
    assert_page_title "Geographic Distribution Report"
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:roles)
    assert_not_equal assigns(:locations).uniq.size, assigns(:locations).size
    assert_false assigns(:all_users_locations).collect(&:full_address).include?(locations(:ukraine).full_address)
    assert assigns(:all_users_locations).collect(&:full_address).include?(locations(:pondicherry).full_address)
    assert_equal_unordered (mentor_locations + [locations(:pondicherry)]).collect(&:full_address), assigns(:role_locations)[RoleConstants::MENTOR_NAME].collect(&:full_address)
    assert_equal_unordered (student_locations + [locations(:pondicherry)]).collect(&:full_address), assigns(:role_locations)[RoleConstants::STUDENT_NAME].collect(&:full_address)
    assert_equal program.report_view_columns.for_demographic_report.to_a, assigns(:report_view_columns)
    assert_equal ReportViewColumn::DemographicReport::Key::COUNTRY, assigns(:sort_param)
    assert_equal "asc", assigns(:sort_order)
    assert_equal_hash({}, assigns(:filter_params))
    assert_equal 0, assigns(:filters_count)
  end

  def test_demographic_report_filters
    program = programs(:albers)
    location_question = program.organization.profile_questions.find_by(question_text: "Location")

    members(:ram).profile_answers.create!(profile_question: location_question, location: locations(:ukraine))
    members(:f_student).profile_answers.create!(profile_question: location_question, location: locations(:st_mary))

    current_user_is users(:f_admin)
    get :demographic_report, params: { filters: {map_filter: "true", countries: ["United Kingdom", "Ukraine"]}}
    assert_response :success
    assert assigns(:all_users_locations).collect(&:full_address).include?(locations(:ukraine).full_address)
    assert assigns(:all_users_locations).collect(&:full_address).include?(locations(:st_mary).full_address)
    assert_equal_hash({map_filter: "true", countries: ["United Kingdom", "Ukraine"]}, assigns(:filter_params))
    assert_equal 1, assigns(:filters_count)
    assert_equal_unordered [[locations(:ukraine).full_address, locations(:ukraine).lat, locations(:ukraine).lng], [locations(:st_mary).full_address, locations(:st_mary).lat, locations(:st_mary).lng]], assigns(:locations)

    get :demographic_report, params: { filters: {map_filter: "true", role: RoleConstants::STUDENT_NAME, countries: ["United Kingdom", "Ukraine"]}}
    assert_equal_hash({map_filter: "true", role: RoleConstants::STUDENT_NAME, countries: ["United Kingdom", "Ukraine"]}, assigns(:filter_params))
    assert_equal 2, assigns(:filters_count)
    assert_equal [[locations(:st_mary).full_address, locations(:st_mary).lat, locations(:st_mary).lng]], assigns(:locations)
  end

  def test_blank_demographic_report_for_portal_no_location_question
    program = programs(:primary_portal)
    current_user_is users(:portal_admin)
    programs(:org_nch).profile_questions.where(question_type: ProfileQuestion::Type::LOCATION).destroy_all
    get :demographic_report
    assert_response :success
    assert_page_title "Geographic Distribution Report"
    assert_nil assigns(:roles)
    assert_nil assigns(:most_users_country)
    assert_match /This report is not available as there are no locations recorded for the users of this program. Please update the profile design to include a profile field of type .*Location/, @response.body
  end

  def test_blank_demographic_report_for_portal_no_answers_provided
    program = programs(:primary_portal)
    current_user_is users(:portal_admin)
    location_question = programs(:org_nch).profile_questions.find_by(question_text: "Location")
    location_question.profile_answers.destroy_all
    get :demographic_report
    assert_response :success
    assert_page_title "Geographic Distribution Report"
    assert_equal [RoleConstants::EMPLOYEE_NAME], assigns(:roles)
    assert_nil assigns(:most_users_country)
    assert_match /This report is not available as there are no locations recorded for the users of this program/, @response.body
    assert_no_match(/Please update the profile design to include a profile field of type .*Location/, @response.body)
  end

  def test_demographic_report_for_portal
    program = programs(:primary_portal)
    current_user_is users(:portal_admin)

    location_question = program.organization.profile_questions.find_by(question_text: "Location")
    employee_role = program.find_role(RoleConstants::EMPLOYEE_NAME)
    employee_member_ids = RoleReference.where(role_id: employee_role.id, ref_obj_type: User.name).collect(&:ref_obj).map(&:member_id)
    employee_locations = location_question.profile_answers.where(ref_obj_type: Member.name, ref_obj_id: employee_member_ids).collect(&:location)

    get :demographic_report, params: { filter: RoleConstants::EMPLOYEE_NAME, sort_param: ReportViewColumn::DemographicReport::Key::EMPLOYEES_COUNT}
    assert_response :success
    assert_page_title "Geographic Distribution Report"
    assert_equal [RoleConstants::EMPLOYEE_NAME], assigns(:roles)
    assert assigns(:all_users_locations).collect(&:full_address).include?(locations(:chennai).full_address)
    assert_equal employee_locations.collect(&:full_address), assigns(:role_locations)[RoleConstants::EMPLOYEE_NAME].collect(&:full_address)
    assert_equal program.report_view_columns.for_demographic_report.to_a.reject! {|column| column.column_key == ReportViewColumn::DemographicReport::Key::ALL_USERS_COUNT }.to_a, assigns(:report_view_columns)
    assert_equal ReportViewColumn::DemographicReport::Key::EMPLOYEES_COUNT, assigns(:sort_param)
    assert_equal "asc", assigns(:sort_order)
    assert_equal_hash({}, assigns(:filter_params))
    assert_equal 0, assigns(:filters_count)
  end

  def test_management_report_success
    program = programs(:albers)
    admin_user = users(:f_admin)
    current_user_is admin_user
    get :management_report
    assert assigns(:show_pendo_launcher_in_all_devices)
    assert_nil assigns(:my_all_connections_count)
  end

  def test_management_report_success_with_mentoring_role
    program = programs(:albers)
    current_user_is users(:f_admin)
    role = users(:f_admin).roles.first
    role.for_mentoring = true
    role.save!
    get :management_report
    assert_equal 0, assigns(:my_all_connections_count)
  end

  def test_management_report_async_loading_enrollment_success
    admin_user = users(:f_admin)
    current_user_is admin_user
    get :management_report_async_loading, xhr: true, params: { section: ReportsController::ManagementReportConstants::AsyncLoadingSections::ENROLLMENT}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENROLLMENT][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENROLLMENT][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range(nil, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::LAST_30_DAYS, assigns(:date_range_preset)

    get :management_report_async_loading, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENROLLMENT}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENROLLMENT][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENROLLMENT][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range(nil, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::LAST_30_DAYS, assigns(:date_range_preset)
  end

  def test_management_report_async_loading_matching_success
    admin_user = users(:f_admin)
    current_user_is admin_user
    get :management_report_async_loading, xhr: true, params: { section: ReportsController::ManagementReportConstants::AsyncLoadingSections::MATCHING}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::MATCHING][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::MATCHING][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range(nil, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::LAST_30_DAYS, assigns(:date_range_preset)
  end

  def test_management_report_async_loading_groups_success
    admin_user = users(:f_admin)
    current_user_is admin_user
    get :management_report_async_loading, xhr: true, params: { section: ReportsController::ManagementReportConstants::AsyncLoadingSections::ENGAGEMENTS}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENGAGEMENTS][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENGAGEMENTS][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range(nil, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::LAST_30_DAYS, assigns(:date_range_preset)

    get :management_report_async_loading, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENGAGEMENTS, filters: {date_range: "12/01/2017 - 01/30/2018", date_range_preset: DateRangePresets::CUSTOM}}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENGAGEMENTS][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::ENGAGEMENTS][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range({date_range: "12/01/2017 - 01/30/2018"}, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::CUSTOM, assigns(:date_range_preset)
  end

  def test_management_report_async_loading_groups_activity_success
    admin_user = users(:f_admin)
    current_user_is admin_user
    get :management_report_async_loading, xhr: true, params: { section: ReportsController::ManagementReportConstants::AsyncLoadingSections::GROUPS_ACTIVITY}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::GROUPS_ACTIVITY][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::GROUPS_ACTIVITY][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range(nil, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::LAST_30_DAYS, assigns(:date_range_preset)
  end

  def test_management_report_async_loading_community_success
    admin_user = users(:f_admin)
    current_user_is admin_user
    get :management_report_async_loading, xhr: true, params: { section: ReportsController::ManagementReportConstants::AsyncLoadingSections::COMMUNITY}
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::COMMUNITY][:partial], assigns(:partial)
    assert_equal ReportsController::ManagementReportConstants::AsyncLoadingSections::MAPPING[ReportsController::ManagementReportConstants::AsyncLoadingSections::COMMUNITY][:element_id], assigns(:element_id)
    assert assigns(:skip_hiding_loader)
    start_date, end_date = ReportsFilterService.get_report_date_range(nil, ReportsController::ManagementReportConstants::DEFAULT_LIMIT.ago)
    start_time = start_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = end_date.end_of_day.in_time_zone(Time.zone)
    assert_equal (start_time..end_time), assigns(:date_range)
    assert_equal DateRangePresets::LAST_30_DAYS, assigns(:date_range_preset)
  end

  def test_filter_management_report_success_with_param_filters_tile
    current_user_is users(:f_admin)
    role = users(:f_admin).roles.first
    role.for_mentoring = true
    role.save!
    post :filter_management_report, xhr: true, params: { filters: {date_range_preset: DateRangePresets::CUSTOM, tile: DashboardReportSubSection::Tile::ENGAGEMENTS, date_range: "12/14/2013 - 03/14/2014" }}
    start_time = Date.strptime("12/14/2013".strip, MeetingsHelper::DateRangeFormat.call).to_date.beginning_of_day.in_time_zone(Time.zone)
    end_time = Date.strptime("03/14/2014".strip, MeetingsHelper::DateRangeFormat.call).to_date.end_of_day.in_time_zone(Time.zone)
    assert_equal DateRangePresets::CUSTOM, assigns(:date_range_preset)
    assert_equal DashboardReportSubSection::Tile::ENGAGEMENTS, assigns(:tile)
    assert_equal start_time..end_time, assigns(:date_range)
  end

  private

  def create_activity_data
    @program = programs(:albers)
    @program.enable_feature(FeatureName::PROGRAM_GOALS)
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @model = @program.default_mentoring_model
    @model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    goal_template = @model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    @group = create_group
    connection_goals = @group.mentoring_model_goals.where(:mentoring_model_goal_template_id => goal_template.id)
    @goal_1 = connection_goals.first
    @act1 = create_mentoring_model_goal_activity(@goal_1, {progress_value: nil})
    @act2 = create_mentoring_model_goal_activity(@goal_1, {progress_value: 45})
    @act3 = create_mentoring_model_goal_activity(@goal_1, {progress_value: 78})
  end

  def setup_program_for_reports(program)
    program.enable_feature(FeatureName::EXECUTIVE_SUMMARY_REPORT)
    program.enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program.enable_feature(FeatureName::CALENDAR)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.enable_feature(FeatureName::CONTRACT_MANAGEMENT)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
  end
end
