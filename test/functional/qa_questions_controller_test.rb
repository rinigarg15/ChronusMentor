require_relative './../test_helper.rb'

class QaQuestionsControllerTest < ActionController::TestCase
  def setup
    super
    @view_questions_role = create_role(:name => 'question_viewer')
    @answer_question_role = create_role(:name => 'question_answerer')
    @follow_questions_role = create_role(:name => 'question_follower')
    @manage_questions_role = create_role(:name => 'question_manager')
    @ask_questions_role = create_role(:name => 'question_asker')

    add_role_permission(@view_questions_role, 'view_questions')
    add_role_permission(@answer_question_role, 'answer_question')
    add_role_permission(@follow_questions_role, 'follow_question')
    add_role_permission(@manage_questions_role, 'manage_questions')
    add_role_permission(@ask_questions_role, 'ask_question')
    @viewer = create_user(:name => 'question_viewer', :role_names => ['question_viewer'])
    @answerer = create_user(:name => 'question_answerer', :role_names => ['question_answerer'])
    @follower = create_user(:name => 'question_follower', :role_names => ['question_follower'])
    @manager = create_user(:name => 'question_manager', :role_names => ['question_manager'])
    @asker = create_user(:name => 'question_asker', :role_names => ['question_asker'])
  end

  ##############################################################################
  # NEW
  ##############################################################################

  def test_follow
    current_user_is @follower
    current_program_is :albers
    program = programs(:albers)
    question = create_qa_question(:user => users(:f_student), :program => program)
    user = @follower
    assert_false question.follow?(user)

    post :follow, xhr: true, params: { :id => question.id}
    assert question.reload.follow?(user)

    post :follow, xhr: true, params: { :id => question.id}
    assert_false question.reload.follow?(user)
  end

  def test_authentication
    current_user_is :f_admin
    current_program_is :albers
    programs(:org_primary).enable_feature(FeatureName::ANSWERS, false)

    # First page
    assert_permission_denied do
      get :index, params: { :page => 1}
    end

    question = qa_questions(:what)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_QA, {context_object: question.summary}).never
    assert_permission_denied do
      get :show, params: { :id => question.id}
    end
  end

  def test_index_fetches_all_qa_questions
    current_user_is @viewer
    current_program_is :albers
    program = programs(:albers)
    qa_questions = program.qa_questions
    QaAnswer.destroy_all
    qa_question = qa_questions.first
    3.times { create_qa_answer(:qa_question => qa_question, :user => users(:f_admin))}
    2.times { create_qa_answer(:qa_question => qa_question, :user => users(:f_mentor))}
    1.times { create_qa_answer(:qa_question => qa_question, :user => users(:f_student))}
    # First page
    get :index, params: { :page => 1, :add_new_question => true}
    assert_response :success
    assert_template 'index'
    assert_equal qa_questions.last(PER_PAGE).reverse.collect(&:id), assigns(:qa_questions).collect(&:id)
    assert_equal [users(:f_admin), users(:f_mentor), users(:f_student)], assigns(:top_contributors).to_a
    assert assigns(:add_new_question)

    # Second page
    get :index, params: { :page => 2}
    assert_response :success
    assert_template 'index'
    assert_equal((qa_questions-qa_questions.last(PER_PAGE)).reverse.collect(&:id), assigns(:qa_questions).collect(&:id))
  end

  def test_index_fetches_top_contributors_in_program_view
    current_user_is @viewer
    current_program_is :albers
    program1 = programs(:albers)
    program2 = programs(:ceg)
    program3 = programs(:psg)
    new_user_ceg = create_user(:member => members(:f_admin), :role_names => ['mentor'], :program => programs(:ceg))
    qa_questions = program1.qa_questions    
    qa_question1 = program1.qa_questions.first
    qa_question2 = program2.qa_questions.first
    qa_question3 = program3.qa_questions.first
    QaAnswer.destroy_all
    10.times { create_qa_answer(:qa_question => qa_question2, :user => users(:arun_ceg))}    
    5.times { create_qa_answer(:qa_question => qa_question1, :user => users(:f_student))}
    3.times { create_qa_answer(:qa_question => qa_question1, :user => users(:f_admin))}
    2.times { create_qa_answer(:qa_question => qa_question1, :user => users(:f_mentor))}
    1.times { create_qa_answer(:qa_question => qa_question3, :user => users(:psg_mentor))}
    1.times { create_qa_answer(:qa_question => qa_question1, :user => users(:f_mentor_student))}
    3.times { create_qa_answer(:qa_question => qa_question2, :user => new_user_ceg)}    

    # First page
    get :index, params: { :page => 1}
    assert_response :success
    assert_template 'index'
    assert_equal qa_questions.last(PER_PAGE).reverse.collect(&:id), assigns(:qa_questions).collect(&:id)
    assert_equal [users(:f_student), users(:f_admin), users(:f_mentor), users(:f_mentor_student)], assigns(:top_contributors).to_a
    assert_false assigns(:add_new_question)
  end

  def test_index_sort_by_views
    current_user_is @viewer
    current_program_is :albers
    sorted_qa_questions = programs(:albers).qa_questions.order("views desc")

    get :index, params: { :page => 1, :sort => :views, :order => :desc}
    assert_response :success
    assert_template 'index'
    assert_equal sorted_qa_questions.first(PER_PAGE).collect(&:id), assigns(:qa_questions).collect(&:id)
  end

  def test_search
    current_user_is @viewer
    current_program_is :albers

    #testing a correct term(not a stopword)
    get :index, params: { :search => "coimbatore is"}
    qa_questions = [qa_questions(:question_for_stopwords_test)]
    assert_response :success
    assert_template 'index'
    assert_equal qa_questions.collect(&:id), assigns(:qa_questions).collect(&:id)
  end

  def test_to_check_search_query_is_escaped
    current_user_is @viewer
    current_program_is :albers
    assert_nothing_raised do
      get :index, params: { :search => "coimbatore/"}
    end
    qa_questions = [qa_questions(:question_for_stopwords_test)]
    assert_response :success
    assert_template 'index'
    assert_equal qa_questions.collect(&:id), assigns(:qa_questions).collect(&:id)
  end

  def test_index_has_a_new_qa_question_object
    current_user_is @viewer
    current_program_is :albers
    @viewer.add_role('question_asker')
    assert @viewer.can_ask_question?
    get :index

    new_question = assigns(:new_qa_question)
    assert_not_nil new_question
    assert new_question.new_record?
    assert_equal programs(:albers), new_question.program
    assert_equal @viewer, new_question.user
  end

  def test_show_fetches_all_answers_of_question
    current_user_is @viewer
    current_program_is :albers

    question = qa_questions(:what)
    question.qa_answers.destroy_all
    answers = []
    answers << create_qa_answer(:qa_question => question)
    answers << create_qa_answer(:qa_question => question)

    view_count = question.views
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_QA, {context_object: question.summary}).once
    get :show, params: { :id => question.id}
    assert_response :success
    assert_template 'show'
    assert_equal question.similar_qa_questions.to_a, assigns(:similar_qa_questions).to_a
    assert_equal question, assigns(:qa_question)
    assert_equal_unordered answers, assigns(:qa_answers)
    assert_equal view_count + 1, assigns(:qa_question).reload.views
  end

  def test_show_for_marking_answer_helpful
    current_user_is @viewer
    current_program_is :albers

    question = qa_questions(:what)
    answer = question.qa_answers.first
    assert_equal answer.score, 0
    assert_false answer.helpful?(@viewer)
    
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_QA, {context_object: question.summary}).once
    get :show, params: { :id => question.id, :mark_helpful_answer_id => answer.id}
    assert_response :success
    assert_template 'show'
    answer.reload
    assert_equal answer.score, 1
    assert answer.helpful?(@viewer)
  end

  def test_handle_mark_helpful_for_non_existing_answer
    current_user_is @viewer
    current_program_is :albers
    question = qa_questions(:what)

    get :show, params: { :id => question.id, :mark_helpful_answer_id => 0}
    assert_response :success
    assert_template 'show'
  end

  def test_access_invalid_question
    current_user_is @viewer
    current_program_is :albers

    get :show, params: { id: 0}
    assert_redirected_to qa_questions_path
    assert_equal "The question you are looking for does not exist.", flash[:error]
  end

  def test_show_for_marking_answer_helpful_if_already_marked_helpful
    current_user_is @viewer
    current_program_is :albers

    question = qa_questions(:what)
    answer = question.qa_answers.first
    answer.toggle_helpful!(@viewer)
    assert answer.helpful?(@viewer)
    assert_equal answer.score, 1

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_QA, {context_object: question.summary}).once
    get :show, params: { :id => question.id, :mark_helpful_answer_id => answer.id}
    assert_response :success
    assert_template 'show'
    answer.reload
    assert_equal answer.score, 1
    assert answer.helpful?(@viewer)
  end

  def test_show_creates_new_qa_question_object
    current_user_is @viewer
    current_program_is :albers

    @viewer.add_role('question_asker')
    assert @viewer.can_ask_question?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_QA, {context_object: qa_questions(:what).summary}).once
    get :show, params: { :id => qa_questions(:what).id}
    assert_response :success
    assert_template 'show'

    new_question = assigns(:new_qa_question)
    assert_not_nil new_question
    assert new_question.new_record?
    assert_equal programs(:albers), new_question.program
    assert_equal @viewer, new_question.user
    sort_options = assigns(:answers_sort_options)
    assert_equal "score DESC, id DESC", sort_options[:order_string]
    assert_no_select 'div#new_question'
  end

  def test_show_show_new_qa_question_form_if_cannot_ask_question
    current_user_is @viewer
    current_program_is :albers
    assert !@viewer.can_ask_question?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::VIEW_QA, {context_object: qa_questions(:what).summary}).once
    get :show, params: { :id => qa_questions(:what).id}
    assert_response :success
    assert_template 'show'

    assert_nil assigns(:new_qa_question)
    sort_options = assigns(:answers_sort_options)
    assert_equal "score DESC, id DESC", sort_options[:order_string]
    assert_no_select 'div#new_question'
  end

  def test_qa_question_increment_counter
    current_user_is @viewer
    current_program_is :albers
    question = qa_questions(:what)

    views_count = question.views
    get :show, params: { :id => question.id}
    assert_response :success
    assert_template 'show'
    assert_equal views_count+1, question.reload.views

    views_count = question.views
    get :show, params: { id: question.id, sort: "id", order: "desc"}
    assert_response :success
    assert_template 'show'
    assert_equal views_count, question.reload.views
  end

  def test_qa_question_does_not_increment_view_count_when_question_owner_views_it
    current_user_is users(:f_mentor)
    current_program_is :albers
    question = qa_questions(:what)
    views_count = question.views
    get :show, params: { id: question.id}
    assert_response :success
    assert_template 'show'
    assert_equal views_count, question.reload.views
  end

  def test_create_new_question
    current_user_is @asker
    current_program_is :albers

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_QA, {context_object: 'Hello'}).once
    assert_difference('QaQuestion.count') do
      post :create, params: { :qa_question => {:summary => 'Hello', :description => 'How are you?'}}
    end
    assert_redirected_to qa_questions_path(format: :js)
    assert_equal "Question has been posted successfully", flash[:notice]
  end

  def test_create_new_question_failed
    current_user_is @asker
    current_program_is :albers
    
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::POST_TO_QA, {context_object: ''}).never
    assert_no_difference('QaQuestion.count') do
      post :create, params: { :qa_question => {:description => 'How are you?'}}
    end
    assert_redirected_to qa_questions_path(format: :js)
    assert_equal "Sorry, the question was not posted", flash[:error]
  end

  # Delete
  def test_do_not_allow_nonadmin_user_other_than_owner_to_delete
    current_user_is users(:f_mentor)
    current_program_is :albers
    assert !users(:f_mentor).can_manage_questions?
    qa_question = create_qa_question(:user => users(:f_student))
    assert_permission_denied do
      post :destroy, params: { :id => qa_question.id}
    end
  end

  def test_should_allow_owner_to_delete
    current_user_is :f_student
    current_program_is :albers
    # No manage permissions. Never mind.
    assert !users(:f_student).can_manage_questions?
    qa_question = create_qa_question(:user => users(:f_student))
    flag = create_flag(content: qa_question)
    assert flag.unresolved?
    assert_difference('QaQuestion.count', -1) do
      post :destroy, params: { :id => qa_question.id}
    end
    assert_equal Flag::Status::DELETED, flag.reload.status
  end

  def test_should_allow_admin_to_delete_all_questions
    current_user_is :f_admin
    current_program_is :albers
    qa_question = create_qa_question(:user => users(:f_student))
    assert_difference('QaQuestion.count', -1) do
      post :destroy, params: { :id => qa_question.id}
    end
  end
end
