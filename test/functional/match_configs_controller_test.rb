require_relative './../test_helper.rb'

class MatchConfigsControllerTest < ActionController::TestCase
  def setup
    super
    @program = programs(:albers)
    prof_q = create_question(:role_names => [RoleConstants::MENTOR_NAME])
    @mentor_question = prof_q.role_questions.first    
    @student_question = prof_q.role_questions.new
    @student_question.role = @program.get_role(RoleConstants::STUDENT_NAME)
    @student_question.save!
    current_program_is :albers
  end

  def test_only_super_user_can_access
    current_user_is :f_admin

    get :index
    assert_redirected_to super_login_path
  end

  def test_index_for_superadmin
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)

    mc = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1
    )

    get :index
    assert_select 'li.active', text: 'Manage'
  end

  def test_play_for_superadmin
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)

    mc = program.match_configs.create(
      student_question: role_questions(:role_questions_1),
      mentor_question: role_questions(:role_questions_1),
      operator: MatchConfig::Operator::lt,
      threshold: 0.1
    )

    get :play
    assert_equal program.match_configs.order("weight DESC").all, assigns(:match_configs)
  end

  def test_only_super_user_can_access_for_compute_fscore
    get :compute_fscore, xhr: true, params: { :format => :json, :config_id => "1"}
    assert_redirected_to super_login_path
  end

  def test_compute_fscore_zero
    login_as_super_user
    get :compute_fscore, xhr: true, params: { :format => :json}
    assert_response :success
    assert_equal 0.0, JSON.parse(response.body)["score"]
  end

  def test_compute_fscore_nonzero
    program = programs(:albers)
    prof_q = create_profile_question(:organization => programs(:org_primary))
    mentor_question = create_role_question(:program => program, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    student_question = create_role_question(:program => program, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)
    MatchConfig.create!(
        :program => program,
        :mentor_question => mentor_question,
        :student_question => student_question)

    login_as_super_user
    get :compute_fscore, xhr: true, params: { :format => :json, :config_id => MatchConfig.first.id, :sq_value => "ABC", :mq_value => "ABC", :sq_type => ProfileQuestion::Type::SINGLE_CHOICE, :mq_type => ProfileQuestion::Type::SINGLE_CHOICE}
    assert_response :success
    assert_equal 1.0, JSON.parse(response.body)["score"]
  end

  def test_compute_fscore_for_downcase
    program = programs(:albers)
    prof_q = create_profile_question(:organization => programs(:org_primary))
    mentor_question = create_role_question(:program => program, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    student_question = create_role_question(:program => program, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)
    MatchConfig.create!(
        :program => program,
        :mentor_question => mentor_question,
        :student_question => student_question)

    login_as_super_user
    get :compute_fscore, xhr: true, params: { :format => :json, :config_id => MatchConfig.first.id, :sq_value => "abc", :mq_value => "ABC", :sq_type => ProfileQuestion::Type::SINGLE_CHOICE, :mq_type => ProfileQuestion::Type::SINGLE_CHOICE}
    assert_response :success
    assert_equal 1.0, JSON.parse(response.body)["score"]
  end

  def test_compute_fscore_for_array_downcase
    program = programs(:albers)
    prof_q = create_profile_question(:organization => programs(:org_primary))
    mentor_question = create_role_question(:program => program, :role_names => [RoleConstants::MENTOR_NAME], :profile_question => prof_q)
    student_question = create_role_question(:program => program, :role_names => [RoleConstants::STUDENT_NAME], :profile_question => prof_q)
    MatchConfig.create!(
        :program => program,
        :mentor_question => mentor_question,
        :student_question => student_question)

    login_as_super_user
    get :compute_fscore, xhr: true, params: { :format => :json, :config_id => MatchConfig.first.id, :sq_value => "[\"abc\", \"def\"]", :mq_value => "[\"ABC\", \"DEF\"]", :sq_type => ProfileQuestion::Type::SINGLE_CHOICE, :mq_type => ProfileQuestion::Type::SINGLE_CHOICE}
    assert_response :success
    assert_equal 1.0, JSON.parse(response.body)["score"]
  end

  def test_question_template
    login_as_super_user
    get :question_template, xhr: true, params: { :type => ProfileQuestion::Type::SINGLE_CHOICE}
    assert_response :success
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, assigns(:type)
    assert_match /select/, response.body
  end

  def test_create_matchable_field
    current_user_is :f_admin
    login_as_super_user

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
        :mentor_question_id => @mentor_question.id.to_s,
        :student_question_id => @student_question.id.to_s,
        :weight => "0.25"}}
    end

    pair = assigns(:match_config)
    assert_equal MatchConfig.last, pair
    assert_equal @mentor_question, pair.mentor_question
    assert_equal @student_question, pair.student_question
    assert_equal 0.25, pair.weight
    assert_equal pair.matching_type, MatchConfig::MatchingType::DEFAULT
    assert_nil pair.matching_details_for_display
    assert_nil pair.matching_details_for_matching
  end

  def test_create_with_incompatible_question_choices
    current_user_is :f_admin
    login_as_super_user

    choice_based_profile_question = create_question(question_type: ProfileQuestion::Type::SINGLE_CHOICE, question_text: "pick one")
    education_based_profile_question = create_question(question_type: ProfileQuestion::Type::EDUCATION, question_text: "Educatiion")
    mentor_question = choice_based_profile_question.role_questions.first
    student_question = education_based_profile_question.role_questions.first

    assert_no_difference "MatchConfig.count" do
      post :create, params: {
        match_config: {
          mentor_question_id: mentor_question.id.to_s,
          student_question_id: student_question.id.to_s,
          weight: "0.25"
        }
      }
    end
    assert_equal "activerecord.custom_errors.answer.invalid_question_choice".translate, assigns(:match_config).errors.full_messages.to_sentence
  end

  def test_edit_with_choice_questions
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)
    student_choice_questions = program.choice_based_questions_ids_for_role([RoleConstants::STUDENT_NAME])
    mentor_choice_questions = program.choice_based_questions_ids_for_role([RoleConstants::MENTOR_NAME])
    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "alpha, beta, gamma")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!
    mc = MatchConfig.create!(
        :program => program,
        :mentor_question => mentor_question,
        :student_question => student_question)

    Program.any_instance.stubs(:show_match_label_questions_ids_for_role).with([RoleConstants::STUDENT_NAME]).returns("student location question ids")
    Program.any_instance.stubs(:show_match_label_questions_ids_for_role).with([RoleConstants::MENTOR_NAME]).returns("mentor location question ids")

    get :edit, params: { id: mc.id}
    assert_equal student_choice_questions + [student_question.id], assigns(:mentee_single_ordered_question_ids)
    assert_equal mentor_choice_questions  + [mentor_question.id], assigns(:mentor_single_ordered_question_ids)
    assert_equal "student location question ids", assigns(:mentee_single_show_match_label_question_ids)
    assert_equal "mentor location question ids", assigns(:mentor_single_show_match_label_question_ids)
  end

  def test_new_with_choice_questions
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)
    student_choice_questions = program.choice_based_questions_ids_for_role([RoleConstants::STUDENT_NAME])
    mentor_choice_questions = program.choice_based_questions_ids_for_role([RoleConstants::MENTOR_NAME])
    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "alpha, beta, gamma")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!

    Program.any_instance.stubs(:show_match_label_questions_ids_for_role).with([RoleConstants::STUDENT_NAME]).returns("student location question ids")
    Program.any_instance.stubs(:show_match_label_questions_ids_for_role).with([RoleConstants::MENTOR_NAME]).returns("mentor location question ids")
    
    get :new
    assert_equal student_choice_questions + [student_question.id], assigns(:mentee_single_ordered_question_ids)
    assert_equal mentor_choice_questions + [mentor_question.id], assigns(:mentor_single_ordered_question_ids)
    assert_equal "student location question ids", assigns(:mentee_single_show_match_label_question_ids)
    assert_equal "mentor location question ids", assigns(:mentor_single_show_match_label_question_ids)
  end

  def test_set_matching_with_question_which_has_brackets_in_choices
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)
    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "alpha(1), beta(2), gamma(3)")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!
    matching_hash = {"alpha1" => [["beta2", "gamma3"], ["alpha1"]], "beta2" => [[]], "gamma3" => [["alpha1"]], "non_existing_choice4" => [["non_existing_choice2"]]}

    mentee_selected_choices = ["alpha(1)", "beta(2)", "gamma(3)/~alpha(1)", "non_existing_choice(4)"]
    mentor_selected_choices = ["beta(2)/~gamma(3)", "", "alpha(1)", "non_existing_choice(2)"]

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
          :mentor_question_id => mentor_question.id.to_s,
          :student_question_id => student_question.id.to_s,
          :weight => "0.25",
          :matching_type => MatchConfig::MatchingType::SET_MATCHING, :mentee_choice => mentee_selected_choices, :mentor_choices => mentor_selected_choices}}
    end
    pair = assigns(:match_config)
    assert_equal pair.matching_type, MatchConfig::MatchingType::SET_MATCHING
    assert_equal pair.matching_details_for_display, Hash[mentee_selected_choices.zip mentor_selected_choices]
    assert_false pair.show_match_label
    assert_nil pair.prefix
    assert_equal matching_hash, pair.matching_details_for_matching
  end

  def test_set_matching_with_multi_sets
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)
    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "alpha, beta, gamma")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!
    matching_hash = {"alpha" => [["alpha", "beta", "gamma"], ["beta"]], "beta" => [[], ["gamma"]], "gamma" => [["alpha"]]}

    mentee_selected_choices = ["alpha", "beta", "gamma", "alpha", "beta"]
    mentor_selected_choices = ["alpha/~beta/~gamma", "", "alpha", "beta", "gamma"]

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
          :mentor_question_id => mentor_question.id.to_s,
          :student_question_id => student_question.id.to_s,
          :weight => "0.25",
          :matching_type => MatchConfig::MatchingType::SET_MATCHING, :mentee_choice => mentee_selected_choices, :mentor_choices => mentor_selected_choices}}
    end
    pair = assigns(:match_config)
    assert_equal MatchConfig::MatchingType::SET_MATCHING, pair.matching_type
    expected_hash = {"alpha"=>"alpha/~beta/~gamma!---!beta", "beta"=>"!---!gamma", "gamma"=>"alpha"}
    assert_equal expected_hash, pair.matching_details_for_display
    assert_false pair.show_match_label
    assert_nil pair.prefix
    assert_equal matching_hash, pair.matching_details_for_matching
  end

  def test_create_matching_details
    current_user_is :f_admin
    login_as_super_user

    program = programs(:albers)
    prof_q = create_question(:question_type => ProfileQuestion::Type::SINGLE_CHOICE, :question_text => "Pick one", :question_info => "alpha, beta, gamma")
    student_question = prof_q.role_questions.first
    mentor_question = prof_q.role_questions.new
    mentor_question.role = program.get_role(RoleConstants::MENTOR_NAME)
    mentor_question.save!
    matching_hash = {"alpha" => [["beta", "gamma"]], "beta" => [[]], "gamma" => [["alpha"]]}

    mentee_selected_choices = ["alpha", "beta", "gamma"]
    mentor_selected_choices = ["beta/~gamma", "", "alpha"]

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
          :mentor_question_id => mentor_question.id.to_s,
          :student_question_id => student_question.id.to_s,
          :weight => "0.25",
          :matching_type => MatchConfig::MatchingType::SET_MATCHING, :mentee_choice => mentee_selected_choices, :mentor_choices => mentor_selected_choices,
          prefix: "abc", show_match_label: true}}
    end
    pair = assigns(:match_config)
    assert_equal pair.matching_type, MatchConfig::MatchingType::SET_MATCHING
    assert_equal pair.matching_details_for_display, Hash[mentee_selected_choices.zip mentor_selected_choices]
    assert_equal pair.matching_details_for_matching, matching_hash
    assert pair.show_match_label
    assert_equal "abc", pair.prefix

    assert_no_difference 'MatchConfig.count' do
      post :update, params: { :id => pair.id, :match_config => { :matching_type => MatchConfig::MatchingType::DEFAULT }}
    end
    pair = assigns(:match_config)
    assert_equal pair.matching_type, MatchConfig::MatchingType::DEFAULT
    assert_nil pair.matching_details_for_matching
    assert_nil pair.matching_details_for_display

    mentee_selected_choices = ["alpha/~beta", "gamma"]
    mentor_selected_choices = ["beta/~gamma", "alpha"]
    matching_hash = {"alpha" =>[["beta", "gamma"]], "beta" =>[["beta", "gamma"]], "gamma" => [["alpha"]]}

    assert_no_difference 'MatchConfig.count' do
      post :update, params: { :id => pair.id, :match_config => {
                    :mentor_question_id => mentor_question.id.to_s, :student_question_id => student_question.id.to_s, :weight => "0.25",
                    :matching_type => MatchConfig::MatchingType::SET_MATCHING , 
                    :mentee_choice => mentee_selected_choices, :mentor_choices => mentor_selected_choices}}
    end
    pair = assigns(:match_config)
    assert_equal MatchConfig::MatchingType::SET_MATCHING, pair.matching_type
    assert_equal pair.matching_details_for_display, Hash[mentee_selected_choices.zip mentor_selected_choices]
    assert_equal pair.matching_details_for_matching, matching_hash
  end

  def test_update_match_field_for_location_question
    current_user_is :f_admin
    login_as_super_user

    mentor_loc_ques = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|ques| ques.profile_question.location?}.first
    student_loc_ques = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|ques| ques.profile_question.location?}.first
    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
        :mentor_question_id => mentor_loc_ques.id.to_s,
        :student_question_id => student_loc_ques.id.to_s,
        :weight => "0.3"}}
    end
    pair = assigns(:match_config)
    assert_equal MatchConfig.last, pair
    assert_equal mentor_loc_ques, pair.mentor_question
    assert_equal student_loc_ques, pair.student_question
    assert_equal 0.3, pair.weight
  end

  def test_update_match_field_for_education_question
    current_user_is :f_admin
    login_as_super_user

    mentor_edu_ques = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.question_text =="Education"}[0]
    student_edu_ques = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question.question_text =="Education"}[0]

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
        :mentor_question_id => mentor_edu_ques.id.to_s,
        :student_question_id => student_edu_ques.id.to_s,
        :weight => "0.5"}}
    end
    pair = assigns(:match_config)
    assert_equal MatchConfig.last, pair
    assert_equal mentor_edu_ques, pair.mentor_question
    assert_equal student_edu_ques, pair.student_question
    assert_equal 0.5, pair.weight
  end

  def test_update_match_field_for_experience_question
    current_user_is :f_admin
    login_as_super_user

    mentor_exp_ques = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.question_text =="Work"}[0]
    student_exp_ques = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question.question_text =="Work"}[0]

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
        :mentor_question_id => mentor_exp_ques.id.to_s,
        :student_question_id => student_exp_ques.id.to_s,
        :weight => "0.8"}}
    end
    pair = assigns(:match_config)
    assert_equal MatchConfig.last, pair
    assert_equal mentor_exp_ques, pair.mentor_question
    assert_equal student_exp_ques, pair.student_question
    assert_equal 0.8, pair.weight
  end

  def test_update_an_existing_match_config
    current_user_is :f_admin
    login_as_super_user

    mentor_exp_ques = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.question_text =="Work"}[0]
    student_exp_ques = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question.question_text =="Work"}[0]

    create_mentor_question(:organization => programs(:org_primary), :question_type => ProfileQuestion::Type::EXPERIENCE, :question_text => "Work Experience")
    mentor_exp_ques_2 = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.question_text =="Work Experience"}[0]

      post :create, params: { :match_config => {
        :mentor_question_id => mentor_exp_ques.id.to_s,
        :student_question_id => student_exp_ques.id.to_s,
        :weight => "0.8"}}

    pair = assigns(:match_config)
    
    assert_no_difference 'MatchConfig.count' do
      post :update, params: { :id => pair.id, :match_config => {
         :mentor_question_id => mentor_exp_ques_2.id.to_s
      }}
    end
    
    pair_updated = assigns(:match_config)
    assert_equal MatchConfig.last, pair_updated
    assert_equal mentor_exp_ques_2, pair_updated.mentor_question
    assert_equal student_exp_ques, pair_updated.student_question
    assert_equal 0.8, pair_updated.weight.round(1)
  end

  def test_destroy_an_existing_match_config
    current_user_is :f_admin
    login_as_super_user

    mentor_exp_ques = programs(:albers).role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.question_text =="Work"}[0]
    student_exp_ques = programs(:albers).role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question.question_text =="Work"}[0]

    assert_difference 'MatchConfig.count' do
      post :create, params: { :match_config => {
        :mentor_question_id => mentor_exp_ques.id.to_s,
        :student_question_id => student_exp_ques.id.to_s,
        :weight => "0.8"}}
    end

    pair = assigns(:match_config)
    
    assert_difference 'MatchConfig.count', -1 do
      post :destroy, params: { :id => pair.id}
    end
  end

  def test_refresh_scores_for_non_super_users
    current_user_is :f_admin
    
    DJUtils.expects(:enqueue_unless_duplicates).with(:queue => DjQueues::MONGO_CACHE).never
    post :refresh_scores
    assert_redirected_to super_login_path
  end

  def test_refresh_scores_for_program_delta_index
    current_user_is :f_admin
    login_as_super_user

    Matching.expects(:perform_program_delta_index_and_refresh_later).once
    post :refresh_scores
    assert_redirected_to match_configs_path
  end

  def test_question_choices
    current_user_is :f_admin
    login_as_super_user
    program = programs(:albers)

    # first a ques which has choices
    mentor_edu_ques = program.role_questions_for(RoleConstants::MENTOR_NAME).select{|q| q.profile_question.question_text =="Gender"}[0].id.to_s
    student_edu_ques = program.role_questions_for(RoleConstants::STUDENT_NAME).select{|q| q.profile_question.question_text =="Gender"}[0].id.to_s
    get :question_choices, params: { :config_id => 0, :student_ques_id => student_edu_ques, :mentor_ques_id => mentor_edu_ques}
    assert_response :success
  end
end