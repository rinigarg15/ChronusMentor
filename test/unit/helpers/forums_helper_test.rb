require_relative './../../test_helper.rb'

class ForumsHelperTest < ActionView::TestCase
  
  def test_render_community_widget_forum_content
    forum = forums(:common_forum)

    content = render_community_widget_forum_content(forum)
    set_response_text(content)

    assert_select "div.clearfix.height-65.overflowy-ellipsis.break-word-all" do
      assert_select "a.btn-link" do
        assert_select "h4.m-b-xs.maxheight-30.overflowy-ellipsis.h5.no-margins.text-info", text: truncate_html(forum.name, max_length: 65)
      end
    end
    assert_select "div.height-54.break-word-all.overflowy-ellipsis.p-r-xs", text: forum.description
  end

end