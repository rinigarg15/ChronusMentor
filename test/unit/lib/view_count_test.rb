require_relative './../../test_helper.rb'

class ViewCountTest < ActiveSupport::TestCase
  def test_hit
    res = Resource.create!(:organization => programs(:org_primary), :title => "test", :content => "Content", :default => true)
    assert_equal 0, res.view_count
    res.hit!
    assert_equal 1, res.view_count
    res.hit!
    assert_equal 2, res.view_count
    DelayedEsDocument.expects(:delayed_update_es_document).once.with(Article, articles(:economy).id)
    assert_difference("articles(:economy).reload.view_count", 1) do
      articles(:economy).hit!
    end
  end
end
