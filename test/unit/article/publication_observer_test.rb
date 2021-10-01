require_relative './../../test_helper.rb'

class Article::PublicationObserverTest < ActiveSupport::TestCase

  def test_after_destroy
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Article, [articles(:economy).id])
    article_publications(:article_publications_1).destroy
  end
end
