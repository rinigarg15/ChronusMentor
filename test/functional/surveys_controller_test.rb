require_relative './../test_helper.rb'

class SurveysControllerTest < ActionController::TestCase
  def setup
    super
    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program.reload

    current_program_is :albers
    survey_role = create_role(:name => 'survey_role')
    add_role_permission(survey_role, 'manage_surveys')
    @survey_manager = create_user(:role_names => ['survey_role'])
  end

  # NEW ------------------------------------------------------------------------

  def test_new_only_for_admin
    current_user_is :f_student

    assert_permission_denied do
      get :new
    end
  end

  def test_new_accessible_to_admin
    current_user_is @survey_manager

    get :new, params: { survey_type: Survey::Type::ENGAGEMENT }
    assert_response :success
    assert_select 'html'
    assert_equal Survey::Type::ENGAGEMENT, assigns(:survey_type)
  end

  def test_new_invalid_survey_type
    current_user_is @survey_manager

    get :new, params: { survey_type: "Invalid" }
    assert_response :success
    assert_select 'html'
    assert_nil assigns(:survey_type)
  end


  # CREATE ---------------------------------------------------------------------

  def test_only_admin_can_create
    current_user_is :f_mentor

    assert_permission_denied do
      assert_no_difference 'Survey.count' do
        post :create, params: { :survey => {
          :name => 'What a survey!',
          :recipient_role_names => [RoleConstants::MENTOR_NAME],
          :type => "ProgramSurvey"
        }}
      end
    end
  end

  def test_create_fail_if_ongoing_mentoring_disabled
    current_user_is @survey_manager

    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    assert_raise Authorization::PermissionDenied do
      assert_no_difference 'Survey.count' do
        post :create, params: { :survey => {
          :name => 'What a survey!',
          :recipient_role_names => [RoleConstants::MENTOR_NAME],
          :type => "EngagementSurvey"
        }}
      end
    end
  end

  def test_create_program_survey_success_by_admin
    current_user_is @survey_manager
    due_date = 2.days.from_now

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_difference 'Survey.count' do
      post :create, params: { :survey => {
        :type => "ProgramSurvey",
        :name => 'What a survey!', :due_date => due_date,
        :recipient_role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
        }}
    end

    survey = assigns(:survey)
    assert survey.program_survey?
    assert_equal "What a survey!", survey.name
    assert_equal due_date.to_date, survey.due_date.to_date
    assert_equal "The survey has been successfully created. Now you can add questions to it.", flash[:notice]
    assert_redirected_to survey_survey_questions_path(survey)
  end

  def test_create_engagement_survey_success_by_admin
    current_user_is @survey_manager
    due_date = 2.days.from_now
    assert_difference 'Survey.count' do
      post :create, params: { :survey => {
        :type => "EngagementSurvey",
        :name => 'What a survey!'
        }}
    end

    survey = assigns(:survey)
    assert survey.engagement_survey?
    assert_equal "What a survey!", survey.name
    assert_equal "The survey has been successfully created. Now you can add questions to it.", flash[:notice]
    assert_redirected_to survey_survey_questions_path(survey)
  end

  def test_create_engagement_survey_with_CSV_questions_file_success_by_admin
    current_user_is @survey_manager

    assert_difference 'Survey.count' do
      assert_difference "SurveyQuestion.count", 61 do
        # File has two sub matrix questions which should not be considered for SurveyResponseColumn
        assert_difference "SurveyResponseColumn.count", ( 61 - 2 ) + SurveyResponseColumn::Columns.default_columns.count  do
          post :create, params: { survey: {
            type: "EngagementSurvey",
            name: 'What a survey!',
            questions_file: fixture_file_upload("files/solution_pack_import/survey_question_survey.csv", "text/csv")
          }}
        end
      end
    end

    survey = assigns(:survey)
    assert survey.engagement_survey?
    assert_equal "What a survey!", survey.name
    assert_equal "The survey has been successfully created.", flash[:notice]
    assert_redirected_to survey_survey_questions_path(survey)
  end

  def test_create_engagement_survey_with_invalid_CSV_questions_file_by_admin
    current_user_is @survey_manager
    due_date = 2.days.from_now
    csv_questions = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')

    assert_no_difference 'Survey.count' do
      post :create, params: { :survey => {
        :type => "EngagementSurvey",
        :name => 'What a survey!',
        :questions_file => csv_questions
        }}
    end

    survey = assigns(:survey)
    assert_not_nil survey.errors[:questions_file]
    assert_response :success
    assert_equal "Please upload a valid CSV file.", flash.now[:error]
    assert_template 'new'
  end

  def test_create_survey_questions_from_invalid_csv_stream
    current_user_is @survey_manager
    due_date = 2.days.from_now
    csv_questions = fixture_file_upload("/files/solution_pack_import/survey.csv", "text/csv")

    assert_no_difference 'Survey.count' do
      post :create, params: { :survey => {
        :type => "EngagementSurvey",
        :name => 'Survey with invalid columns!',
        :questions_file => csv_questions
        }}
    end

    survey = assigns(:survey)
    assert_not_nil survey.errors[:questions_file]
    assert_response :success
    assert_equal "Please upload a valid CSV file.", flash.now[:error]
    assert_template 'new'
  end

  def test_create_with_invalid_survey_type
    current_user_is @survey_manager
    due_date = 2.days.from_now

    assert_permission_denied  do
      assert_no_difference 'Survey.count' do
        post :create, params: { :survey => {
          :type => "InvalidSurvey",
          :name => 'Survey with invalid columns!',
          }}
      end
    end
  end

  def test_create_program_survey_failure
    current_user_is @survey_manager

    assert_no_difference 'Survey.count' do
      post :create, params: { :survey => {
        :type => "ProgramSurvey",
        :name => 'What a survey!',
        :due_date => 2.days.ago
      }}
    end

    survey = assigns(:survey)
    assert_not_nil survey.errors[:due_date]
    assert_response :success
    assert_template 'new'
  end

  def test_create_engagement_survey_failure
    current_user_is @survey_manager

    assert_no_difference 'Survey.count' do
      post :create, params: { :survey => {
        :type => "EngagementSurvey",
      }}
    end

    survey = assigns(:survey)
    assert_not_nil survey.errors[:name]
    assert_response :success
    assert_template 'new'
  end

  # INDEX ----------------------------------------------------------------------

  def test_index_not_for_non_admin
    current_user_is :f_mentor

    assert_permission_denied do
      get :index
    end
  end

  # Responses are tested at the model level. Not testing here.
  def test_index_fetches_surveys
    program = programs(:albers)
    program_survey = surveys(:one)
    engagement_survey = surveys(:two)
    feedback_survey = program.feedback_survey
    mentor_meeting_feedback_survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    mentee_meeting_feedback_survey = program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    no_question_survey = create_program_survey
    surveys = [program_survey, engagement_survey, feedback_survey, mentor_meeting_feedback_survey, mentee_meeting_feedback_survey, no_question_survey]
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program.enable_feature(FeatureName::CALENDAR)

    current_user_is :f_mentor
    q1 = common_questions(:q2_name)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: engagement_survey.id)
    survey_response = Survey::SurveyResponse.new(engagement_survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"]})
    last_answer = engagement_survey.survey_answers.last
    Time.zone = "America/Los_Angeles"
    last_answer.last_answered_at  = Date.current.end_of_day
    last_answer.save!

    @survey_manager.member.update_attributes!(time_zone: "Asia/Tokyo")
    current_user_is @survey_manager
    get :index
    assert_response :success
    assert_equal_unordered program.surveys, assigns(:surveys)
    assert surveys.all? { |survey| assigns(:surveys).include?(survey) }
    assert [program_survey, no_question_survey].all? { |survey| assigns(:surveys_by_type)[ProgramSurvey.name].include?(survey) }
    assert [mentor_meeting_feedback_survey, mentee_meeting_feedback_survey, engagement_survey, feedback_survey].all? { |survey| !assigns(:surveys_by_type)[ProgramSurvey.name].include?(survey) }
    assert [engagement_survey, feedback_survey].all? { |survey| assigns(:surveys_by_type)[EngagementSurvey.name].include?(survey) }
    assert [mentor_meeting_feedback_survey, program_survey, no_question_survey].all? { |survey| !assigns(:surveys_by_type)[EngagementSurvey.name].include?(survey) }
    assert_equal [mentor_meeting_feedback_survey, mentee_meeting_feedback_survey], assigns(:surveys_by_type)[MeetingFeedbackSurvey.name]
    assert_match DateTime.localize(last_answer.last_answered_at.in_time_zone, format: :full_display_short_month), @response.body
  end

  # SHOW -----------------------------------------------------------------------

  def test_xls_export
    current_user_is @survey_manager

    get :show, params: { :id => surveys(:one), :format => 'xls'}
    assert_response :success
    assert_nil assigns(:meetings)
    assert_nil assigns(:meeting_members)
    assert_nil assigns(:member_names)
  end

  def test_xls_export_engagement_survey_fail_ongoing_mentoring_disabled
    current_user_is @survey_manager

    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    assert_permission_denied do
      get :show, params: { :id => surveys(:two), :format => 'xls'}
    end
  end

  def test_xls_export_meeting_survey_fail_ongoing_mentoring_disabled
    current_user_is @survey_manager
    program = programs(:albers)

    assert_false program.calendar_enabled?

    survey = program.surveys.find_by(name: "Meeting Feedback Survey For Mentees")
    assert_permission_denied do
      get :show, params: { :id => survey, :format => 'xls'}
    end
  end


  # UPDATE ---------------------------------------------------------------------

  def test_update_only_by_admin
    current_user_is :f_student

    assert_permission_denied do
      put :update, params: { :id => surveys(:one).id, :survey => {:name => 'something'}}
    end
  end

  def test_update_success
    current_user_is @survey_manager

    new_due_date = 6.days.from_now
    put :update, xhr: true, params: { :id => surveys(:one).id, :survey => {
      :name => 'something', :due_date => new_due_date}}

    assert_response :success
    assert_equal surveys(:one), assigns(:survey)
    surveys(:one).reload
    assert_equal 'something', surveys(:one).name
    assert_equal new_due_date.to_date, surveys(:one).due_date.to_date
  end

  def test_update_fail_ongoing_mentoring_disabled
    current_user_is @survey_manager

    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    new_due_date = 6.days.from_now
    assert_permission_denied do
      put :update, xhr: true, params: { :id => surveys(:two).id, :survey => {
        :name => 'something', :due_date => new_due_date}}
    end
  end

  def test_create_progress_report_enabled
    current_user_is @survey_manager
    programs(:albers).enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, true)

    due_date = 2.days.from_now
    assert_difference 'Survey.count' do
      post :create, params: { survey: {
        progress_report: true,
        type: "EngagementSurvey",
        name: 'What a survey!'
      } }
    end

    survey = assigns(:survey)
    assert survey.engagement_survey?
    assert_equal "What a survey!", survey.name
    assert_equal "The survey has been successfully created. Now you can add questions to it.", flash[:notice]
    assert survey.progress_report
    assert_redirected_to survey_survey_questions_path(survey)
  end

  def test_create_progress_report_disabled
    current_user_is @survey_manager
    programs(:albers).enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, false)

    due_date = 2.days.from_now
    assert_difference 'Survey.count' do
      post :create, params: { survey: {
        progress_report: true,
        type: "EngagementSurvey",
        name: 'What a survey!'
      } }
    end

    survey = assigns(:survey)
    assert survey.engagement_survey?
    assert_equal "What a survey!", survey.name
    assert_equal "The survey has been successfully created. Now you can add questions to it.", flash[:notice]
    assert_false survey.progress_report
    assert_redirected_to survey_survey_questions_path(survey)
  end

  def test_update_progress_report_enabled
    programs(:albers).enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, true)

    current_user_is @survey_manager

    put :update, xhr: true, params: { :id => surveys(:two).id, :survey => {
      :name => 'something', progress_report: true } }

    assert_response :success
    assert_equal surveys(:two), assigns(:survey)
    assert assigns(:survey).progress_report
  end

  def test_update_progress_report_disabled
    programs(:albers).enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, false)

    current_user_is @survey_manager

    put :update, xhr: true, params: { :id => surveys(:two).id, :survey => {
      :name => 'something', progress_report: true } }

    assert_response :success
    assert_equal surveys(:two), assigns(:survey)
    assert_false assigns(:survey).progress_report
  end

  # CLONE --------------------------------------------------------------------
  def test_clone_without_super_user
    current_user_is :f_student

    assert_permission_denied do
      get :clone, params: { :id => surveys(:one).id}
    end

    current_user_is @survey_manager

    assert_permission_denied do
      get :clone, params: { :id => surveys(:one).id}
    end
  end

  def test_clone
    login_as_super_user
    current_user_is :f_admin
    prog = programs(:albers)
    survey = prog.surveys.first
    count = prog.surveys.size

    post :clone, params: { :id => survey.id, :clone_survey_name => "Copy of " + survey.name}
    clone_survey = Survey.last
    assert_redirected_to survey_survey_questions_path(clone_survey)
    assert_equal clone_survey.name, ("Copy of " + survey.name)
    assert_equal prog.surveys.size, (count + 1)
    assert_equal clone_survey.survey_questions.size, survey.survey_questions.size
    assert_equal 0, clone_survey.total_responses
    assert_nil clone_survey.due_date
  end

  # DESTROY --------------------------------------------------------------------

  def test_non_admin_cannot_delete
    survey = surveys(:one)
    assert survey.destroyable?

    current_user_is :f_student
    assert_permission_denied do
      delete :destroy, params: { id: survey.id}
    end
  end

  def test_destroy_sucess
    survey = surveys(:one)
    assert survey.destroyable?

    current_user_is @survey_manager
    assert_difference 'Survey.count', -1 do
      delete :destroy, params: { id: survey.id}
    end
    assert_equal "The survey has been deleted", flash[:notice]
  end

  def test_destroy_not_destroyable
    survey = surveys(:one)

    ProgramSurvey.any_instance.stubs(:destroyable?).returns(false)
    current_user_is @survey_manager
    assert_permission_denied do
      delete :destroy, params: { id: survey.id}
    end
  end

  def test_destroy_fail_ongoing_mentoring_disabled
    survey = surveys(:two)
    program = survey.program
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    current_user_is @survey_manager
    assert_permission_denied do
      delete :destroy, params: { id: survey.id}
    end
  end

  def test_destroy_engagement_survey_with_associated_tasks_in_closed_connections
    survey = surveys(:two)
    EngagementSurvey.any_instance.stubs(:destroyable?).returns(true)
    task = create_mentoring_model_task(group: groups(:mygroup), action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    task2 = create_mentoring_model_task(group: groups(:group_2), user: users(:student_2), action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    Group.stubs(:closed).returns(Group.where(id: task.group_id))

    current_user_is @survey_manager
    assert_difference "MentoringModel::Task.count", -1 do
      assert_difference "Survey.count", -1 do
        delete :destroy, params: { id: survey.id}
      end
    end
    assert_equal "The survey has been deleted", flash[:notice]
  end

  # edit_answers ---------------------------------------------------------------

  def test_edit_answers_renders
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})

    get :edit_answers, params: { :id => survey.id, :src => Survey::SurveySource::TASK}
    assert_response :success
    assert_template 'edit_answers'
    assert_select 'html'
    response = assigns(:response)
    assert_equal questions, response.question_answer_map.keys
    assert_equal survey, response.survey
    assert_false response.question_answer_map.values.collect(&:persisted?).any?
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
    assert_equal Survey::SurveySource::TASK, assigns(:from_src)
  end

  def test_edit_engagement_survey_answers
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    get :edit_answers, params: { id: survey.id, task_id: task.id}
    assert_response :success
    assert_template "edit_answers"
    assert_equal task, assigns(:task)
    response = assigns(:response)
    assert_equal_unordered [q1, q2, q3], response.question_answer_map.keys
    assert_equal survey, response.survey
    assert response.question_answer_map.values.collect(&:persisted?).any?
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
  end

  def test_edit_engagement_survey_answers_ongoing_mentoring_disabled
    current_user_is :f_mentor

    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})
    assert_permission_denied do
      get :edit_answers, params: { id: survey.id, task_id: task.id}
    end
  end


  def test_edit_engagement_survey_answers_without_task_and_with_appropriate_group
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    group = users(:f_mentor).groups.active.first
    group_with_answer = create_group(:student => users(:f_student),:mentor => users(:f_mentor))
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, group_id: group_with_answer.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})
    @controller.expects(:prepare_template).with(skip_survey_initialization: true).once

    get :edit_answers, params: { id: survey.id, group_id: group.id}
    assert_response :success
    assert_template "edit_answers"
    assert_equal group, assigns(:group)
    response = assigns(:response)
    assert_equal_unordered [q1, q2, q3], response.question_answer_map.keys
    assert_equal survey, response.survey
    assert_false response.question_answer_map.values.collect(&:persisted?).any?
  end

  def test_edit_engagement_survey_answers_without_task_and_with_appropriate_group_for_closed_connection
    current_user_is :f_mentor

    survey = surveys(:two)
    group = users(:f_mentor).groups.active.first
    group.status = Group::Status::INACTIVE
    group.save!

    assert_nothing_raised do
      get :edit_answers, params: { id: survey.id, group_id: group.id}
    end
    assert assigns(:surveys_controls_allowed)
  end

  def test_edit_engagement_survey_answers_without_task_and_with_appropriate_group_for_drafted_connection
    current_user_is :student_1
    group = groups(:drafted_group_1)
    survey = surveys(:two)
    assert_nothing_raised do
      get :edit_answers, params: { id: survey.id, group_id: group.id}
    end
    assert_false assigns(:surveys_controls_allowed)
  end

  def test_edit_engagement_survey_answers_without_task_and_with_appropriate_group_for_expired_connection
    current_user_is :f_mentor
    group = groups(:mygroup)
    group.expiry_time = 1.day.ago
    group.save(:validate => false)
    assert group.reload.expired?
    survey = surveys(:two)
    assert_nothing_raised do
      get :edit_answers, params: { id: survey.id, group_id: group.id}
    end
    assert assigns(:surveys_controls_allowed)
  end

  def test_edit_engagement_survey_answers_without_task_and_with_not_appropriate_group
    current_user_is :f_mentor
    survey = surveys(:two)
    group = programs(:albers).groups.active.last

    assert_raise Authorization::PermissionDenied do
      get :edit_answers, params: { id: survey.id, group_id: group.id}
    end
  end

  def test_admin_accesses_edit_answer
    current_user_is @survey_manager
    survey = surveys(:one)
    survey.recipient_role_names = [RoleConstants::MENTOR_NAME]
    survey.save!

    assert_nothing_raised do
      get :edit_answers, params: { :id => survey.id}
    end
    assert_response :success
    assert_equal "Only mentors can take part in the survey", flash[:error]
  end

  def test_meeting_survey_without_meeting_details
    current_user_is @survey_manager
    survey = programs(:albers).surveys.of_meeting_feedback_type.first

    assert_raise Authorization::PermissionDenied do
      get :edit_answers, params: { :id => survey.id}
    end
  end

  def test_meeting_survey_with_future_meeting
    current_user_is @survey_manager
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.reload
    survey = program.surveys.of_meeting_feedback_type.first
    meeting = program.meetings.where(recurrent: false).first
    meeting.start_time = 1.day.from_now
    meeting.end_time = 1.day.from_now + 1.hour
    meeting.save!
    member_meeting = meeting.member_meetings.first
    # group meeting is not stopped from giving feedback thru url, but in UI we do not show option

    assert_nothing_raised do
      get :edit_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first}
    end
    assert_equal "These questions can only be answered in the context of a valid past Meeting", flash[:error]
    assert_equal member_meeting, assigns(:member_meeting)
    assert_equal meeting.occurrences.first, assigns(:meeting_timing).to_time
  end

  def test_meeting_survey_with_person_not_belonging_in_meeting
    current_user_is @survey_manager
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.reload
    survey = program.surveys.of_meeting_feedback_type.first
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.first

    assert_nothing_raised do
      get :edit_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first}
    end

    assert_equal "These questions can only be answered in the context of a valid past Meeting", flash[:error]
    assert_equal member_meeting, assigns(:member_meeting)
    assert_equal meeting.occurrences.first, assigns(:meeting_timing)
  end

  def test_meeting_survey_with_correct_params
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.reload
    survey = program.surveys.of_meeting_feedback_type.first
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.first

    current_user_is member_meeting.member.user_in_program(program)
    assert_nothing_raised do
      get :edit_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first}
    end

    assert_nil flash[:error]
    assert_equal member_meeting, assigns(:member_meeting)
    assert_equal meeting.occurrences.first, assigns(:meeting_timing)
  end

  def test_edit_answers_fetches_old_answers
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})

    answer_0 = create_survey_answer({:survey_question => questions[0]})
    answer_2 = create_survey_answer(
      {:answer_value => {answer_text: "set", question: questions[2]}, :survey_question => questions[2]})

    get :edit_answers, params: { :id => survey.id, :response_id => 1}
    assert_response :success
    assert_template 'edit_answers'
    assert_select 'html'

    response = assigns(:response)
    assert_equal questions, response.question_answer_map.keys
    assert_equal survey, response.survey
    assert_equal answer_0, response.question_answer_map[questions[0]]
    assert_false response.question_answer_map[questions[1]].persisted?
    assert_equal answer_2, response.question_answer_map[questions[2]]
  end

  def test_edit_answers_fetches_drafted_answers
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})

    answer_0 = create_survey_answer({survey_question: questions[0]})
    answer_2 = create_survey_answer(
      {answer_value: {answer_text: "set", question: questions[2]}, survey_question: questions[2]})
    answer_0.update_attributes!(is_draft: true)
    answer_2.update_attributes!(is_draft: true)

    get :edit_answers, params: { id: survey.id }
    assert_response :success
    assert_template 'edit_answers'

    response = assigns(:response)
    assert_equal questions, response.question_answer_map.keys
    assert_equal survey, response.survey
    assert_equal answer_0, response.question_answer_map[questions[0]]
    assert_false response.question_answer_map[questions[1]].persisted?
    assert_equal answer_2, response.question_answer_map[questions[2]]
  end

  def test_cannot_participate_in_overdue_survey
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})

    # update_attribute so as to skip validations
    survey.update_attribute :due_date, 2.days.ago
    assert survey.reload.overdue?

    get :edit_answers, params: { id: survey.id}
    assert_redirected_to program_root_path
    assert_equal  "The survey has passed it's due date and you cannot participate in it now.", flash[:error]
  end

  # UPDATE_ANSWERS ---------------------------------------------------------------

  def test_update_answers_failure
    current_user_is :f_student

    survey = surveys(:one)
    question = create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})
    question_1 = create_survey_question({
      question_type: CommonQuestion::Type::STRING, survey: survey})

    # XXX: The correct answer may not get saved in case it comes after the wrong
    # answer after sorting. This is a bad implementation limitation, and we
    # should fix this. Currently this is fine given we have strong client side
    # validations.
    # So, we cannot check the SurveyAnswer.count since it is not dependable.
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    put :update_answers, params: { :id => survey.id, :survey_answers => {
      question.id => "wrong",
      question_1.id => "perfect"
    }}

    assert_redirected_to edit_answers_survey_path(survey, :error_q_ids => [question.id], :src => Survey::SurveySource::NON_CONN_SURVEY)
    assert_equal "Required fields cannot be blank", flash[:error]
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
  end

  def test_update_empty_answers_success
    current_user_is :f_student

    survey = surveys(:one)
    questions = []

    q = survey.survey_questions.new(question_type: CommonQuestion::Type::MATRIX_RATING, program_id: survey.program.id, question_text: "Matrix Question")
    ["Bad","Average","Good"].each_with_index{|text, pos| q.question_choices.build(text: text, position: pos + 1, ref_obj: q) }
    q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
    q.create_survey_question
    q.save
    questions << q
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    assert_difference 'SurveyAnswer.count', 0 do
      put :update_answers, params: { :id => survey.id}
    end

    assert_redirected_to program_root_path
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
  end

  def test_update_answers_success
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({:survey => survey})
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::RATING_SCALE,
      question_choices: "Good,Better,Best", survey: survey})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_difference 'SurveyAnswer.count', 3 do
      put :update_answers, params: { :id => survey.id, :survey_answers => {
        questions[0].id => "Land",
        questions[2].id => "set",
        questions[3].id => "Better"
      }}
    end

    assert_redirected_to program_root_path
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]

    answer_1 = questions[0].survey_answers.reload.last
    answer_2 = questions[2].survey_answers.reload.last
    answer_3 = questions[3].survey_answers.reload.last

    assert_equal "Land", answer_1.answer_text
    assert_equal users(:f_student), answer_1.user

    assert_equal "set", answer_2.answer_text
    assert_equal users(:f_student), answer_2.user

    assert_equal "Better", answer_3.answer_text
    assert_equal users(:f_student), answer_3.user

    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
  end

  def test_update_answers_for_engagement_survey_from_survey_popup
    current_user_is :f_mentor

    survey = surveys(:two)

    mentoring_model = programs(:albers).mentoring_models.default.first
    groups(:mygroup).update_attribute(:mentoring_model_id, mentoring_model.id)

    cm = groups(:mygroup).membership_of(users(:f_mentor))
    MentoringModel::Task.any_instance.stubs(:overdue?).returns(true)

    task_template = create_mentoring_model_task_template
    task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    task_template.action_item_id = survey.id
    task_template.skip_survey_validations = true
    task_template.save!

    task = cm.get_last_outstanding_survey_task

    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last

    assert_equal "Clark Kent\n Superman\n Kal-El", answer_1.answer_text
    assert_equal "Smallville", answer_2.answer_text
    assert_equal "Krypton", answer_3.answer_text

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    assert_no_difference "SurveyAnswer.count" do
      put :update_answers, params: { id: survey.id, task_id: task.id, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      }, :src => Survey::SurveySource::POPUP}
    end

    assert_redirected_to group_path(groups(:mygroup))

    assert_equal Survey::SurveySource::POPUP, assigns(:from_src)
    assert_equal survey, assigns(:last_overdue_survey)
    assert_equal edit_answers_survey_path(survey, :task_id => task.id, :src => Survey::SurveySource::FLASH), assigns(:new_survey_answer_path)
    assert_equal "Thanks for your feedback! It looks like you have another survey overdue as well. Click <a href='/p/albers/surveys/#{survey.id}/edit_answers?src=4&amp;task_id=#{task.id}'>here</a> to complete it.", flash[:notice]

    assert_equal task, assigns(:task)

    assert_equal "Ironman\n Superman\n Spiderman", answer_1.reload.answer_text
    assert_equal "Chennai", answer_2.reload.answer_text
    assert_equal "Earth", answer_3.reload.answer_text

    assert_equal users(:f_mentor), answer_1.user
    assert_equal users(:f_mentor), answer_2.user
    assert_equal users(:f_mentor), answer_3.user
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
  end

  def test_update_answers_draft_success
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({:survey => survey})
    questions << create_survey_question({:survey => survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::RATING_SCALE,
      question_choices: "Good,Better,Best", survey: survey})

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    session[:last_visit_url] = "/test_url"
    assert_difference 'SurveyAnswer.count', 0 do
      assert_difference 'SurveyAnswer.drafted.count', 3 do
        put :update_answers, params: { :id => survey.id, :survey_answers => {
          questions[0].id => "Land",
          questions[2].id => "set",
          questions[3].id => "Better"
        }, :is_draft => true, :src => Survey::SurveySource::POPUP}
      end
    end

    assert_redirected_to program_root_path
    assert_equal "Your draft for the survey '#{survey.name}' has been saved successfully.", flash[:notice]

    answer_1 = questions[0].survey_answers.drafted.reload.last
    answer_2 = questions[2].survey_answers.drafted.reload.last
    answer_3 = questions[3].survey_answers.drafted.reload.last

    assert_equal "Land", answer_1.answer_text
    assert_equal users(:f_student), answer_1.user

    assert_equal "set", answer_2.answer_text
    assert_equal users(:f_student), answer_2.user

    assert_equal "Better", answer_3.answer_text
    assert_equal users(:f_student), answer_3.user

    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)

    assert_nil assigns(:last_overdue_survey)
    assert_nil assigns(:new_survey_answer_path)
  end

  def test_update_answers_for_engagement_survey
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last

    assert_equal "Clark Kent\n Superman\n Kal-El", answer_1.answer_text
    assert_equal "Smallville", answer_2.answer_text
    assert_equal "Krypton", answer_3.answer_text
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    @controller.expects(:generate_progress_report_pdf_content).never
    EngagementSurvey.expects(:generate_and_email_progress_report_pdf).never
    assert_no_difference "SurveyAnswer.count" do
      put :update_answers, params: { id: survey.id, task_id: task.id, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      }}
    end

    assert_equal task, assigns(:task)
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]

    assert_equal "Ironman\n Superman\n Spiderman", answer_1.reload.answer_text
    assert_equal "Chennai", answer_2.reload.answer_text
    assert_equal "Earth", answer_3.reload.answer_text

    assert_equal users(:f_mentor), answer_1.user
    assert_equal users(:f_mentor), answer_2.user
    assert_equal users(:f_mentor), answer_3.user
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
  end

  def test_update_answers_for_engagement_closure_survey
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    milestone = create_mentoring_model_milestone
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, milestone_id: milestone.id)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last

    assert_equal "Clark Kent\n Superman\n Kal-El", answer_1.answer_text
    assert_equal "Smallville", answer_2.answer_text
    assert_equal "Krypton", answer_3.answer_text
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    assert_no_difference "SurveyAnswer.count" do
      put :update_answers, params: { id: survey.id, task_id: task.id, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      }}
    end
  end

  def test_update_answers_for_progress_report_enabled
    current_user_is :f_mentor

    survey = surveys(:two)
    survey.program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, true)
    survey.update_attributes!(progress_report: true)

    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)

    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last

    assert_equal "Clark Kent\n Superman\n Kal-El", answer_1.answer_text
    assert_equal "Smallville", answer_2.answer_text
    assert_equal "Krypton", answer_3.answer_text
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
    ChronusS3Utils::S3Helper.stubs(:write_to_file_and_store_in_s3).returns(true)
    EngagementSurvey.expects(:generate_and_email_progress_report_pdf).once
    assert_no_difference "SurveyAnswer.count" do
      put :update_answers, params: { id: survey.id, task_id: task.id, share_progress_report: true, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      } }
    end

    assert_equal task, assigns(:task)
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]

    assert_equal "Ironman\n Superman\n Spiderman", answer_1.reload.answer_text
    assert_equal "Chennai", answer_2.reload.answer_text
    assert_equal "Earth", answer_3.reload.answer_text

    assert_equal users(:f_mentor), answer_1.user
    assert_equal users(:f_mentor), answer_2.user
    assert_equal users(:f_mentor), answer_3.user
    assert_false assigns(:not_published)
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
    assert assigns(:response)
    assert_equal "Introduce yourself", assigns(:title)
    assert assigns(:hide_logo_in_pdf)
  end


  def test_update_answers_for_progress_report_enabled_for_draft
    current_user_is :f_mentor

    survey = surveys(:two)
    survey.program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, true)
    survey.update_attributes!(progress_report: true)

    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    @controller.expects(:generate_progress_report_pdf_content).never
    EngagementSurvey.expects(:generate_and_email_progress_report_pdf).never
    assert_no_difference "SurveyAnswer.count" do
      assert_difference "SurveyAnswer.drafted.count", 3 do
        put :update_answers, params: { id: survey.id, task_id: task.id, share_progress_report: true, is_draft: true, survey_answers: {
          q1.id => ["Ironman", "Superman", "Spiderman"],
          q2.id => "Chennai",
          q3.id => "Earth"
        } }
      end
    end

    assert_equal task, assigns(:task)
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal "Your draft for the survey '#{survey.name}' has been saved successfully. Please note that the response is not shared yet.", flash[:notice]
    answer_1 = q1.survey_answers.drafted.reload.last
    answer_2 = q2.survey_answers.drafted.reload.last
    answer_3 = q3.survey_answers.drafted.reload.last


    assert_equal "Ironman\n Superman\n Spiderman", answer_1.reload.answer_text
    assert_equal "Chennai", answer_2.reload.answer_text
    assert_equal "Earth", answer_3.reload.answer_text

    assert_equal users(:f_mentor), answer_1.user
    assert_equal users(:f_mentor), answer_2.user
    assert_equal users(:f_mentor), answer_3.user
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
    assert_nil assigns(:title)
    assert assigns(:not_published)
    assert_nil assigns(:hide_logo_in_pdf)
    assert assigns(:response)
  end

  def test_update_answers_for_progress_report_enabled_first_submit
    current_user_is :f_mentor

    survey = surveys(:two)
    survey.program.enable_feature(FeatureName::SHARE_PROGRESS_REPORTS, true)
    survey.update_attributes!(progress_report: true)

    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)


    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).once
    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
    ChronusS3Utils::S3Helper.stubs(:write_to_file_and_store_in_s3).returns(true)
    EngagementSurvey.expects(:generate_and_email_progress_report_pdf).once
    assert_difference "SurveyAnswer.count", 3 do
      put :update_answers, params: { id: survey.id, task_id: task.id, share_progress_report: true, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      } }
    end


    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last
    assert_equal task, assigns(:task)
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]

    assert_equal "Ironman\n Superman\n Spiderman", answer_1.reload.answer_text
    assert_equal "Chennai", answer_2.reload.answer_text
    assert_equal "Earth", answer_3.reload.answer_text

    assert_equal users(:f_mentor), answer_1.user
    assert_equal users(:f_mentor), answer_2.user
    assert_equal users(:f_mentor), answer_3.user
    assert assigns(:not_published)
    assert_nil assigns(:member_meeting)
    assert_nil assigns(:meeting_timing)
    assert assigns(:response)
    assert_equal "Introduce yourself", assigns(:title)
    assert assigns(:hide_logo_in_pdf)
  end

  def test_update_answers_for_engagement_survey_ongoing_mentoring_disabled
    current_user_is :f_mentor

    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name), common_questions(:q2_location), common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last

    assert_equal "Clark Kent\n Superman\n Kal-El", answer_1.answer_text
    assert_equal "Smallville", answer_2.answer_text
    assert_equal "Krypton", answer_3.answer_text
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    assert_permission_denied do
      put :update_answers, params: { id: survey.id, task_id: task.id, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      }}
    end
  end

  def test_update_answers_for_engagement_survey_without_task_and_with_appropriate_group
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    group = users(:f_mentor).groups.active.first
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_TASK).never
    assert_difference "SurveyAnswer.count", 3 do
      put :update_answers, params: { id: survey.id, group_id: group.id, survey_answers: {
        q1.id => ["Ironman", "Superman", "Spiderman"],
        q2.id => "Chennai",
        q3.id => "Earth"
      }}
    end
    answer_1 = q1.survey_answers.reload.last
    answer_2 = q2.survey_answers.reload.last
    answer_3 = q3.survey_answers.reload.last

    assert_equal group.id, answer_1.group_id
    assert_equal group.id, answer_2.group_id
    assert_equal group.id, answer_3.group_id

    assert_equal group, assigns(:group)
    assert_redirected_to group_path(groups(:mygroup))
    assert assigns(:not_published)
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]
  end

  def test_update_answers_for_engagement_survey_without_task_and_with_appropriate_group_for_closed_connection
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    group = users(:f_mentor).groups.active.first
    group.status = Group::Status::INACTIVE
    group.save!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_difference "SurveyAnswer.count", 3 do
      assert_nothing_raised do
        put :update_answers, params: { id: survey.id, group_id: group.id, survey_answers: {
          q1.id => ["Ironman", "Superman", "Spiderman"],
          q2.id => "Chennai",
          q3.id => "Earth"
        }}
      end
    end
    answer_1 = q1.survey_answers.last
    answer_2 = q2.survey_answers.last
    answer_3 = q3.survey_answers.last

    assert_equal group.id, answer_1.group_id
    assert_equal group.id, answer_2.group_id
    assert_equal group.id, answer_3.group_id

    assert_equal group, assigns(:group)
    assert_redirected_to group_path(groups(:mygroup))
    assert_equal "Thanks for completing #{survey.name}", flash[:notice]
  end

  def test_update_answers_for_engagement_survey_without_task_and_with_not_appropriate_group
    current_user_is :f_mentor
    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    group = programs(:albers).groups.active.last
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_raise Authorization::PermissionDenied do
      assert_no_difference "SurveyAnswer.count" do
        put :update_answers, params: { id: survey.id, group_id: group.id, survey_answers: {
          q1.id => ["Ironman", "Superman", "Spiderman"],
          q2.id => "Chennai",
          q3.id => "Earth"
        }}
      end
    end
  end

  def test_edit_answers_old_meeting_survey_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    current_user_is :f_mentor
    survey = create_survey({:name => "Meeting Report", :program => program, :type => "MeetingFeedbackSurvey", role_name: RoleConstants::MENTOR_NAME })
    survey.update_attribute(:role_name, nil)
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.first
    get :edit_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first}
    assert_redirected_to(participate_survey_path(:id => program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME).id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first, :src => Survey::SurveySource::MAIL))
  end

  def test_edit_answers_old_meeting_survey_mentee
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    current_user_is :mkr_student
    survey = create_survey({:name => "Meeting Report", :program => program, :type => "MeetingFeedbackSurvey", role_name: RoleConstants::MENTOR_NAME })
    survey.update_attribute(:role_name, nil)
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.last
    get :edit_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first}
    assert_redirected_to(participate_survey_path(:id => program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME).id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first, :src => Survey::SurveySource::MAIL))
  end

  def test_edit_answers_for_engagement_survey_with_overdue_task
    current_user_is :f_mentor

    survey = surveys(:two)
    q1,q2,q3 = common_questions(:q2_name),common_questions(:q2_location),common_questions(:q2_from)
    task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, required: true, due_date: 1.week.ago.utc)
    survey_response = Survey::SurveyResponse.new(survey, {user_id: users(:f_mentor).id, task_id: task.id})
    survey_response.save_answers({q1.id => ["Clark Kent", "Superman", "Kal-El"], q2.id => "Smallville", q3.id => "Krypton"})

    assert task.overdue?
    assert survey.engagement_survey?
    get :edit_answers, params: { id: survey.id, task_id: task.id}

    assert_not_equal "#{survey.name} has expired.", flash[:notice]
    assert_response :success
    assert_template "edit_answers"
    assert_equal task, assigns(:task)
  end

  def test_cannot_update_answers_for_overdue_survey
    current_user_is :f_student

    survey = surveys(:one)
    questions = []
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({survey: survey})
    questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: survey})

    # update_attribute so as to skip validations
    survey.update_attribute :due_date, 2.days.ago
    assert survey.reload.overdue?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_no_difference 'SurveyAnswer.count' do
      put :update_answers, params: { :id => survey.id, :survey_answers => {
        questions[0].id => "Land",
        questions[1].id => "set",
        questions[2].id => "get"
      }}
    end

    assert_redirected_to program_root_path
    assert_equal "The survey has passed it's due date and you cannot participate in it now.", flash[:error]
  end

  def test_update_meeting_survey_without_meeting_details
    current_user_is @survey_manager
    survey = programs(:albers).surveys.of_meeting_feedback_type.first
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_raise Authorization::PermissionDenied do
      get :update_answers, params: { :id => survey.id}
    end
  end

  def test_save_answers_of_meeting_survey_with_correct_params
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    survey = program.surveys.of_meeting_feedback_type.first
    survey.survey_questions.each do |sq|
      sq.update_attribute(:condition, SurveyQuestion::Condition::ALWAYS)
    end
    question_id = survey.survey_questions.pluck(:id)
    survey.survey_questions.where.not(id: question_id.first(2)).destroy_all
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.first
    user = member_meeting.member.user_in_program(program)
    count = SurveyAnswer.count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).once
    current_user_is user
    assert_nothing_raised do
      get :update_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first,
                           survey_answers: {question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}}
    end
    assert_nil flash[:error]
    assert_equal member_meeting, assigns(:member_meeting)
    assert_equal meeting.occurrences.first, assigns(:meeting_timing)
    assert_equal (count + 2), SurveyAnswer.count
    answers = SurveyAnswer.last(2)
    assert_equal_unordered answers.collect(&:answer_text), ["Extremely satisfying", "Great use of time"]
    assert_equal answers.collect(&:member_meeting_id), [member_meeting.id]*2
    assert_equal answers.collect(&:meeting_occurrence_time), [meeting.occurrences.first]*2
    assert_redirected_to member_path(user.member, meeting_id: member_meeting.meeting_id, current_occurrence_time: meeting.occurrences.first, :tab => MembersController::ShowTabs::AVAILABILITY)
  end

  def test_save_answers_of_flash_meeting_survey_with_correct_params
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, true)
    survey = program.surveys.of_meeting_feedback_type.first
    survey.survey_questions.each do |sq|
      sq.update_attribute(:condition, SurveyQuestion::Condition::ALWAYS)
    end
    time = 50.minutes.ago.change(:usec => 0)
    question_id = survey.survey_questions.pluck(:id)
    survey.survey_questions.where.not(id: question_id.first(2)).destroy_all
    time = 50.minutes.ago.change(:usec => 0)
    meeting = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    meeting.meeting_request.update_attribute(:status, AbstractRequest::Status::ACCEPTED)
    meeting.update_attributes(:state => Meeting::State::COMPLETED)
    meeting = create_meeting(:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true, state: Meeting::State::COMPLETED)
    member_meeting = meeting.member_meetings.first
    user = member_meeting.member.user_in_program(program)
    count = SurveyAnswer.count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    current_user_is user
    assert_nothing_raised do
      get :update_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first,
                           survey_answers: {question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}}
    end
    assert_nil flash[:error]
    assert_equal member_meeting, assigns(:member_meeting)
    assert_equal meeting.occurrences.first, assigns(:meeting_timing)
    assert_equal (count + 2), SurveyAnswer.count
    answers = SurveyAnswer.last(2)
    assert_equal_unordered answers.collect(&:answer_text), ["Extremely satisfying", "Great use of time"]
    assert_equal answers.collect(&:member_meeting_id), [member_meeting.id]*2
    assert_equal answers.collect(&:meeting_occurrence_time), [meeting.occurrences.first]*2
    assert_redirected_to member_path(user.member, meeting_id: member_meeting.meeting_id, current_occurrence_time: meeting.occurrences.first, :tab => MembersController::ShowTabs::AVAILABILITY)
  end
  def test_save_answers_of_meeting_survey_with_correct_params_if_one_time_is_disabled
    program = programs(:albers)
    survey = program.surveys.of_meeting_feedback_type.first
    question_id = survey.survey_questions.pluck(:id)
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.first
    user = member_meeting.member.user_in_program(program)
    count = SurveyAnswer.count

    current_user_is user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_permission_denied do
      get :update_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first,
                           survey_answers: {question_id[0] => "Good", question_id[1] => "Phone"}}
    end
  end


  def test_save_answers_of_meeting_survey_with_wrong_person
    current_user_is @survey_manager
    program = programs(:albers)
    survey = program.surveys.of_meeting_feedback_type.first
    question_id = survey.survey_questions.pluck(:id)
    meeting = program.meetings.where(recurrent: false).first
    member_meeting = meeting.member_meetings.first
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_permission_denied do
      get :update_answers, params: { :id => survey.id, member_meeting_id: member_meeting.id, meeting_occurrence_time: meeting.occurrences.first,
                           survey_answers: {question_id[0] => "Good", question_id[1] => "Phone"}}
    end
  end

  def test_report_need_permission
    current_user_is :f_student

    assert !users(:f_student).can_manage_surveys?
    assert !users(:f_student).can_view_reports?
    assert_permission_denied do
      get :report, params: { :id => surveys(:one).id}
    end
  end

  def test_program_survey_report
    current_user_is :f_admin

    survey = surveys(:one)
    get :report, params: { :id => survey.id}
    assert_response :success
    assert_page_title survey.name
    assert_template 'report'

    survey_ques = survey.survey_questions.select([:id, :question_type, :allow_other_option])
    assert_equal_unordered survey_ques, assigns(:survey_questions)
    assert assigns(:show_tabs)

    assert_select 'html'
    assert_select 'a', :text => /Edit/
    assert_select 'a', :text => /Share/
    assert_select 'ul#tab-box' do
      assert_select 'li' do
        assert_select 'a', :text => /Questions(.*)/
      end
      assert_select 'li' do
        assert_select 'a', :text => /Trends/
      end
      assert_select 'li' do
        assert_select 'a', :text => /Responses(.*)/
      end
    end
    assert_select '#survey_report'
  end

  def test_engagement_survey_report
    current_user_is :f_admin

    survey = surveys(:two)
    survey.program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    get :report, params: { :id => survey.id}
    assert_response :success
    assert_page_title survey.name
    assert_template 'report'

    survey_ques = survey.survey_questions.select([:id, :question_type, :allow_other_option])
    assert_equal_unordered survey_ques, assigns(:survey_questions)
    assert assigns(:show_tabs)

    assert_select 'html'
    assert_select 'a', :text => /Edit/
    assert_select 'a', :text => /Add to Mentoring Connection Plan/
    assert_select 'ul#tab-box' do
      assert_select 'li' do
        assert_select 'a', :text => /Questions(.*)/
      end
      assert_select 'li' do
        assert_select 'a', :text => /Trends/
      end
      assert_select 'li' do
        assert_select 'a', :text => /Responses(.*)/
      end
    end
    assert_select '#survey_report'
  end

  def test_engagement_survey_report_denied
    current_user_is :f_admin

    program = programs(:albers)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload

    survey = surveys(:two)
    survey.program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    assert_permission_denied do
      get :report, params: { :id => survey.id}
    end
  end


  def test_report_with_report_param
    current_user_is :f_admin

    survey = surveys(:one)
    get :report, params: { :id => survey.id, :report => true}
    assert_response :success
    assert_page_title survey.name.term_titleize + " Report"
    assert_template 'report'

    assert_equal survey.survey_questions, assigns(:survey_questions)
    assert !assigns(:show_tabs)

    assert_select 'html'
    assert_select 'div#action_1' do
      assert_select 'a', :text => 'View Survey'
    end

    assert_no_select '#edit_survey'
    assert_no_select '.inner_tabs'
    assert_select '#survey_report'
  end

  def test_report_export_pdf
    current_user_is :f_admin

    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails.
    survey = surveys(:one)
    get :report, params: { :id => survey.id, :report => true, :format => FORMAT::PDF}

    assert_response :success
  end

  def test_report_with_filter_params
    survey = surveys(:progress_report)
    start_time = Date.parse("3 June 2016").to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
    end_time = Date.parse("3 June 2016").to_datetime.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])

    SurveyResponsesDataService.any_instance.stubs(:filters_count).once.returns(77)
    newparams = { "0" => { field: "date", operator: "eq", value: "3 June 2016" } }
    current_user_is :no_mreq_admin
    get :report, params: { id: survey.id, report: true, newparams: newparams}
    assert_response :success
    expected_filter_params = { "0" => { field: "date", operator: "eq", value: "3 June 2016" } }
    assert_equal_hash expected_filter_params, assigns(:filter_params)
    assert_equal_hash assigns(:response_rate_hash), { responses_count: 0, users_responded: 0, users_responded_groups_or_meetings_count: 0, overdue_responses_count: 0, users_overdue: 0, users_overdue_groups_or_meetings_count: 0, response_rate: nil, percentage_error: nil }
    assert_equal "3 June 2016".to_date, assigns(:start_date).to_date
    assert_equal Time.current.to_date, assigns(:end_date).to_date
    assert_equal survey.program.roles.select { |r| !r.administrative }, assigns(:roles)
    assert_equal survey.program.profile_questions_for(survey.program.roles_without_admin_role.pluck(:name), { default: false, skype: false, fetch_all: true } ), assigns(:profile_questions)
    assert_equal 77, assigns(:filters_count)
  end

  def test_report_with_filter_params_remote
    survey = surveys(:progress_report)

    SurveyResponsesDataService.any_instance.stubs(:filters_count).once.returns(77)
    newparams = { "0" => { field: "date", operator: "eq", value: "3 June 2016" } }
    current_user_is :no_mreq_admin
    get :report, xhr: true, params: { id: survey.id, report: true, newparams: newparams}
    assert_response :success
    expected_filter_params = { "0" => { field: "date", operator: "eq", value: "3 June 2016" } }
    assert_equal_hash expected_filter_params, assigns(:filter_params)
    assert_equal_hash assigns(:response_rate_hash), { responses_count: 0, users_responded: 0, users_responded_groups_or_meetings_count: 0, overdue_responses_count: 0, users_overdue: 0, users_overdue_groups_or_meetings_count: 0, response_rate: nil, percentage_error: nil }
    assert_equal "3 June 2016".to_date, assigns(:start_date).to_date
    assert_equal Time.current.to_date, assigns(:end_date).to_date
    assert_equal survey.program.roles.select { |r| !r.administrative }, assigns(:roles)
    assert_equal survey.program.profile_questions_for(survey.program.roles_without_admin_role.pluck(:name), { default: false, skype: false, fetch_all: true } ), assigns(:profile_questions)
    assert_equal 77, assigns(:filters_count)
  end

  def test_report_filter_params_hash_meeting_survey
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    program.enable_feature(FeatureName::CALENDAR, true)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)

    current_user_is :f_admin
    get :report, params: { id: survey.id}
    assert_response :success
    assert_equal_hash assigns(:response_rate_hash), { responses_count: 0, users_responded: 0, users_responded_groups_or_meetings_count: 0, overdue_responses_count: 3, users_overdue: 1, users_overdue_groups_or_meetings_count: 3, response_rate: 0.0, percentage_error: nil }
  end

  def test_report_filter_params_hash
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    program.enable_feature(FeatureName::CALENDAR, true)
    survey = MeetingFeedbackSurvey.create!(program_id: program.id, name: "Something", role_name: RoleConstants::MENTOR_NAME)

    Timecop.freeze(Time.current.beginning_of_day) do
      time = 50.minutes.ago.change(usec: 0)
      m1 = create_meeting(program: program, topic: "Arbit Topic", start_time: time, end_time: (time + 30.minutes), location: "Chennai", members: [members(:f_mentor), members(:mkr_student)], owner_id: members(:f_mentor).id, force_non_group_meeting: true)
      m1.meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
      time = 70.minutes.ago.change(usec: 0)
      user2 = members(:not_requestable_mentor).user_in_program(programs(:albers))
      m2 = create_meeting(program: programs(:albers), topic: "Arbit Topic2", start_time: time, end_time: (time + 30.minutes), members: [members(:student_2), members(:not_requestable_mentor)], requesting_student: users(:student_2), requesting_mentor: user2, force_non_group_meeting: true, owner_id: members(:student_2).id)
      m2.meeting_request.update_attributes!(status: AbstractRequest::Status::ACCEPTED)

      new_date = "July 06, 2016"
      start_time = Date.parse(new_date).to_datetime.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
      end_time = Date.yesterday.end_of_day.change(offset: Time.current.strftime("%z")).strftime(ElasticsearchConstants::DATE_RANGE_FORMATS::FORMATS_HASH["yyyy-MM-dd HH:mm:ss ZZ"])
      SurveyAnswer.expects(:get_es_survey_answers).with( { filter: { survey_id: survey.id, is_draft: false, last_answered_at: start_time..end_time, es_range_formats: { last_answered_at: "yyyy-MM-dd HH:mm:ss ZZ" }, user_id: program.all_user_ids, response_id: [] }, source_columns: ["response_id"] } ).returns([])
      newparams = { "0" => { "field" => "date", "operator" => "eq", "value" => new_date }, "1" => { "field" => "date", "operator" => "eq", "value" => 1.minute.ago } }
      current_user_is :f_admin
      get :report, params: { id: survey.id, report: true, newparams: newparams }
      assert_response :success
      assert_equal_hash assigns(:response_rate_hash), { responses_count: 0, users_responded: 0, users_responded_groups_or_meetings_count: 0, overdue_responses_count: 5, users_overdue: 2, users_overdue_groups_or_meetings_count: 5, response_rate: 0.0, percentage_error: nil }
    end
  end

  def test_survey_edit_permissions
    current_user_is :f_student
    survey = surveys(:one)

    # Survey meant only for mentors
    survey.recipient_role_names = RoleConstants::MENTOR_NAME
    survey.save!

    assert_permission_denied do
      get :edit_answers, params: { :id => survey.id}
    end
  end

  # Survey#get_report is already tested in SurveyTest. Just ensure it's called
  # in the action.
  def test_fetches_report_data
    current_user_is @survey_manager

    # Unable to mock <code>surveys(:one).get_report</code>. So, expecting
    # the method on some instance of Survey
    ProgramSurvey.any_instance.expects(:get_report).once.returns({})
    get :report, params: { :id => surveys(:one).id}
    assert_response :success
    assert_template 'report'
    assert_equal surveys(:one), assigns(:survey)
  end

  def test_export_questions_permission_denied
    current_user_is :f_student
    survey = surveys(:one)
    assert_permission_denied do
      get :export_questions, params: { id: survey.id}
    end
  end

  def test_export_questions_success
    current_user_is :f_admin
    survey = surveys(:two)
    Survey.any_instance.stubs(:name).returns("file, name with comma")
    get :export_questions, params: { id: survey.id}
    assert_response :success
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body.split("\n")
    assert_equal_unordered SurveyQuestion.attribute_names, csv_response[0].split(",")
    assert_equal survey.survey_questions.size+1, csv_response.size
    first_question_from_csv = csv_response[1].split(",")
    first_question = survey.survey_questions.first
    assert_equal first_question.id.to_s, first_question_from_csv[0]
    assert_equal first_question.program_id.to_s, first_question_from_csv[1]
    assert_equal first_question.question_text, first_question_from_csv[20]
    assert_equal first_question.question_type.to_s, first_question_from_csv[2]
    assert_equal first_question.default_choices.join(","), first_question_from_csv[22].delete('"')
    assert_equal first_question.position.to_s, first_question_from_csv[3]
    assert_equal first_question.required.to_s, first_question_from_csv[6]
    assert_equal first_question.help_text.to_s, first_question_from_csv[21].delete('"')
    assert_equal "attachment; filename=file__name_with_comma.csv", @response.headers["Content-Disposition"]
  end

  def test_export_questions_success_no_questions
    current_user_is :f_admin
    survey = surveys(:one)
    get :export_questions, params: { id: survey.id}
    assert_response :success
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body.split("\n")
    assert_equal_unordered SurveyQuestion.attribute_names, csv_response[0].split(",")
    assert_equal 1, csv_response.size
  end

  def test_destroy_prompt
    current_user_is :f_admin
    survey = surveys(:two)
    mm1 = mentoring_models(:mentoring_models_1)
    mm2 = mentoring_models(:mentoring_models_2)
    task_template1 = create_mentoring_model_task_template(mentoring_model_id: mm1.id)
    task_template1.action_item_id = survey.id
    task_template1.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    task_template1.save!

    get :destroy_prompt, xhr: true, params: { id: survey.id}
    assert_equal [mm1], assigns(:mentoring_models)
  end

  def test_destroy_prompt_no_task_associated
    current_user_is :f_admin
    survey = surveys(:one)
    get :destroy_prompt, xhr: true, params: { id: survey.id}
    assert_equal [], assigns(:mentoring_models)
  end

  def test_destroy_prompt_no_permission
    current_user_is :f_student
    survey = surveys(:one)
    assert_permission_denied do
      get :destroy_prompt, xhr: true, params: { id: survey.id}
    end
  end

  def test_update_answers_for_feedback_survey_no_permission
    current_user_is :f_student
    program = programs(:albers)
    survey = program.feedback_survey

    # Non-group member
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    assert_permission_denied do
      put :update_answers, xhr: true, params: { id: survey.id, feedback_group_id: groups(:mygroup).id}
    end
  end

  def test_update_answers_for_feedback_survey
    current_user_is :mkr_student
    program = programs(:albers)
    feedback_survey = program.feedback_survey
    effectiveness_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::EFFECTIVENESS)
    connectivity_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::CONNECTIVITY)

    survey_answers = {"#{effectiveness_question.id}" => "Good", "#{connectivity_question.id}" => "Phone"}
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_FLASH_MEETING_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_ENGAGEMENT_SURVEY).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMPLETE_CLOSURE_SURVEY).never
    put :update_answers, xhr: true, params: { format: :js, id: feedback_survey.id, feedback_group_id: groups(:mygroup).id, survey_answers: survey_answers}
    assert_response :success
  end

  def test_meeting_details_xls
    current_user_is @survey_manager
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    program.reload
    survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    time = 2.days.ago
    meeting = create_meeting(:recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY, :members => [members(:f_admin), members(:mkr_student)], :owner_id => members(:mkr_student).id, :program_id => programs(:albers).id, :repeats_end_date => time + 4.days, :start_time => time, :end_time => time + 5.hours, topic: "trial", description: "test")
    member_meeting = meeting.member_meetings.find_by(member_id: members(:mkr_student))
    question_id = survey.survey_questions.pluck(:id)
    assert_equal [], meeting.survey_answers
    survey.update_user_answers({question_id[0] => "Good", question_id[1] => "Phone"}, {user_id: users(:mkr_student).id, :meeting_occurrence_time => meeting.occurrences.first.start_time, member_meeting_id: member_meeting.id})

    get :show, params: { :id => survey, :format => 'xls'}
    assert_response :success

    # assert_equal assigns(:meetings).size, 1
    # assert_equal meeting.topic, assigns(:meetings)[member_meeting.id].topic
    # assert_equal meeting.description, assigns(:meetings)[member_meeting.id].description
    # assert_equal member_meeting.id, assigns(:meetings)[member_meeting.id]["member_meeting_id"]
    # assert_equal meeting.id, assigns(:meetings)[member_meeting.id]["meeting_id"]
    # assert_equal assigns(:meeting_members).size, 1
    # assert_equal assigns(:meeting_members)[meeting.id]["meeting_id"], meeting.id
    # assert_equal_unordered assigns(:meeting_members)[meeting.id]["meeting_members"].split(","), [members(:f_admin).id.to_s, members(:mkr_student).id.to_s]
    # assert_equal 2, assigns(:member_names).size
    # assert_equal assigns(:member_names)[members(:f_admin).id]["name"], members(:f_admin).name(name_only: true)
    # assert_equal assigns(:member_names)[members(:mkr_student).id]["name"], members(:mkr_student).name(name_only: true)
  end

  def test_update_for_survey_response_columns
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)

    assert_equal 6, survey.survey_response_columns.size
    assert_equal 4, survey.survey_response_columns.of_default_columns.size
    assert_equal 2, survey.survey_response_columns.of_survey_questions.size
    assert_blank survey.survey_response_columns.of_profile_questions

    profile_question = programs(:org_primary).profile_questions.select{|ques| ques.location?}.first

    assert_difference "SurveyResponseColumn.count", -1 do
      post :update, params: { :id => survey.id, :survey => {:survey_response_columns => ["default:name", "default:date", "default:roles", "profile:#{profile_question.id}", "survey:#{survey.survey_questions.first.id}"]}}
    end
    assert_redirected_to survey_responses_path(survey)

    assert_equal 5, survey.reload.survey_response_columns.size
    assert_equal 3, survey.survey_response_columns.of_default_columns.size
    assert_equal 1, survey.survey_response_columns.of_survey_questions.size
    assert_equal 1, survey.survey_response_columns.of_profile_questions.size

    assert_equal ["name", "date", "roles"], survey.survey_response_columns.of_default_columns.collect(&:key)
    assert_equal [profile_question.id.to_s], survey.survey_response_columns.of_profile_questions.collect(&:key)
    assert_equal [survey.survey_questions.first.id.to_s], survey.survey_response_columns.of_survey_questions.collect(&:key)

    assert_difference "SurveyResponseColumn.count", -2 do
      post :update, params: { :id => survey.id, :survey => {:survey_response_columns => ["default:name", "default:date", "default:roles"]}}
    end
    assert_redirected_to survey_responses_path(survey)

    assert_false survey.reload.survey_response_columns.collect(&:key).include?(survey.survey_questions.first.id.to_s)
    assert_false survey.survey_response_columns.collect(&:key).include?(profile_question.id.to_s)
    assert survey.survey_response_columns.collect(&:key).include?("name")
    assert survey.survey_response_columns.collect(&:key).include?("date")
    assert survey.survey_response_columns.collect(&:key).include?("roles")
  end

  def test_edit_columns_permission_denied
    current_user_is :no_mreq_mentor
    survey = surveys(:progress_report)

    assert_permission_denied {  get :edit_columns, xhr: true, params: { :id => survey.id }}
  end

  def test_edit_columns
    current_user_is :no_mreq_admin
    current_program_is :no_mentor_request_program

    survey = surveys(:progress_report)

    get :edit_columns, xhr: true, params: { :id => survey.id}
    assert_response :success

    assert_select "div.modal-header" do
      assert_select "h4", :text => 'Select Fields to Display'
    end
  end

  def test_reminders_only_admin_can_access
    current_user_is :f_student
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")

    assert_permission_denied do
      get :reminders, params: { id: survey.id}
    end
  end

  def test_reminders_show_only_if_survey_can_have_reminders
    current_user_is :f_admin
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    Survey.any_instance.stubs(:can_have_campaigns?).returns(false)

    assert_permission_denied do
      get :reminders, params: { id: survey.id}
    end
  end

  def test_reminders_success
    current_user_is :f_admin
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")

    get :reminders, params: { id: survey.id}
    assert_response :success
    q_count = survey.survey_questions.count
    assert_equal q_count, assigns(:questions_count)
    assert_equal survey.campaign, assigns(:campaign)
  end
end
