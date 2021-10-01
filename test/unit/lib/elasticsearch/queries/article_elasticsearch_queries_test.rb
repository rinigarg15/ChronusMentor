require_relative './../../../../test_helper'

class ArticleElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_es_articles
    article = articles(:economy)
    options = {filter: {"publications.program_id" => article.publications.first.program_id}, sort: {"_score" => "desc", "id" => "asc"}, skip_pagination: true}
    results = Article.get_es_articles("", options)
    # We are checking assert_equal_unordered wherever there is no search query because _score is 0 without any search query and created_at is almost always the same since the objects are created at the same time. The order could be any order.

    assert_equal_unordered articles(:economy, :india, :kangaroo, :delhi).collect(&:id), results.collect(&:id)

    # Test pagination
    options.delete(:skip_pagination)
    options.merge!(page: 1, per_page: 2)
    results = Article.get_es_articles("", options)
    assert_equal_unordered articles(:economy, :india).collect(&:id), results.collect(&:id)
    options.merge!(page: 2, per_page: 2)
    results = Article.get_es_articles("", options)
    assert_equal_unordered articles(:kangaroo, :delhi).collect(&:id), results.collect(&:id)
    options.merge!(skip_pagination: true)
    # search string from title & body
    results = Article.get_es_articles("India", options)
    assert_equal articles(:india, :economy).collect(&:id), results.collect(&:id)

    # search string from label
    results = Article.get_es_articles("mba", options)
    assert_equal [articles(:economy).id], results.collect(&:id)

    # search string author name
    results = Article.get_es_articles("Good unique", options)
    assert_equal [articles(:kangaroo).id], results.collect(&:id)

    # stop words should not be considered for search
    results = Article.get_es_articles("is", options)
    assert_equal [], results.collect(&:id)

    # html tag should not considered for search
    results = Article.get_es_articles("span", options)
    assert_equal [], results.collect(&:id)

    # draft article should not considered for search
    results = Article.get_es_articles("draft", options)
    assert_equal [], results.collect(&:id)

    options[:filter].merge!("article_content.labels.id" => article.labels.last.id)
    results = Article.get_es_articles("", options)
    assert_equal [articles(:economy).id], results.collect(&:id)
  end
end