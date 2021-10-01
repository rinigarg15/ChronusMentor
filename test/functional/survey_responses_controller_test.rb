require_relative './../test_helper.rb'

class SurveyResponsesControllerTest < ActionController::TestCase

  def setup
    super
    @survey = surveys(:progress_report)
    @question1 = common_questions(:q3_name)
    @question2 = common_questions(:q3_from)
    @profile_question = programs(:org_primary).profile_questions.select{|ques| ques.location?}.first
    @mentor_answer_one = common_answers(:q3_name_answer_1)
    @mentor_answer_two = common_answers(:q3_from_answer_1)
    @student_answer_one = common_answers(:q3_name_answer_2)
    @student_answer_two = common_answers(:q3_from_answer_2)
    @response1 = {:user => users(:no_mreq_mentor), :group => groups(:no_mreq_group), connection_role_id: nil, :date => @mentor_answer_one.last_answered_at, :answers => {@mentor_answer_one.common_question_id => @mentor_answer_one.answer_text, @mentor_answer_two.common_question_id => @mentor_answer_two.answer_text}, :profile_answers => {@profile_question.id =>"Chennai, Tamil Nadu, India"}}
    @response2 = {:user => users(:no_mreq_student), :group => groups(:no_mreq_group), connection_role_id: nil, :date => @student_answer_one.last_answered_at, :answers => {@student_answer_one.common_question_id => @student_answer_one.answer_text, @student_answer_two.common_question_id => @student_answer_two.answer_text}, :profile_answers => {@profile_question.id => "New Delhi, Delhi, India"}}
    @survey.survey_response_columns.create!(:survey_id => @survey.id, :position => @survey.survey_response_columns.collect(&:position).max+1, :profile_question_id => @profile_question.id, :ref_obj_type => SurveyResponseColumn::ColumnType::USER)
  end

  def test_show_permission_denied
    User.any_instance.stubs(:can_manage_surveys?).returns(false)
    surveys(:one).stubs(:engagement_survey?).returns(false)
    current_user_is :f_admin

    create_survey_answer
    assert_permission_denied do
      get :show, params: { :survey_id => surveys(:one).id, :id => surveys(:one).survey_answers.first.response_id}
    end
  end

  def test_show_permission_denied_engagement_survey
    User.any_instance.stubs(:can_manage_surveys?).returns(false)
    surveys(:one).stubs(:engagement_survey?).returns(true)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    current_user_is :f_admin

    create_survey_answer
    assert_permission_denied do
      get :show, params: { :survey_id => surveys(:one).id, :id => surveys(:one).survey_answers.first.response_id}
    end
  end

  def test_show_success
    User.any_instance.stubs(:can_manage_surveys?).returns(true)
    surveys(:one).stubs(:engagement_survey?).returns(false)
    current_user_is :f_student

    create_survey_answer
    get :show, params: { :survey_id => surveys(:one).id, :id => surveys(:one).survey_answers.first.response_id}
    assert_response :success
    assert_equal surveys(:one), assigns(:survey)

    surveys(:one).stubs(:engagement_survey?).returns(true)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    get :show, params: { :survey_id => surveys(:one), :id => surveys(:one).survey_answers.first.response_id}
    assert_response :success
  end

  def test_index_permission_denied
    User.any_instance.stubs(:can_manage_surveys?).returns(false)
    surveys(:one).stubs(:engagement_survey?).returns(false)
    current_user_is :f_admin

    assert_permission_denied do
      get :index, params: { :survey_id => surveys(:one).id}
    end
  end

  def test_index_permission_denied_engagement_survey
    User.any_instance.stubs(:can_manage_surveys?).returns(false)
    surveys(:one).stubs(:engagement_survey?).returns(true)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    current_user_is :f_admin

    assert_permission_denied do
      get :index, params: { :survey_id => surveys(:one).id}
    end
  end

  def test_index_success
    User.any_instance.stubs(:can_manage_surveys?).returns(true)
    surveys(:one).stubs(:engagement_survey?).returns(false)
    current_user_is :f_student

    SurveyResponsesDataService.any_instance.stubs(:total_count).returns(12)
    get :index, params: { :survey_id => surveys(:one).id}
    assert_response :success
    assert_equal surveys(:one), assigns(:survey)
    assert_equal 12, assigns(:total_count)
    assert_equal 10, assigns(:entries_in_page)

    SurveyResponsesDataService.any_instance.stubs(:total_count).returns(3)
    surveys(:one).stubs(:engagement_survey?).returns(true)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    get :index, params: { :survey_id => surveys(:one)}
    assert_response :success
    assert_equal 3, assigns(:total_count)
    assert_equal 3, assigns(:entries_in_page)
  end

  def test_data_permission_denied
    User.any_instance.stubs(:can_manage_surveys?).returns(false)
    surveys(:one).stubs(:engagement_survey?).returns(false)
    create_survey_answer
    current_user_is :f_admin


    assert_permission_denied do
      get :data, params: { :survey_id => surveys(:one).id}
    end
  end

  def test_data_permission_denied_engagement_survey
    User.any_instance.stubs(:can_manage_surveys?).returns(false)
    surveys(:one).stubs(:engagement_survey?).returns(true)
    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    create_survey_answer
    current_user_is :f_admin

    assert_permission_denied do
      get :data, params: { :survey_id => surveys(:one).id}
    end
  end

  # def test_filter_by_name
  #	  refresh_es_index(User)
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"name", "operator"=>"eq", "value"=>"Student"}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {2 => @response2}
  # end

  # def test_filter_by_date
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter =>{"logic" => "and", "filters" => {"0"=>{"logic" => "and", "filters"=> {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at.beginning_of_day}"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at.end_of_day + 2.days}"}}}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}


  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter =>{"logic" => "and", "filters" => {"0"=>{"logic" => "and", "filters"=> {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at.beginning_of_day}"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at + 1.day}"}}}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {1 => @response1}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter =>{"logic" => "and", "filters" => {"0"=>{"logic" => "and", "filters"=> {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at + 1.day}"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at.end_of_day + 2.day}"}}}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {2 => @response2}
  # end
  
  # def test_survey_specific_filter
  #	  refresh_es_index(Group)
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"surveySpecific", "operator"=>"eq", "value"=>"#{groups(:no_mreq_group).name}"}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}
  # end

  # def test_survey_question_filter
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"answers#{@question1.id}", "operator"=>"eq", "value"=>"#{@mentor_answer_one.answer_text}"}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {1 => @response1}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"answers#{@question1.id}", "operator"=>"eq", "value"=>"#{@student_answer_one.answer_text}"}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {2 => @response2}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"answers#{@question1.id}", "operator"=>"eq", "value"=>"remove"}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}
  # end

  # def test_filter_on_profile_answers
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"column#{@profile_question.id}", "operator"=>"eq", "value"=>"Chennai"}}}}

  #   assert_equal assigns(:responses), {1 => @response1}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"column#{@profile_question.id}", "operator"=>"eq", "value"=>"Delhi"}}}}
    
  #   assert_equal assigns(:responses), {2 => @response2}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"column#{@profile_question.id}", "operator"=>"eq", "value"=>"India"}}}}

  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}
  # end

  # def test_filters_combination
  #	  refresh_es_index(User)
  #	  refresh_es_index(Group)
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"surveySpecific", "operator"=>"eq", "value"=>"#{groups(:no_mreq_group).name}"}, "1" => {"field"=>"name", "operator"=>"eq", "value"=>"Mentor"}}}}
  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter => {"logic" => "and", "filters" =>{"0"=>{"field"=>"surveySpecific", "operator"=>"eq", "value"=>"#{groups(:no_mreq_group).name}"}, "1" => {"field"=>"name", "operator"=>"eq", "value"=>"Mentor"}, "2" => {"logic" => "and", "filters" => {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at + 1.day}"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at.end_of_day + 2.day}"}}}, "3" => {"field"=>"answers#{@question1.id}", "operator"=>"eq", "value"=>"#{@student_answer_one.answer_text}"}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {2 => @response2}
  # end

  # def test_sort_on_sender_name
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"name", "dir"=>"asc"}}}

  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}

  #   get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"name", "dir"=>"desc"}}}
    
  #   assert_equal assigns(:responses), {2 => @response2, 1 => @response1}
  # end

  def test_filter_by_user_roles_and_name
    current_user_is :no_mreq_admin

    survey = surveys(:progress_report)

    get :data, params: { survey_id: survey.id, format: :json, filter: { "logic" => "and", "filters" => { "0" => {"field"=>"roles", "operator"=>"eq", "value"=>"student" } , "1" => {"field"=>"name", "operator"=>"eq", "value" => "No Mentor Request Student" } } }}
    assert_response :success
    survey = assigns(:survey)
    assert_equal 4, survey.survey_answers.count
    responses = assigns(:responses)
    user = responses[2][:user]
    group = responses[2][:group]
    assert_equal "student", group.membership_of(user).role.name
    assert_equal "No Mentor Request Student", user.name
  end

  def test_sort_on_user_roles
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)

    common_answers(:q3_name_answer_1).update_column(:connection_membership_role_id, survey.program.get_role("mentor").id)
    common_answers(:q3_name_answer_2).update_column(:connection_membership_role_id, survey.program.get_role("student").id)
    reindex_documents(updated: [common_answers(:q3_name_answer_1), common_answers(:q3_name_answer_2)])

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"roles", "dir"=>"desc"}}}
    assert_equal [2, 1], assigns(:responses).keys

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"roles", "dir"=>"asc"}}}
    assert_equal [1, 2], assigns(:responses).keys
  end

  def test_sort_on_response_date
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)
    survey.stubs(:engagement_survey?).returns(true)

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"date", "dir"=>"asc"}}}

    assert_equal assigns(:responses), {1 => @response1, 2 => @response2}

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"date", "dir"=>"desc"}}}
    
    assert_equal assigns(:responses), {2 => @response2, 1 => @response1}
  end

  def test_sort_on_survey_answers
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)
    survey.stubs(:engagement_survey?).returns(true)

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"answers#{@question1.id}", "dir"=>"asc"}}}

    assert_equal assigns(:responses), {2 => @response2, 1 => @response1}

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"answers#{@question1.id}", "dir"=>"desc"}}}
    
    assert_equal assigns(:responses), {1 => @response1, 2 => @response2}
  end

  def test_sort_on_profile_answers
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)
    survey.stubs(:engagement_survey?).returns(true)

    expected_responses = { 1 => @response1, 2 => @response2 }
    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"column#{@profile_question.id}", "dir"=>"asc"}}}
    assert_equal expected_responses, assigns(:responses)

    get :data, params: { :survey_id => survey.id, :format => :json, :sort => {"0"=>{"field"=>"column#{@profile_question.id}", "dir"=>"desc"}}}
    assert_equal expected_responses, assigns(:responses)
  end

  def test_show_action
    current_user_is :f_admin
    survey = surveys(:two)

    ans1 = SurveyAnswer.create!({:answer_text => "My answer one", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => survey.survey_questions.first})
    ans2 = SurveyAnswer.create!({:answer_text => "Smallville", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => survey.survey_questions.last})

    get :show, params: { :id => 1, :survey_id => survey.id}

    assert_response :success
    survey_answers = survey.survey_answers.where(:response_id => 1)
    assert_equal assigns(:survey), survey
    assert_equal assigns(:user), users(:f_student)
    assert_equal assigns(:survey_questions), survey.survey_questions
    assert_equal assigns(:survey_answers), survey_answers.group_by(&:common_question_id)
    assert_equal assigns(:submitted_at), survey_answers.collect(&:last_answered_at).max
  end

  def test_export_as_xls
    current_user_is :f_admin
    survey = surveys(:two)

    ans1 = SurveyAnswer.create!({:answer_text => "My answer one", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => survey.survey_questions.first})
    ans2 = SurveyAnswer.create!({:answer_text => "Smallville", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => survey.survey_questions.last})

    get :export_as_xls, params: { :id => 1, :survey_id => survey.id, :format => :xls}

    assert_response :success

    survey_answers = survey.survey_answers.where(:response_id => 1)
    assert_equal assigns(:survey), survey
    assert_equal assigns(:user), users(:f_student)
    assert_equal assigns(:survey_questions), survey.survey_questions
    assert_equal assigns(:survey_answers), survey_answers.group_by(&:common_question_id)
    assert_equal assigns(:submitted_at), survey_answers.collect(&:last_answered_at).max
    assert_match "User Role", response.body
    assert_equal "Student", assigns(:user_roles)
  end

  def test_export_as_xls_permission_denied
    current_user_is :f_mentor
    survey = surveys(:two)

    ans1 = SurveyAnswer.create!({:answer_text => "My answer one", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => survey.survey_questions.first})
    ans2 = SurveyAnswer.create!({:answer_text => "Smallville", :user => users(:f_student), :response_id => 1, last_answered_at: Time.now.utc, :survey_question => survey.survey_questions.last})

    assert_false users(:f_mentor).can_manage_surveys?

    assert_permission_denied do
      get :export_as_xls, params: { :id => 1, :survey_id => survey.id, :format => :xls}
    end
  end

  def test_select_all_ids_permission_denied
    current_user_is :no_mreq_student
    survey = surveys(:progress_report)

    assert_permission_denied do
      get :select_all_ids, params: { :survey_id => survey.id}
    end
  end

  def test_select_all_ids_success
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)
    get :select_all_ids, params: { :survey_id => survey.id, :filter => {"filters" =>{"0"=>{"field"=>"answers#{@question1.id}", "operator"=>"eq", "value"=>"remove"}}}}
    assert_response :success
  end

  def test_select_all_with_multi_choice_questions
    current_user_is :no_mreq_admin
    mentor = users(:no_mreq_mentor)
    student = users(:no_mreq_student)
    survey = surveys(:progress_report)
    survey_question = create_survey_question(question_type: CommonQuestion::Type::MULTI_CHOICE, question_text: "How was the mentoring", question_info: "Very Good, Good, Average, Poor", survey: survey, program: mentor.program)
    choices_hash = survey_question.question_choices.index_by(&:text)
    mentor_answer = create_survey_answer(answer_value: {answer_text: "Poor", question: survey_question}, survey_question: survey_question, user: mentor)
    student_answer = create_survey_answer(answer_value: {answer_text: "Good", question: survey_question}, survey_question: survey_question, user: student, response_id: 2)

    get :select_all_ids, params: { :survey_id => survey.id, :filter => { "filters" => { "0"=> { "field" => "answers#{survey_question.id}", "operator" => "eq", "value" => "#{choices_hash['Good'].id},#{choices_hash['Average'].id}"}}}}
    assert_response :success
    assert_equal [[student_answer.response_id.to_s], 1], YAML.load(response.body).values

    get :select_all_ids, params: { :survey_id => survey.id, :filter => { "filters" => { "0"=> { "field" => "answers#{survey_question.id}", "operator" => "eq", "value" => "#{choices_hash['Good'].id},#{choices_hash['Poor'].id}"}}}}
    assert_response :success
    response_hash = YAML.load(response.body)
    assert_equal_unordered [mentor_answer.response_id.to_s, student_answer.response_id.to_s], response_hash["ids"]
    assert_equal 2, response_hash["total_count"]

    get :select_all_ids, params: { :survey_id => survey.id, :filter => { "filters" => { "0"=> { "field" => "answers#{survey_question.id}", "operator" => "eq", "value" => "#{choices_hash['Average'].id}"}}}}
    assert_response :success
    assert_equal [[], 0], YAML.load(response.body).values
  end

  def test_download_permission_denied
    current_user_is :no_mreq_student
    survey = surveys(:progress_report)
    response_ids = survey.survey_answers.pluck(:response_id).uniq.join(',')

    assert_permission_denied do
      post :download, params: { :survey_id => survey.id, :response_ids => response_ids, :format => 'xls', :responses_sort_field => "date", :responses_sort_dir =>"desc"}
    end
  end

  def test_download_success
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)
    response_ids = survey.survey_answers.pluck(:response_id).uniq.join(',')

    post :download, params: { :survey_id => survey.id, :response_ids => response_ids, :format => 'xls', :responses_sort_field => "date", :responses_sort_dir =>"desc"}
    assert_response :success
    assert_match /Name.*Email.*Date of response.*Mentoring Connection.*Task.*User Role/, response.body

    name_column = survey.survey_response_columns.find_by(column_key: SurveyResponseColumn::Columns::SenderName)
    role_column = survey.survey_response_columns.find_by(column_key: SurveyResponseColumn::Columns::Roles)
    role_position = role_column.position

    role_column.update_column(:position, name_column.position)
    name_column.update_column(:position, role_position)

    post :download, params: { :survey_id => survey.id, :response_ids => response_ids, :format => 'xls', :responses_sort_field => "date", :responses_sort_dir =>"desc"}
    assert_response :success
    assert_match /User Role.*Date of response.*Mentoring Connection.*Task.*Name.*Email/, response.body
  end

  def test_email_report_popup_permission_denied
    current_user_is :no_mreq_student
    survey = surveys(:progress_report)

    assert_permission_denied do
      get :email_report_popup, params: { :survey_id => survey.id}
    end
  end

  def test_email_report_popup_success
    current_user_is :no_mreq_admin
    survey = surveys(:progress_report)

    get :email_report_popup, params: { :survey_id => survey.id}
    assert_response :success
  end  

  def test_email_with_program
    ewp = SurveyResponsesController::EmailWithProgram.new('a', 'b')
    assert_equal 'a', ewp.email
    assert_equal 'b', ewp.program
  end

  # def test_invalid_date_filter
  #   current_user_is :no_mreq_admin
  #   survey = surveys(:progress_report)
  #   survey.stubs(:engagement_survey?).returns(true)

  #   get :data, params: { :survey_id => survey.id, :format => :json, :filter =>{"logic" => "and", "filters" => {"0"=>{"logic" => "and", "filters"=> {"0"=>{"field"=>"date", "operator"=>"eq", "value"=>"null"}, "1"=>{"field"=>"date", "operator"=>"eq", "value"=>"#{@mentor_answer_two.last_answered_at + 1.day}"}}}}}}

  #   assert_response :success
  #   assert_equal assigns(:responses), {1 => @response1, 2 => @response2}
  # end
end