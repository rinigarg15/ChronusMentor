require_relative "./../test_helper.rb"

class DashboardReportSubSectionsControllerTest < ActionController::TestCase
  def test_tile_settings_permission_denied
    current_user_is :f_student

    assert_permission_denied do
      get :tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENROLLMENT}
    end
  end

  def test_tile_settings_success
    current_user_is :f_admin
    get :tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENROLLMENT}

    assert_response :success
    assert_equal DashboardReportSubSection::Tile::ENROLLMENT, assigns(:tile)
    assert_nil assigns(:date_range)
    assert_nil assigns(:date_range_preset)
  end

  def test_tile_settings_groups_tile
    program = programs(:albers)
    program.surveys.of_engagement_type.destroy_all
    survey = create_engagement_survey
    q2 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})
    choices_hash = q2.question_choices.index_by(&:text)
    q2.update_attributes!(positive_outcome_options_management_report: choices_hash["get"].id.to_s)

    current_user_is :f_admin
    get :tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENGAGEMENTS, date_range: "date_range", date_range_preset: "date_range_preset"}

    assert_response :success
    assert_equal DashboardReportSubSection::Tile::ENGAGEMENTS, assigns(:tile)
    assert_equal "date_range", assigns(:date_range)
    assert_equal "date_range_preset", assigns(:date_range_preset)
    assert_equal [{:text=>"Some survey", :children=>[{:id=>q2.id, :text=>"Whats your age?", :choices=>[{:id=>choices_hash["get"].id, :text=>"get"}, {:id=>choices_hash["set"].id, :text=>"set"}, {:id=>choices_hash["go"].id, :text=>"go"}], :selected=>[choices_hash["get"].id.to_s]}]}],  assigns(:questions_data)
  end

  def test_update_tile_settings_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      post :update_tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENROLLMENT, dashboard_reports: [DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE]}
    end
  end

  def test_update_tile_settings_success
    current_user_is :f_admin

    Program.any_instance.stubs(:enable_dashboard_report!).with(DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE, true, nil)
    Program.any_instance.stubs(:enable_dashboard_report!).with(DashboardReportSubSection::Type::Enrollment::APPLICATIONS_STATUS, false, nil)
    Program.any_instance.stubs(:enable_dashboard_report!).with(DashboardReportSubSection::Type::Enrollment::PUBLISHED_PROFILES, false, nil)
    post :update_tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENROLLMENT, dashboard_reports: [DashboardReportSubSection::Type::Enrollment::INVITATIONS_ACCEPTANCE_RATE]}
    assert_redirected_to management_report_async_loading_path(remote: true, tile: DashboardReportSubSection::Tile::ENROLLMENT, filters: {})
    assert_equal DashboardReportSubSection::Tile::ENROLLMENT, assigns(:tile)

    Program.any_instance.stubs(:enable_dashboard_report!).with(DashboardReportSubSection::Type::Matching::CONNECTED_USERS, true, "something")
    Program.any_instance.stubs(:enable_dashboard_report!).with(DashboardReportSubSection::Type::Matching::MENTOR_REQUESTS, false, nil)
    post :update_tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::MATCHING, dashboard_reports: [DashboardReportSubSection::Type::Matching::CONNECTED_USERS], report_sub_settings: {DashboardReportSubSection::Type::Matching::CONNECTED_USERS => "something"}}
    assert_redirected_to management_report_async_loading_path(remote: true, tile: DashboardReportSubSection::Tile::MATCHING, filters: {})
    assert_equal DashboardReportSubSection::Tile::MATCHING, assigns(:tile)
  end

  def test_update_groups_tile_settings_success
    program = programs(:albers)
    program.surveys.of_engagement_type.destroy_all
    survey = create_engagement_survey
    q1 = create_survey_question(
      {:question_type => CommonQuestion::Type::SINGLE_CHOICE,
        :question_choices => "get,set,go", :survey => survey})
    choices_hash = q1.question_choices.index_by(&:text)
    current_user_is :f_admin

    post :update_tile_settings, xhr: true, params: { tile: DashboardReportSubSection::Tile::ENGAGEMENTS, positive_outcomes_options_array: {"0"=>{"id"=>q1.id, "selected"=>[choices_hash["get"].id.to_s]}}, filters: {date_range: "date_range", date_range_preset: "date_range_preset"}}
    assert_redirected_to management_report_async_loading_path(remote: true, tile: DashboardReportSubSection::Tile::ENGAGEMENTS, filters: {date_range: "date_range", date_range_preset: "date_range_preset"})
    assert_equal DashboardReportSubSection::Tile::ENGAGEMENTS, assigns(:tile)
    assert_equal choices_hash["get"].id.to_s, q1.reload.positive_outcome_options_management_report
  end

  def test_scroll_survey_responses
    group_setup
    current_user_is :f_admin
    create_engagement_survey_and_its_answers
    date_range = "#{DateTime.localize(@program.created_at, format: "%m/%d/%Y")} - #{DateTime.localize(Time.now, format: "%m/%d/%Y")}"
    get :scroll_survey_responses, xhr: true, params: { next_page_index: "1", date_range: date_range}
    survey_responses = @group.survey_answers.select("common_answers.common_question_id, common_answers.user_id, common_answers.group_id, common_answers.response_id, common_answers.last_answered_at").order("last_answered_at DESC").to_a.uniq{|ans| [ans.user_id, ans.group_id, ans.response_id]}
    survey_responses.each_with_index do |response, index|
      assert_equal response.common_question_id, assigns(:survey_responses)[index].common_question_id
      assert_equal response.last_answered_at, assigns(:survey_responses)[index].last_answered_at
      assert_equal response.response_id, assigns(:survey_responses)[index].response_id
      assert_equal response.group_id, assigns(:survey_responses)[index].group_id
    end
    assert_nil assigns(:next_page_index)
  end

  private

  def group_setup
    @user = users(:f_student)
    @mentor = users(:f_mentor)
    @program = programs(:albers)
    @group = create_group(:students => [@user], :mentor => @mentor, :program => @program)
  end

  def create_engagement_survey_and_its_answers
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentoring_model = @program.default_mentoring_model
    @mentoring_model.update_attributes(:should_sync => true)
    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    create_matrix_survey_question({survey: survey})
    tem_task = create_mentoring_model_task_template
    tem_task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => @program.roles.with_name([RoleConstants::MENTOR_NAME]).first })
    MentoringModel.trigger_sync(@mentoring_model.id, I18n.locale)

    @response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    @user = @group.mentors.first
    @task = @group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first
    @task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
      @ans = @task.survey_answers.new(:user => @user, :response_id => @response_id, :answer_text => "lorem ipsum", :last_answered_at => Time.now.utc)
      @ans.survey_question = ques
      @ans.save!
    end
    @task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
      @ans1 = @task.survey_answers.new(:user => @user, :response_id => @response_id, :answer_text => "Good", :last_answered_at => Time.now.utc)
      @ans1.survey_question = ques
      @ans1.save!
    end
  end
end