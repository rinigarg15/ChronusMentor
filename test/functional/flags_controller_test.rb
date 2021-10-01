require_relative './../test_helper.rb'

class FlagsControllerTest < ActionController::TestCase

  def setup
    super
    @user = users(:f_admin)
    @program = programs(:albers)
    @program.enable_feature(FeatureName::FLAGGING, true)
    current_user_is :f_admin
  end

  def test_new
    content = articles(:economy)
    get :new, xhr: true, params: { content_id: content.id, content_type: content.class.to_s}
    assert_response :success
    assert_equal content, assigns(:content)
    assert_equal content, assigns(:flag).content
  end

  def test_new_permission_denied
    assert_permission_denied do
      get :new, xhr: true, params: { content_id: 'someId', content_type: User.name}
    end
  end

  def test_create
    request.env["HTTP_REFERER"] = '/' # some path needed since redirect_to :back is there
    current_user_is :f_mentor
    content = articles(:economy)
    assert_difference 'ActionMailer::Base.deliveries.size', programs(:albers).admin_users.size do
      assert_difference 'Flag.count', +1 do
        post :create, xhr: true, params: { flag: {content_id: content.id, content_type: content.class.to_s, reason: 'bad article'}}
      end
    end
    flag = Flag.last
    assert_equal content, flag.content
    assert_equal users(:f_mentor), flag.user
    assert_equal programs(:albers), flag.program
    assert_equal 'bad article', flag.reason
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Good unique name has flagged content as inappropriate", mail.subject
    assert Member.find_by(email: mail.to[0]).user_in_program(@program).is_admin?
  end

  def test_create_permission_denied
    current_user_is :f_mentor

    assert_permission_denied do
      assert_no_difference 'Flag.count' do
        post :create, xhr: true, params: { flag: {content_id: "some Id", content_type: User.name, reason: 'bad article'}}
      end
    end
  end

  def test_index
    contents = [articles(:economy), qa_questions(:what)]
    flags = []
    contents.each {|c| flags << create_flag(content: c) }
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
    assert_equal flags.size, assigns(:unresolved_flags_count)
    assert_equal flags.reverse, assigns(:flags)
  end

  def test_index_no_src
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_index_sets_proper_tabs_from_filter_for_pending
    get :index, params: { unresolved: true}
    assert_equal Flag::Tabs::UNRESOLVED, assigns(:tab)
  end

  def test_index_sets_proper_tabs_from_filter_for_resolved
    get :index, params: { resolved: true}
    assert_equal Flag::Tabs::RESOLVED, assigns(:tab)
  end



  def test_update
    request.env["HTTP_REFERER"] = '/' # some path needed since redirect_to :back is there
    content = articles(:economy)
    flag1 = create_flag(content: content)
    flag2 = create_flag(content: content)
    flag3 = create_flag(content: content)
    assert flag1.unresolved?
    assert flag2.unresolved?
    assert flag3.unresolved?
    put :update, params: { id: flag1.id, allow: 'true'}
    assert_false flag1.reload.unresolved?
    put :update, params: { id: flag2.id, allow_all: 'true'}
    assert_false flag1.reload.unresolved?
    assert_false flag2.reload.unresolved?
    assert_false flag3.reload.unresolved?
  end

  def test_content_related
    article = articles(:economy)
    qa_question = qa_questions(:what)
    article_flag_1 = create_flag(content: article)
    article_flag_2 = create_flag(content: article)
    qa_question_flag_1 = create_flag(content: qa_question)
    get :content_related, params: { content_id: article.id, content_type: article.class.to_s}
    assert_response :success
    assert_equal_unordered [article_flag_1, article_flag_2], assigns(:flags)
    assert_equal article, assigns(:content)
  end

  def test_content_related_permission_denied
    assert_permission_denied do
      get :content_related, params: { content_id: "Some Id", content_type: User.name}
    end
  end

  def test_flags_view_title
    current_user_is :f_admin
    program = programs(:albers)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_FLAGS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending flags", abstract_view_id: view.id)

    get :index, params: { :metric_id => metric.id}
    assert_response :success

    assert_not_nil assigns(:metric)
    assert_page_title(metric.title)
  end
end