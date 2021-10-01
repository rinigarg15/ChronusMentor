module ForumsHelper
  def render_community_widget_forum_content(forum)
    content_tag(:div, class: "clearfix height-65 overflowy-ellipsis break-word-all") do
      link_to(content_tag(:h4, truncate_html(forum.name, max_length: 65), class: "m-b-xs maxheight-30 overflowy-ellipsis h5 no-margins text-info"), forum_path(forum, src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET), class: "btn-link")
    end +
    content_tag(:div, class: "height-54 break-word-all overflowy-ellipsis p-r-xs") do
      HtmlToPlainText.plain_text(forum.description)
    end
  end
end