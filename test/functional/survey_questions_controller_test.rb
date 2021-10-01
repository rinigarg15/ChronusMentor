require_relative './../test_helper.rb'

class SurveyQuestionsControllerTest < ActionController::TestCase
  def setup
    super
    @survey_role = create_role(name: 'survey_role')
    add_role_permission(@survey_role, 'manage_surveys')
    @survey_manager = create_user(role_names: ['survey_role'])
    current_program_is :albers
    @survey = surveys(:one)
    @questions = []
    @questions << create_survey_question({survey: @survey})
    @questions << create_survey_question({survey: @survey})
    @questions << create_survey_question({
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      question_choices: "get,set,go", survey: @survey})
  end

  # INDEX ----------------------------------------------------------------------

  def test_index_only_for_admin
    current_user_is :f_student

    assert_permission_denied do
      get :index, params: { :survey_id => @survey.id}
    end
  end

  def test_index_fetches_all_questions
    current_user_is @survey_manager

    get :index, params: { :survey_id => @survey.id}
    assert_response :success
    assert_template 'index'
    assert_select 'html'
    assert_equal @survey, assigns(:survey)
    assert_equal @questions, assigns(:survey_questions)
  end

  def test_index_non_existent_survey
    current_user_is @survey_manager

    get :index, params: { survey_id: 0}
    assert_redirected_to program_root_path
    assert_equal "The survey you are trying to access doesn't exist.", flash[:error]
  end

  # NEW ------------------------------------------------------------------------

  def test_no_new_for_non_admins
    current_user_is :f_mentor
    assert_permission_denied { get :new, xhr: true, params: { :survey_id => @survey.id }}
  end

  def test_new_form
    current_user_is @survey_manager

    get :new, xhr: true, params: { :survey_id => @survey.id}
    assert_response :success
  end

  # CREATE ---------------------------------------------------------------------

  def test_create_only_for_admins
    current_user_is :f_student
    assert_permission_denied do
      post :create, xhr: true, params: { :survey_id => @survey.id, :survey_question => { }}
    end
  end

  def test_create_success
    current_user_is @survey_manager
    count = @survey.survey_questions.count

    assert_difference 'SurveyQuestion.count' do
      post :create, xhr: true, params: { survey_id: @survey.id,
        survey_question: {
          question_text: "How are you?",
          question_type: CommonQuestion::Type::SINGLE_CHOICE,
          allow_other_option: true,
          }, common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "Good"}, "102"=>{"text" => "Bad"}, "103"=>{"text" => "Okay"}}], question_choices: {new_order: "101,102,103"}}
        }
    end

    question = SurveyQuestion.last
    assert_equal @survey, question.survey
    assert_equal programs(:albers), question.program
    assert_equal "How are you?", question.question_text
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, question.question_type
    assert question.allow_other_option?
    assert_equal @survey.survey_questions[count], question
    assert_equal ["Good", "Bad", "Okay"], question.default_choices

  end

  def test_create_matrix_question
    current_user_is @survey_manager
    count = @survey.survey_questions.count

    assert_difference 'SurveyQuestion.count', 4 do
      post :create, xhr: true, params: { survey_id: @survey.id,
        survey_question: {
          question_text: "Rate on following attributes",
          question_type: CommonQuestion::Type::MATRIX_RATING,
          rating_questions: "Ability,Talent,Confidence"
        },
        common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "Good"}, "102"=>{"text" => "Bad"}, "103"=>{"text" => "Okay"}}], question_choices: {new_order: "101,102,103"}},
        matrix_question: {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Talent"}, "103"=>{"text" => "Confidence"}}], rows: {new_order: "101,102,103"} }
      }
    end

    question = SurveyQuestion.last(4).first
    assert_equal @survey, question.survey
    assert_equal programs(:albers), question.program
    assert_equal "Rate on following attributes", question.question_text
    assert_equal CommonQuestion::Type::MATRIX_RATING, question.question_type
    assert_equal ["Good", "Bad", "Okay"], question.default_choices
    assert_equal ["Ability", "Talent", "Confidence"], question.matrix_rating_question_texts
    assert_equal 3, question.rating_questions.count
  end

  # UPDATE ---------------------------------------------------------------------

  def test_no_update_for_non_admins
    current_user_is :f_mentor

    question = @questions.first
    assert_permission_denied do
      put :update, xhr: true, params: { :survey_id => @survey.id, :id => question.id,
        :survey_question => {
        :question_text => "New question",
        :question_type => CommonQuestion::Type::TEXT
      }}
    end
  end


  def test_update_success
    current_user_is @survey_manager

    question = @questions.first
    assert_equal false, question.allow_other_option?
    put :update, xhr: true, params: { survey_id: @survey.id, id: question.id,
      survey_question: {
      question_text: "New question",
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      allow_other_option: true},
      common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "a"}, "102"=>{"text" => "b"}, "103"=>{"text" => "c"}, "104"=>{"text" => "d"}}], question_choices: {new_order: "101,102,103,104"}}
    }

    assert_response :success
    assert_false assigns(:last_question_for_meeting_cancelled_or_completed_scenario)
    question.reload
    assert_equal 'New question', question.question_text
    assert_equal CommonQuestion::Type::SINGLE_CHOICE, question.question_type
    assert question.allow_other_option?
  end

  def test_update_matrix_question
    current_user_is @survey_manager

    question = @questions.first

    put :update, xhr: true, params: { survey_id: @survey.id, id: question.id,
      survey_question: {
        question_text: "Rate on following attributes",
        question_type: CommonQuestion::Type::MATRIX_RATING
      },
      common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "Good"}, "102"=>{"text" => "Bad"}, "103"=>{"text" => "Okay"}}], question_choices: {new_order: "101,102,103"}},
      matrix_question: {existing_rows_attributes: [{"101"=>{"text" => "Ability"}, "102"=>{"text" => "Talent"}, "103"=>{"text" => "Confidence"}}], rows: {new_order: "101,102,103"} }
    }

    assert_response :success
    assert_false assigns(:last_question_for_meeting_cancelled_or_completed_scenario)
    question.reload
    assert_equal "Rate on following attributes", question.question_text
    assert_equal CommonQuestion::Type::MATRIX_RATING, question.question_type
    assert_equal ["Good", "Bad", "Okay"], question.default_choices
    assert_equal ["Ability", "Talent", "Confidence"], question.matrix_rating_question_texts
    assert_equal 3, question.rating_questions.count
  end

  def test_update_failure
    current_user_is @survey_manager

    question = @questions.first
    put :update, xhr: true, params: { :survey_id => @survey.id, :id => question.id,
      :survey_question => {:question_text => ""}} # Error here

    assert_response :success
    assert_false assigns(:last_question_for_meeting_cancelled_or_completed_scenario)
    assert assigns(:common_question).errors[:question_text]
    question.reload
    assert_not_equal 'New question', question.question_text
    assert_not_equal "asda", question.question_type
  end

  def test_update_failure_conditional_question
    Survey.any_instance.stubs(:last_question_for_meeting_cancelled_or_completed_scenario?).returns(SurveyQuestion::Condition::COMPLETED)
    current_user_is @survey_manager

    question = @questions.first
    assert_equal false, question.allow_other_option?
    put :update, xhr: true, params: { survey_id: @survey.id, id: question.id,
      survey_question: {
      question_text: "New question",
      question_type: CommonQuestion::Type::SINGLE_CHOICE,
      allow_other_option: true
    },
    common_question: {existing_question_choices_attributes: [{"101"=>{"text" => "a"}, "102"=>{"text" => "b"}, "103"=>{"text" => "c"}, "104"=>{"text" => "d"}}], question_choices: {new_order: "101,102,103,104"}}}

    assert_response :success
    assert assigns(:last_question_for_meeting_cancelled_or_completed_scenario)
    question.reload
    assert_false question.question_text == 'New question'
    assert_false question.question_type == CommonQuestion::Type::SINGLE_CHOICE
    assert_false question.allow_other_option?
  end

  # DESTROY ----------------------------------------------------------------------

  def test_destroy_only_by_admin
    current_user_is :f_student
    assert_permission_denied{
      delete :destroy, xhr: true, params: { :survey_id => @survey.id, :id => @questions.first.id}
    }
  end

  def test_destroy_success
    current_user_is @survey_manager
    assert_difference 'SurveyQuestion.count', -1 do
      delete :destroy, xhr: true, params: { :survey_id => @survey.id, :id => @questions.first.id}
      assert_false assigns(:last_question_for_meeting_cancelled_or_completed_scenario)
    end
  end

  def test_destroy_failure_conditional_question
    Survey.any_instance.stubs(:last_question_for_meeting_cancelled_or_completed_scenario?).returns(SurveyQuestion::Condition::COMPLETED)
    current_user_is @survey_manager
    assert_no_difference 'SurveyQuestion.count' do
      delete :destroy, xhr: true, params: { :survey_id => @survey.id, :id => @questions.first.id}
      assert assigns(:last_question_for_meeting_cancelled_or_completed_scenario)
    end
  end

  # SORT -----------------------------------------------------------------------

  def test_sort_only_for_admin
    current_user_is :f_student

    assert_permission_denied do
      put :sort, xhr: true, params: { :survey_id => @survey.id, :new_order => [
        @questions[2].id, @questions[0].id, @questions[1].id]
      }
    end
  end

  def test_sort
    current_user_is @survey_manager

    put :sort, xhr: true, params: { :survey_id => @survey.id, :new_order => [
      @questions[2].id, @questions[0].id, @questions[1].id]
    }
    assert_response :success
    assert_equal [@questions[2], @questions[0], @questions[1]],
      @survey.survey_questions.reload
  end

  # SHOW -----------------------------------------------------------------------

  def test_show
    current_user_is @survey_manager

    question = @questions.first
    answers = question.survey_answers.select([:id, :user_id, :answer_text, :updated_at, :common_question_id]).order(:updated_at)
    get :show, xhr: true, params: { :survey_id => @survey.id, :id => question.id}
    assert_response :success
    assert_equal question, assigns(:question)
    assert_equal answers, assigns(:answers)
  end

  def test_report_with_filter_params
    current_user_is :no_mreq_admin

    survey = surveys(:progress_report)
    question = common_questions(:q3_name)
    pq = programs(:org_primary).profile_questions.find_by(question_text: 'Location')

    get :show, xhr: true, params: { :survey_id => survey.id, :id => question.id, :newparams => {}}
    assert_response :success
    assert_equal 2, assigns(:answers).size

    newparams = {"0"=>{"field"=>"column#{pq.id}", "operator"=>"eq", "value"=>"Delhi"}}
    get :show, xhr: true, params: { :survey_id => survey.id, :id => question.id, :newparams => newparams}
    assert_response :success
    assert_equal 1, assigns(:answers).size
  end

  def test_show_failure
    current_user_is :f_student
    question = @questions.first
    assert_permission_denied do
      get :show, params: { :survey_id => @survey.id, :id => question.id}
    end
  end

  def test_engagement_survey_permission_denied_if_ongoing_disabled
    current_user_is  :f_admin
    program = programs(:albers)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    program.reload
    assert_false program.ongoing_mentoring_enabled?
    survey = program.surveys.of_engagement_type.first

    assert_permission_denied do
      get :index, params: { :survey_id => survey.id}
    end

    assert_permission_denied do
      get :show, params: { :survey_id => survey.id, :id => survey.survey_questions.first.id}
    end

    assert_permission_denied do
      delete :destroy, xhr: true, params: { :survey_id => survey.id, :id => survey.survey_questions.first.id}
    end

    assert_permission_denied do
      post :create, xhr: true, params: { survey_id: survey.id,
        survey_question: {
          question_text: "How are you?",
          question_type: CommonQuestion::Type::SINGLE_CHOICE,
          allow_other_option: true
        },
        common_question: { existing_question_choices_attributes: [{"101"=>{"text" => "Good"}, "102"=>{"text" => "Bad"}, "103"=>{"text" => "Okay"}}], question_choices: {new_order: "101,102,103"} }
      }
    end

    assert_permission_denied do
      get :new, xhr: true, params: { :survey_id => survey.id}
    end

    assert_permission_denied do
      put :update, xhr: true, params: { :survey_id => survey.id, :id => survey.survey_questions.first.id,
        :survey_question => {
        :question_text => "New question",
        :question_type => CommonQuestion::Type::TEXT
      }
    }
    end
  end
end