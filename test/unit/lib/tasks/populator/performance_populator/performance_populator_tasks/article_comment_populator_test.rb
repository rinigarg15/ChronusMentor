require_relative './../../../../../../test_helper'

class ArticleCommentPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_article_comments
    program = programs(:albers)
    to_add_article_publication_ids = program.article_publications.pluck(:id).first(5)
    to_remove_article_publication_ids = program.comments.pluck(:article_publication_id).last(5).uniq
    populator_add_and_remove_objects("article_comment", "publication", to_add_article_publication_ids, to_remove_article_publication_ids, {program: program, model: "comment"})
  end
end