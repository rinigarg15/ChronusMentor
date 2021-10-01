require_relative './../../../test_helper'

class HealthReport::ContentOverviewTest < ActiveSupport::TestCase

  def test_compute_content_overview
    program = programs(:albers)
    content_overview = HealthReport::ContentOverview.new(program)
    content_overview.compute

    assert content_overview.history_metrics[:articles]
    assert content_overview.history_metrics[:forums]
    assert content_overview.history_metrics[:questions]
    assert content_overview.history_metrics[:comments]
    assert content_overview.history_metrics[:resources]

    total_count_hash = {}
    last_month_count_hash = {}

    member_ids = program.users.collect(&:member_id)
    resource_ids = program.resource_publications.collect(&:resource_id)
    ratings = Rating.where(rateable_id: resource_ids,  rateable_type: "Resource",  user_id: member_ids, rating: Resource::RatingType::HELPFUL)

    total_count_hash[:resources] = ratings.count
    total_count_hash[:articles] = program.articles.published.count
    total_count_hash[:forums] = program.posts.count
    total_count_hash[:questions] = program.qa_questions.count + program.qa_answers.count
    total_count_hash[:comments] = program.comments.count

    last_month_count_hash[:resources] = ratings.where("ratings.created_at > ?", 1.month.ago).count
    last_month_count_hash[:articles] = program.articles.published.where("articles.created_at > ?", 1.months.ago).count
    last_month_count_hash[:articles] = program.articles.published.where("articles.created_at > ?", 1.months.ago).count
    last_month_count_hash[:forums] = program.posts.where("posts.created_at > ?", 1.months.ago).count
    last_month_count_hash[:questions] = program.qa_questions.where("created_at > ?", 1.months.ago).count + program.qa_answers.where("qa_answers.created_at > ?", 1.months.ago).count
    last_month_count_hash[:comments] = program.comments.where("comments.created_at > ?", 1.months.ago).count

    assert_equal total_count_hash.values, content_overview.history_metrics.values.map{|x| x.value}
    assert_equal last_month_count_hash.values, content_overview.history_metrics.values.map{|x| x.last_month}
    assert_equal total_count_hash.values.map{|x| x > 10 ? 10 : x}, content_overview.percent_metrics.values.map{|x| x.current}
    assert_equal ((total_count_hash.values.map{|x| x > 10 ? 10 : x}.sum.to_f / (10 * total_count_hash.size))* 100).round, (content_overview.cumulative_value.current* 100).round
  end

  def test_compute_content_overview_posts_count
    # Program forum
    topic = create_topic
    10.times { create_post(topic: topic) }
    time_traveller(35.days.ago) do
      10.times { create_post(topic: topic) }
    end

    # Group forum is ignored
    group_forum_setup
    group_user = @group.members.first
    topic = create_topic(forum: @forum, user: group_user)
    create_post(topic: topic, user: group_user)
    create_post(topic: topic, user: group_user)

    program = programs(:albers)
    assert_equal 22, program.posts.count
    content_overview = HealthReport::ContentOverview.new(program)
    content_overview.compute
    history_metrics = content_overview.history_metrics[:forums]
    percent_metrics = content_overview.percent_metrics[:forums]
    assert_equal 20, history_metrics.value
    assert_equal 10, history_metrics.last_month
    assert_equal 10, percent_metrics.current
    assert_equal 1.0, percent_metrics.value
    assert_equal 10, percent_metrics.maximum

    Forum.expects(:program_forums).once.returns([])
    content_overview_2 = HealthReport::ContentOverview.new(program)
    content_overview_2.compute
    history_metrics = content_overview_2.history_metrics[:forums]
    assert_equal 0, history_metrics.value
    assert_equal 0, history_metrics.last_month
  end
end