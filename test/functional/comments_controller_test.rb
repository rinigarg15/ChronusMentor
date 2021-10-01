require_relative './../test_helper.rb'

class CommentsControllerTest < ActionController::TestCase
  def test_owner_should_be_able_to_delete_a_comment
    articles(:economy).publish([programs(:albers)])
    assert articles(:economy).published_programs.include?(programs(:albers))
    c = create_article_comment(articles(:economy), programs(:albers), :user => users(:f_student), :body => "ANC")
    current_user_is c.user
    assert_difference("Comment.count", -1) do
      post :destroy, xhr: true, params: { :article_id => articles(:economy).id, :id => c.id}
    end
  end

  def test_privileged_user_should_be_able_to_delete_any_comment
    role = create_role(:name => 'article_manager')
    article_manager = create_user(:role_names => ['article_manager'])
    current_user_is article_manager
    add_role_permission(role, 'manage_articles')

    c = create_article_comment(articles(:economy), programs(:albers), :user => users(:f_student), :body => "ANC")
    flag = create_flag(content: c)
    assert flag.unresolved?
    assert_difference("Comment.count", -1) do
      post :destroy, xhr: true, params: { :article_id => articles(:economy).id, :id => c.id}
    end
    assert_equal Flag::Status::DELETED, flag.reload.status
  end

  def test_should_now_allow_non_user_to_delete_a_comment
    c = create_article_comment(articles(:economy), programs(:albers), :user => users(:f_mentor), :body => "ANC")
    current_user_is users(:f_student)
    assert_permission_denied do
      post :destroy, xhr: true, params: { :article_id => articles(:economy).id, :id => c.id}
    end
  end

  def test_should_create_a_new_comment
    current_user_is :f_student

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMMENT_ON_ARTICLE, {context_object: articles(:economy).title}).once
    assert_difference("Comment.count", 1) do
      post :create, xhr: true, params: { :article_id => articles(:economy).id, :comment => {
        :body => "Test body"
      }}
    end
    c = assigns(:comment)
    assert_equal(users(:f_student), c.user)
    assert_equal(articles(:economy), c.article)
    assert_equal("Test body", c.body)
  end

  def test_should_trigger_an_email_to_article_watchers_except_commenter
    article = create_article(:author => members(:f_mentor))
    publication = article.get_publication(programs(:albers))
    watchers = [users(:student_0), users(:student_1), users(:student_2)]
    watchers.each do |watcher|
      publication.comments.create!(:user => watcher, :body => "122")
    end

    # These are the expected recepients
    expected_recepients = publication.watchers.collect(&:email)
    new_commenter = users(:f_student)
    assert(!expected_recepients.include?(new_commenter.email))

    current_user_is new_commenter
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::COMMENT_ON_ARTICLE, {context_object: article.title}).once
    assert_difference("Comment.count", 1) do
      assert_emails publication.watchers.size do
        post :create, xhr: true, params: { :article_id => article.id, :comment => {
          :body => "Test body"
        }}
      end
    end
    c = assigns(:comment)
    assert_equal(users(:f_student), c.user)
    assert_equal_unordered(expected_recepients, ActionMailer::Base.deliveries.last(expected_recepients.size).collect(&:to).flatten)
  end
end

private

def _a_article
  "an article"
end

def _article
  "article"
end

def _Article
  "Article"
end

def _articles
  "articles"
end

def _Articles
  "Articles"
end