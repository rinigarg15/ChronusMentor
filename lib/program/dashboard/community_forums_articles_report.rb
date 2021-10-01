module Program::Dashboard::CommunityForumsArticlesReport
  extend ActiveSupport::Concern

  def community_forum_articles_report_enabled?
    self.is_report_enabled?(DashboardReportSubSection::Type::CommunityForumsArticles::FORUMS_AND_ARTICLES)
  end

  module Features
    FORUM_POSTS = "forum_posts"
    ARTICLES_SHARED = "articles_shared"
    COMMENTS_ON_ARTICLES = "comments_on_articles"
  end

  private


  def get_forums_and_articles(date_range)
    {forum_posts: get_forum_posts_data(date_range), articles_shared: get_articles_shared_data(date_range), comments_on_articles: get_comments_on_articles_data(date_range)}
  end


  def get_forum_posts_data(date_range)
    return nil unless self.forums_enabled?
    group_forum_ids = self.forums.where("group_id IS NULL").pluck(:id)
    posts = self.posts.joins(:topic).where(topics: { forum_id: group_forum_ids } ).published
    percentage, prev_period_forum_posts_count, current_period_forum_posts_count = get_percentage_and_object_counts(date_range, posts)
    return {current_periods_count: current_period_forum_posts_count, prev_periods_count: prev_period_forum_posts_count, percentage: percentage}
  end

  def get_articles_shared_data(date_range)
    return nil unless self.articles_enabled?
    percentage, prev_period_shared_articles_count, current_period_shared_articles_count = get_percentage_and_object_counts(date_range, get_articles)
    return {current_periods_count: current_period_shared_articles_count, prev_periods_count: prev_period_shared_articles_count, percentage: percentage}
  end

  def get_comments_on_articles_data(date_range)
    return nil unless self.articles_enabled?
    article_publications = Article::Publication.where(article_id: get_articles.pluck(:id), program_id: self.id)
    comments = Comment.where(article_publication_id: article_publications.pluck(:id))
    percentage, prev_period_article_comments_count, current_period_article_comments_count = get_percentage_and_object_counts(date_range, comments)
    return {current_periods_count: current_period_article_comments_count, prev_periods_count: prev_period_article_comments_count, percentage: percentage}
  end

  def get_articles
    @published_articles || compute_articles
  end

  def compute_articles
    @published_articles = self.articles.published
  end
end