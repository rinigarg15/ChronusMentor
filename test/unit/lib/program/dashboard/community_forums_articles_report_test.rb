require_relative './../../../../test_helper'

class Program::Dashboard::CommunityForumsArticlesReportTest < ActiveSupport::TestCase
  def test_community_forum_articles_report_enabled
    program = programs(:albers)
    assert program.community_forum_articles_report_enabled?

    program.stubs(:is_report_enabled?).with(DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES).returns(false)
    assert_false program.community_forum_articles_report_enabled?
  end


  def test_get_forums_and_articles
    program = programs(:albers)
    start_time = (Time.now.utc-2.days).beginning_of_day
    end_time = Time.now.utc.end_of_day
    date_range = start_time..end_time
    assert_equal_hash({forum_posts: {:current_periods_count=>0, :prev_periods_count=>0, :percentage=>0}, articles_shared: {:current_periods_count=>4, :prev_periods_count=>0, :percentage=>100}, comments_on_articles: {:current_periods_count=>0, :prev_periods_count=>0, :percentage=>0}}, program.send(:get_forums_and_articles, date_range))
  end

  def test_get_forum_posts_data
    program = programs(:albers)
    start_time = (Time.current - 2.days).beginning_of_day
    end_time = Time.current.end_of_day
    date_range = start_time..end_time
    assert_equal 0, program.posts.published.count
    assert_equal_hash( { current_periods_count: 0, prev_periods_count: 0, percentage: 0 }, program.send(:get_forum_posts_data, date_range))

    forum = groups(:group_pbe_0).forum
    user = members(:student_0).users.where(program_id: forum.program_id).first
    topic = create_topic(forum: forum, user: user)
    create_post(topic: topic, user: user)
    assert_equal_hash( { current_periods_count: 0, prev_periods_count: 0, percentage: 0 }, program.send(:get_forum_posts_data, date_range))

    topic = create_topic(forum: forums(:forums_1), user: users(:f_admin))
    create_post(topic: topic, user: users(:f_admin))
    assert_equal_hash( { current_periods_count: 1, prev_periods_count: 0, percentage: 100 }, program.send(:get_forum_posts_data, date_range))

    program.stubs(:forums_enabled?).returns(false)
    assert_nil program.send(:get_forum_posts_data, date_range)
  end

  def test_get_articles_shared_data
    program = programs(:albers)
    start_time = (Time.now.utc-2.days).beginning_of_day
    end_time = Time.now.utc.end_of_day
    date_range = start_time..end_time
    program.stubs(:articles_enabled?).returns(false)
    assert_nil program.send(:get_articles_shared_data, date_range)

    program.stubs(:articles_enabled?).returns(true)
    assert_equal_hash({:current_periods_count=>4, :prev_periods_count=>0, :percentage=>100}, program.send(:get_articles_shared_data, date_range))
  end

  def test_get_comments_on_articles_data
    program = programs(:albers)
    start_time = (Time.now.utc-2.days).beginning_of_day
    end_time = Time.now.utc.end_of_day
    date_range = start_time..end_time
    program.stubs(:articles_enabled?).returns(false)
    assert_nil program.send(:get_comments_on_articles_data, date_range)

    program.stubs(:articles_enabled?).returns(true)
    assert_equal_hash({:current_periods_count=>0, :prev_periods_count=>0, :percentage=>0}, program.send(:get_comments_on_articles_data, date_range))

    create_article_comment(articles(:economy), programs(:albers), :user => users(:f_student), :body => "ANC")
    assert_equal_hash({:current_periods_count=>1, :prev_periods_count=>0, :percentage=>100}, program.send(:get_comments_on_articles_data, date_range))
  end

  def test_get_articles
    program = programs(:albers)
    program.expects(:compute_articles).once
    program.send(:get_articles)
  end

  def test_compute_articles
    program = programs(:albers)
    assert_equal program.articles.published, program.send(:compute_articles)
  end
end