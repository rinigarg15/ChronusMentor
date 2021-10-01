module QaQuestionsHelper
  def render_community_widget_qa_question_content(qa_question)
    content_tag(:div, class: "clearfix height-65 overflowy-ellipsis break-word-all") do
      link_to(content_tag(:h4, truncate_html(qa_question.summary, max_length: 65), class: "m-b-xs maxheight-30 overflowy-ellipsis h5 no-margins text-info"), qa_question_path(qa_question, src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET), class: "btn-link") +
      content_tag(:div, class: "m-t-xs inline m-b-sm") do
        content_tag(:span, append_text_to_icon("fa fa-clock-o", "feature.resources.content.time_ago".translate(time: time_ago_in_words(qa_question.updated_at))), class: "small text-muted")
      end
    end +
    content_tag(:div, class: "height-54 break-word-all overflowy-ellipsis p-r-xs") do
      HtmlToPlainText.plain_text(qa_question.description)
    end
  end
end