require_relative './../test_helper.rb'

class OutcomesReportControllerTest < ActionController::TestCase

  def test_user_outcomes_report_non_admin
    current_user_is users(:f_mentor)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :user_outcomes_report, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_user_outcomes_report_feature_disabled
    current_user_is users(:f_admin)
    disable_feature(programs(:albers), FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :user_outcomes_report, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_meeting_outcomes_report_non_admin
    current_user_is users(:f_mentor)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :meeting_outcomes_report, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_meeting_outcomes_report_permission_denied
    current_user_is users(:f_admin)
    disable_feature(programs(:albers), FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :meeting_outcomes_report, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_meeting_outcomes_report_success
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    get :meeting_outcomes_report, params: { date_range: date_range}
    assert_response :success
    assert assigns(:meeting_outcomes_report).present?
  end

  def test_user_outcomes_report_success
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    get :user_outcomes_report, params: { date_range: date_range }
    assert_response :success
    assert assigns(:user_outcomes_report).present?
    assert_blank assigns(:user_outcomes_report).rolewiseSummary
  end

  def test_user_outcomes_report_with_user_state
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    get :user_outcomes_report, params: { date_range: date_range, data_side: OutcomesReportUtils::DataType::NON_GRAPH_DATA, fetch_user_state: true, include_rolewise_summary: true }
    assert_response :success
    assert assigns(:user_outcomes_report).userState.present?
    assert assigns(:user_outcomes_report).rolewiseSummary[0][:new_roles].present?
    assert assigns(:user_outcomes_report).rolewiseSummary[0][:suspended_roles].present?
  end

  def test_connection_outcomes_report_non_admin
    current_user_is users(:f_mentor)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :connection_outcomes_report, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_positive_outcomes_options_popup
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    (program.surveys - program.surveys.where(name: ["Introduce yourself", "Mentoring Connection Activity Feedback"])).each {|survey| survey.destroy}
    program.reload
    get :positive_outcomes_options_popup, xhr: true
    assert_response :success

    q1 = program.surveys[0].survey_questions.where(question_text: "Where are you from?")[0]
    q2 = program.surveys[1].survey_questions.where(question_text: "How do you communicate with the members of this mentoring connection?")[0]
    q3 = program.surveys[1].survey_questions.where(question_text: "How effective is this mentoring connection?")[0]
    choices_1 = q1.question_choices.index_by(&:text)
    choices_2 = q2.question_choices.index_by(&:text)
    choices_3 = q3.question_choices.index_by(&:text)
    assert_equal [{text: program.surveys[0].name,
      children: [{id: q1.id, text: "Where are you from?", choices: [{id: choices_1["Smallville"].id, text: "Smallville"}, {id: choices_1["Krypton"].id, text: "Krypton"}, {id: choices_1["Earth"].id, text: "Earth"}], selected: []}]},
     {text: "Mentoring Connection Activity Feedback",
      children: [{id: q2.id, text: "How do you communicate with the members of this mentoring connection?", choices: [{id: choices_2["Mentoring Area"].id, text: "Mentoring Area"}, {id: choices_2["Chat/IM"].id, text: "Chat/IM"}, {id: choices_2["Emails"].id, text: "Emails"}, {id: choices_2["Phone"].id, text: "Phone"}, {id: choices_2["Face to face meetings"].id, text: "Face to face meetings"}, {id: choices_2["Other"].id, text: "Other"}], selected: []},
                 {id: q3.id, text: "How effective is this mentoring connection?", choices: [{id: choices_3["Very good"].id, text: "Very good"}, {id: choices_3["Good"].id, text: "Good"}, {id: choices_3["Satisfactory"].id, text: "Satisfactory"}, {id: choices_3["Poor"].id, text: "Poor"}, {id: choices_3["Very poor"].id, text: "Very poor"}], selected: []}]}], assigns(:questions_data)
  end

  def test_positive_outcomes_options_popup_both_ongoing_one_time_mentoring_enabled
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    (program.surveys - program.surveys.where(name: ["Introduce yourself", "Mentoring Connection Activity Feedback"])).each {|survey| survey.destroy}
    program.reload

    assert program.calendar_enabled?
    assert program.ongoing_mentoring_enabled?

    get :positive_outcomes_options_popup, xhr: true
    assert_response :success

    q1 = program.surveys[0].survey_questions.where(question_text: "Where are you from?")[0]
    q2 = program.surveys[1].survey_questions.where(question_text: "How do you communicate with the members of this mentoring connection?")[0]
    q3 = program.surveys[1].survey_questions.where(question_text: "How effective is this mentoring connection?")[0]
    choices_1 = q1.question_choices.index_by(&:text)
    choices_2 = q2.question_choices.index_by(&:text)
    choices_3 = q3.question_choices.index_by(&:text)
    assert_equal [{text: program.surveys[0].name,
                  children: [{id: q1.id, text: "Where are you from?", choices: [{id: choices_1["Smallville"].id, text: "Smallville"}, {id: choices_1["Krypton"].id, text: "Krypton"}, {id: choices_1["Earth"].id, text: "Earth"}], selected: []}]},
    {text: program.surveys[1].name,
    children: [{id: q2.id, text: "How do you communicate with the members of this mentoring connection?", choices: [{id: choices_2["Mentoring Area"].id, text: "Mentoring Area"}, {id: choices_2["Chat/IM"].id, text: "Chat/IM"}, {id: choices_2["Emails"].id, text: "Emails"}, {id: choices_2["Phone"].id, text: "Phone"}, {id: choices_2["Face to face meetings"].id, text: "Face to face meetings"}, {id: choices_2["Other"].id, text: "Other"}], selected: []},
      {id: q3.id, text: "How effective is this mentoring connection?", choices: [{id: choices_3["Very good"].id, text: "Very good"}, {id: choices_3["Good"].id, text: "Good"}, {id: choices_3["Satisfactory"].id, text: "Satisfactory"}, {id: choices_3["Poor"].id, text: "Poor"}, {id: choices_3["Very poor"].id, text: "Very poor"}], selected: []}]}], assigns(:questions_data)
  end

  def test_positive_outcomes_options_popup_with_matrix_questions
    program = programs(:albers)
    EngagementSurvey.create!(
        :program => program,
        :name => "New Survey",
        :edit_mode => Survey::EditMode::MULTIEDIT)
    survey = Survey.last
    mq = create_matrix_survey_question({survey: survey})
    rq0,rq1,rq2 = mq.rating_questions
    choices_hash = mq.question_choices.index_by(&:text)
    rq0.update_attributes(positive_outcome_options: choices_hash["Very Good"].id.to_s)

    program.surveys.each{|s| s.delete unless s.id == survey.id}

    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)

    get :positive_outcomes_options_popup, xhr: true
    assert_response :success
    choices = [{id: choices_hash["Very Good"].id, text: "Very Good"}, {id: choices_hash["Good"].id, text: "Good"}, {id: choices_hash["Average"].id, text: "Average"}, {id: choices_hash["Poor"].id, text: "Poor"}]
    assert_equal [{text: survey.name, children: [{id: rq0.id, text: rq0.question_text_for_display, choices: choices, selected: [choices_hash["Very Good"].id.to_s]},
      {id: rq1.id, text: rq1.question_text_for_display, choices: choices, selected: []},
      {id: rq2.id, text: rq2.question_text_for_display, choices: choices, selected: []}]}], assigns(:questions_data)
  end

  def test_get_filtered_users_permission_denied
    current_user_is users(:f_student)

    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    assert_permission_denied do
      post :get_filtered_users, xhr: true, params: { date_range: date_range}
    end
  end

  def test_get_filtered_users_success
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    current_user_is users(:f_admin)

    user_ids = [users(:f_student).id, users(:f_mentor).id]
    member_ids = [users(:f_student).member_id, users(:f_mentor).member_id]
    group_ids = [groups(:mygroup).id]

    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    Survey::Report.stubs(:remove_incomplete_report_filters).never
    ReportsFilterService.stubs(:dynamic_profile_filter_params).never
    UserAndMemberFilterService.stubs(:apply_profile_filtering).never
    post :get_filtered_users, xhr: true, params: { date_range: date_range}
    assert_response :success
    assert_nil assigns(:cache_key)
    assert_equal 0, assigns(:filters_count)

    Survey::Report.stubs(:remove_incomplete_report_filters).with("profile question filters").returns("complete profile question filters")
    ReportsFilterService.stubs(:dynamic_profile_filter_params).with("complete profile question filters").returns("processed profile filter params")
    UserAndMemberFilterService.stubs(:apply_profile_filtering).with(programs(:albers).users.pluck(:id), "processed profile filter params", {is_program_view: true, program_id: programs(:albers).id, for_report_filter: true}).returns(user_ids)
    post :get_filtered_users, xhr: true, params: { date_range: date_range, report: {profile_questions: "profile question filters"}}
    assert_response :success
    cache_key = assigns(:cache_key)
    assert_equal 1, assigns(:filters_count)
    assert_equal_unordered user_ids, Rails.cache.read(cache_key+"_users")
    assert_equal_unordered member_ids, Rails.cache.read(cache_key+"_members")
    assert_equal_unordered group_ids, Rails.cache.read(cache_key+"_groups")
  end

  def test_detailed_users_outcomes_report_data
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    options = {:date_range => date_range, :page => 1, :page_size => 2, :sort_order => "asc", :fetch_user_data => true}
    get :detailed_users_outcomes_report_data, params: options
    assert_response :success
    assert assigns(:detailed_outcomes_report).userData.present?
  end

  def test_positive_outcomes_options_popup_for_flash_mentoring
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    survey = program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME).survey_questions.destroy_all
    q1 = survey.survey_questions.where(question_text: "How was your overall meeting experience?")[0]
    q2 = survey.survey_questions_with_matrix_rating_questions.where(question_text: "What was discussed in your meeting?")[0]
    choices_1 = q1.question_choices.index_by(&:text)
    choices_2 = q2.question_choices.index_by(&:text)
    q1.update_attribute(:positive_outcome_options, "#{choices_1['Extremely useful'].id},#{choices_1['Very useful'].id}")
    q2.update_attribute(:positive_outcome_options, "#{choices_2['Organizational navigation'].id}")
    (survey.survey_questions.select(&:choice_based?) - [q1, q2]).each {|q| q.destroy}

    current_user_is users(:f_admin)
    get :positive_outcomes_options_popup, xhr: true
    assert_response :success
    assert_equal [{text: "Meeting Feedback Survey For Mentors", children: []},
      {text: survey.name, children: [{id: q1.id, text: q1.question_text, choices: [{id: choices_1["Extremely useful"].id, text: "Extremely useful"}, {id: choices_1["Very useful"].id, text: "Very useful"}, {id: choices_1["Moderately useful"].id, text: "Moderately useful"}, {id: choices_1["Slightly useful"].id, text: "Slightly useful"}, {id: choices_1["Not at all useful"].id, text: "Not at all useful"}], selected: q1.positive_choices},
                                    {id: q2.id, text: q2.question_text, choices: [{id: choices_2["Organizational navigation"].id, text: "Organizational navigation"}, {id: choices_2["Knowledge sharing"].id, text: "Knowledge sharing"}, {id: choices_2["Career planning"].id, text: "Career planning"}, {id: choices_2["Role transitions or opportunities"].id, text: "Role transitions or opportunities"}, {id: choices_2["Informational interview"].id, text: "Informational interview"}, {id: choices_2["Situational guidance"].id, text: "Situational guidance"}], selected: q2.positive_choices}]}], assigns(:questions_data)
  end

  def test_update_positive_outcomes_options
    global_reports_path_url = global_reports_path
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    (program.surveys - program.surveys.where(name: ["Introduce yourself", "Mentoring Connection Activity Feedback"])).each {|survey| survey.destroy}
    program.reload
    q1 = program.surveys[0].survey_questions.where(question_text: "Where are you from?")[0]
    q2 = program.surveys[1].survey_questions.where(question_text: "How do you communicate with the members of this mentoring connection?")[0]
    q3 = program.surveys[1].survey_questions.where(question_text: "How effective is this mentoring connection?")[0]
    choices_1 = q1.question_choices.index_by(&:text)
    choices_2 = q2.question_choices.index_by(&:text)
    choices_3 = q3.question_choices.index_by(&:text)
    q3.update_attribute(:positive_outcome_options, "asd")
    post :update_positive_outcomes_options, params: {"data"=>[
      {"id"=>q1.id, "name"=>"Where are you from?", "choices"=>[{id: choices_1["Smallville"].id, text: "Smallville"}, {id: choices_1["Krypton"].id, text: "Krypton"}, {id: choices_1["Earth"].id, text: "Earth"}], "selected"=>[choices_1["Earth"].id.to_s], "surveyName"=>"Introduce yourself"},
      {"id"=>q2.id, "name"=>"How do you communicate with the members of this mentoring connection?", "choices"=>[{id: choices_2["Mentoring Area"].id, text: "Mentoring Area"}, {id: choices_2["Chat/IM"].id, text: "Chat/IM"}, {id: choices_2["Emails"].id, text: "Emails"}, {id: choices_2["Phone"].id, text: "Phone"}, {id: choices_2["Face to face meetings"].id, text: "Face to face meetings"}, {id: choices_2["Other"].id, text: "Other"}], "selected"=>[choices_2["Emails"].id.to_s, choices_2["Phone"].id.to_s], "surveyName"=>"Mentoring Connection Activity Feedback"},
      {"id"=>q3.id, "name"=>"How effective is this mentoring connection?", "choices"=>[{id: choices_3["Very good"].id, text: "Very good"}, {id: choices_3["Good"].id, text: "Good"}, {id: choices_3["Satisfactory"].id, text: "Satisfactory"}, {id: choices_3["Poor"].id, text: "Poor"}, {id: choices_3["Very poor"].id, text: "Very poor"}], "selected"=>[], "surveyName"=>"Mentoring Connection Activity Feedback"}
    ], return_to_global_reports: true}
    assert_redirected_to global_reports_path_url
    assert_equal "#{choices_1['Earth'].id}", program.surveys[0].survey_questions.where(question_text: "Where are you from?")[0].positive_outcome_options
    assert_equal "#{choices_2['Emails'].id},#{choices_2['Phone'].id}", program.surveys[1].survey_questions.where(question_text: "How do you communicate with the members of this mentoring connection?")[0].positive_outcome_options
    assert_nil program.surveys[1].survey_questions.where(question_text: "How effective is this mentoring connection?")[0].positive_outcome_options
  end

  def test_update_positive_outcomes_options_for_matrix_question
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    survey = surveys(:two)
    mq = create_matrix_survey_question({survey: survey})
    choices_hash = mq.question_choices.index_by(&:text)
    rq0 = mq.rating_questions[0]
    rq0.update_attributes(:positive_outcome_options => choices_hash["Good"].id.to_s)
    rq1 = mq.rating_questions[1]
    rq1.update_attributes(:positive_outcome_options => "#{choices_hash['Very Good'].id}, #{choices_hash['Good'].id}")
    rq2 = mq.rating_questions[2]

    post :update_positive_outcomes_options, params: {"data"=>[
      {"id"=>rq1.id, "name"=>rq1.question_text, "choices"=>['Not needed for the test'], "selected"=>["#{choices_hash['Very Good'].id}"], "surveyName"=> survey.name},
      {"id"=>rq2.id, "name"=>rq2.question_text, "choices"=>['Not needed for the test'], "selected"=>["#{choices_hash['Poor'].id}"], "surveyName"=> survey.name}
    ]}

    assert_nil rq0.reload.positive_outcome_options
    assert_equal "#{choices_hash['Very Good'].id}", rq1.reload.positive_outcome_options
    assert_equal "#{choices_hash['Poor'].id}", rq2.reload.positive_outcome_options
  end

  def test_update_positive_outcomes_options_for_flash_mentoring
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    assert program.calendar_enabled?
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    survey = program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    q1 = survey.survey_questions.where(question_text: "How was your overall meeting experience?")[0]
    q2 = survey.survey_questions_with_matrix_rating_questions.where(question_text: "Ease of finding a mentor")[0]
    q1.update_attribute(:positive_outcome_options, "asd")
    choices_1 = q1.question_choices.index_by(&:text)
    choices_2 = q2.matrix_question.question_choices.index_by(&:text)
    post :update_positive_outcomes_options, params: {"data"=>[
      {"id"=>q1.id, "name"=>q1.question_text, "choices"=>q1.values_and_choices.map{|qc_id, qc_text| {id: qc_id, text: qc_text}}, "selected"=>[choices_1["Extremely useful"].id.to_s, choices_1["Very useful"].id.to_s], "surveyName"=>"Meeting Feedback Survey"},
      {"id"=>q2.id, "name"=>q2.question_text, "choices"=>q2.values_and_choices.map{|qc_id, qc_text| {id: qc_id, text: qc_text}}, "selected"=>[choices_2["Very Easy"].id.to_s], "surveyName"=>"Meeting Feedback Survey"}
    ]}
    assert_equal "#{choices_1['Extremely useful'].id},#{choices_1['Very useful'].id}", q1.reload.positive_outcome_options
    assert_equal "#{choices_2['Very Easy'].id}", q2.reload.positive_outcome_options
  end

  def test_filter_users_on_profile_questions
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)

    profile_filter_service = UserProfileFilterService.new(program, nil, program.roles.for_mentoring.pluck(:name))
    profile_question = profile_filter_service.non_profile_filterable_questions.select{|a| a.question_text == "Gender"}.first
    program.users.first.member.profile_answers.create!(profile_question_id: profile_question.id, answer_value: {answer_text: ["Male"], question: profile_question})

    get :filter_users_on_profile_questions, params: { sf: {pq: {profile_question.id.to_s => [profile_question.question_choices.find_by(text: "Male").id]}}}
    assert_response :success
    response_hash = JSON.parse(@response.body)

    assert_equal "Gender", response_hash["my_filters"].first["label"]
    assert_equal [program.users.first.id], Rails.cache.read(response_hash["cache_key"]+"_users")
    assert_false response_hash["location"]["invalid_location_filter"]
  end

  def test_filter_users_on_profile_questions_with_incorrect_location
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)

    profile_filter_service = UserProfileFilterService.new(program, nil, program.roles.for_mentoring.pluck(:name))
    program.organization.profile_questions.where(:question_type => ProfileQuestion::Type::LOCATION).first.profile_answers
    profile_question = profile_filter_service.profile_filterable_questions.select{|a| a.question_type == ProfileQuestion::Type::LOCATION}.first

    Location.any_instance.stubs(:geocode).raises(Geokit::Geocoders::GeocodeError)
    get :filter_users_on_profile_questions, params: { sf: {location: {profile_question.id.to_s => {name: "Incorrect Name"}}}}
    assert_response :success
    response_hash = JSON.parse(@response.body)
    assert_equal "Location", response_hash["my_filters"].first["label"]
    assert_false assigns(:pivot_location)
    assert_equal response_hash["location"]["error_message"], "feature.user.content.unknown_location".translate
  end

  def test_filter_users_on_profile_questions_without_filters
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)

    get :filter_users_on_profile_questions
    assert_response :success
    response_hash = JSON.parse(@response.body)
    assert_nil response_hash["location"]["cache_key"]
  end

  def test_connection_outcomes_report_feature_disabled
    program = programs(:albers)
    current_user_is users(:f_admin)
    disable_feature(programs(:albers), FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :connection_outcomes_report, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_connection_outcomes_report_success
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    get :connection_outcomes_report, params: { date_range: date_range}
    assert_response :success
    assert assigns(:connection_outcomes_report).present?
  end

  def test_detailed_connection_outcomes_report_group_data_with_feature_disabled
    program = programs(:albers)
    current_user_is users(:f_admin)
    disable_feature(programs(:albers), FeatureName::PROGRAM_OUTCOMES_REPORT)
    assert_permission_denied do
      get :detailed_connection_outcomes_report_group_data, params: { date_range: "April 19, 2014 - September 03, 2014"}
    end
  end

  def test_detailed_connection_outcomes_report_group_data
    program = programs(:albers)
    time_now = Time.now.utc
    end_time = time_now + 1.day
    start_time = time_now - 3.day

    Group.stubs(:get_ids_of_groups_active_between).with(program, start_time.utc.beginning_of_day, end_time.utc.beginning_of_day).once.returns(program.groups.where(status: Group::Status::ACTIVE_CRITERIA).pluck(:id))
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    end_date = end_time.strftime("%b %d, %Y")
    start_date = start_time.strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    options = {date_range: date_range, page_size: 2, page_number: 1, sort_field: "name", sort_type: "asc"}
    get :detailed_connection_outcomes_report_group_data, params: options
    assert_response :success
    assert assigns(:detailed_outcomes_report).groupsData.present?
    assert assigns(:detailed_outcomes_report).groupsTableHash.present?
    assert assigns(:detailed_outcomes_report).groupsTableCacheKey.present?
    assert JSON.parse(@response.body)["pagination_html"].present?
  end

  def test_detailed_connection_outcomes_report_group_data_with_status_filter
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    options = {date_range: date_range, page_size: 10000, page_number: 1, sort_field: "name", sort_type: "asc", status_filter: nil}

    get :detailed_connection_outcomes_report_group_data, params: options
    assert_response :success
    assert_false assigns(:detailed_outcomes_report).groupsData.nil?
    count_without_filter = assigns(:detailed_outcomes_report).groupsData.size
    groups_without_status_filter = assigns(:detailed_outcomes_report).groups
    active_groups = assigns(:detailed_outcomes_report).groups.select{|group| group.status == Group::Status::ACTIVE || group.status == Group::Status::INACTIVE}

    options[:status_filter] = "incorrect_value"
    get :detailed_connection_outcomes_report_group_data, params: options
    assert_response :success
    assert_false assigns(:detailed_outcomes_report).groupsData.nil?
    count_with_incorrect_filter = assigns(:detailed_outcomes_report).groupsData.size
    assert_equal count_without_filter, count_with_incorrect_filter

    options[:status_filter] = DetailedReports::GroupsFilterAndSortService::CurrentStatus::ONGOING
    get :detailed_connection_outcomes_report_group_data, params: options
    assert_response :success
    assert_false assigns(:detailed_outcomes_report).groupsData.nil?
    assert_equal_unordered active_groups.collect(&:id), assigns(:detailed_outcomes_report).groups.collect(&:id)
  end


  def test_detailed_connection_outcomes_report_user_data
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"
    options = {date_range: date_range, page_size: 2, page_number: 1}

    user_ids = program.users.joins('JOIN members ON users.member_id = members.id').order('members.first_name asc').first(5).collect(&:id)
    User.expects(:get_ids_of_connected_users_active_between).once.returns(user_ids)

    get :detailed_connection_outcomes_report_user_data, params: options
    assert_response :success
    assert assigns(:detailed_outcomes_report).userData.present?
    assert assigns(:detailed_outcomes_report).usersTableHash.present?
    assert assigns(:detailed_outcomes_report).usersTableCacheKey.present?
    assert JSON.parse(@response.body)["pagination_html"].present?
    assert_equal user_ids.first(2), assigns(:detailed_outcomes_report).users.collect(&:id)
  end

  def test_test_detailed_connection_outcomes_report_non_table_data_with_nil_cache_key
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    options = {'tab' => 'tab_string', 'section' => 'section_string', 'cache_key' => nil}
    ConnectionDetailedReport.expects(:new).with(program, date_range, options).once.returns('something')
    get :detailed_connection_outcomes_report_non_table_data, params: { date_range: date_range, tab: 'tab_string', section: 'section_string'}
    assert_response :success
    assert_equal 'something', assigns(:connection_detailed_outcomes_data)
  end

  def test_test_detailed_connection_outcomes_report_non_table_data_with_cache_key
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    cache_key = "123"
    options = {'tab' => 'tab_string', 'section' => 'section_string', 'cache_key' => cache_key}
    ConnectionDetailedReport.expects(:new).with(program, date_range, options).once.returns('something')
    get :detailed_connection_outcomes_report_non_table_data, params: { date_range: date_range, user_ids_cache_key: cache_key, tab: 'tab_string', section: 'section_string'}
    assert_response :success
    assert_equal 'something', assigns(:connection_detailed_outcomes_data)
  end

  def test_test_detailed_connection_outcomes_report_non_table_data_with_role
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    options = {'tab' => 'tab_string', 'section' => 'section_string', 'cache_key' => '', 'role' => 7}
    ConnectionDetailedReport.expects(:new).with(program, date_range, options).once.returns('something')
    get :detailed_connection_outcomes_report_non_table_data, params: { date_range: date_range, user_ids_cache_key: '', tab: 'tab_string', section: 'section_string', for_role: '7'}
    assert_response :success
    assert_equal 'something', assigns(:connection_detailed_outcomes_data)
  end

  def test_detailed_connection_outcomes_report_non_table_data_with_all_users_role
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    options = {'tab' => 'tab_string', 'section' => 'section_string', 'cache_key' => ''}
    ConnectionDetailedReport.expects(:new).with(program, date_range, options).once.returns('something')
    get :detailed_connection_outcomes_report_non_table_data, params: { date_range: date_range, user_ids_cache_key: '', tab: 'tab_string', section: 'section_string', for_role: "#{OutcomesReportUtils::RoleData::ALL_USERS}"}
    assert_response :success
    assert_equal 'something', assigns(:connection_detailed_outcomes_data)
  end

  def test_test_detailed_connection_outcomes_report_non_table_data_with_empty_cache_key
    program = programs(:albers)
    current_user_is users(:f_admin)
    programs(:org_primary).enable_feature(FeatureName::PROGRAM_OUTCOMES_REPORT)
    time_now = Time.now.utc
    end_date = (time_now + 1.day).strftime("%b %d, %Y")
    start_date = (time_now - 3.day).strftime("%b %d, %Y")
    date_range = "#{start_date} - #{end_date}"

    options = {'tab' => 'tab_string', 'section' => 'section_string', 'cache_key' => ''}
    ConnectionDetailedReport.expects(:new).with(program, date_range, options).once.returns('something')
    get :detailed_connection_outcomes_report_non_table_data, params: { date_range: date_range, user_ids_cache_key: '', tab: 'tab_string', section: 'section_string'}
    assert_response :success
    assert_equal 'something', assigns(:connection_detailed_outcomes_data)
  end
end
