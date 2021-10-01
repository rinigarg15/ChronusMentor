module CommentsHelper
  DISPLAY_LIMIT = 5

  def comments_container(comments = [], options = {})
    content_tag(:div, class: "light-gray-bg list-group cjs_comments_container", id: options.delete(:container_id)) do
      content = get_safe_string
      show_all_comments_link = comments.size > DISPLAY_LIMIT && options[:view_all_options].present?

      if show_all_comments_link
        comments = comments.last(DISPLAY_LIMIT)
        content += build_view_all_comments_link(options[:view_all_options])
      end
      content += build_comments_list(comments, show_all_comments_link, options)
      if options[:new_comment_partial].present?
        # Make sure that this partial users "common/new_comment_wrapper"
        content += render(partial: options[:new_comment_partial], locals: (options[:new_comment_partial_locals].presence || {}))
      end
      content
    end
  end

  def build_comments_list(comments, show_all_comments_link, options)
    return if comments.empty?

    padding_class = (options[:new_comment_partial].present? || options[:no_bottom_padding]) ? "p-l-m p-r-m p-t-m" : "p-m"
    content_tag(:div, class: "#{padding_class} #{show_all_comments_link ? 'cjs_less_comments' : 'cjs_all_comments'}") do
      inner_content = get_safe_string
      comments.each do |comment|
        # Make sure that this partial uses "common/comment"
        inner_content += render(partial: options[:comment_partial], locals: { options[:comment_partial_key] => comment }.merge(options[:comment_partial_locals] || {}))
      end
      inner_content
    end
  end

  private

  def build_view_all_comments_link(options)
    content_tag(:div, class: "p-t-xs p-l-m p-b-xs b-b") do
      content = get_safe_string
      content += link_to "feature.mentoring_model_task_comment.action.view_less_comments".translate, "javascript:void(0)", class: "cjs_view_less_comments_link hide"
      content += link_to("javascript:void(0)", data: { url: options[:url] }, class: "cjs_view_all_comments_link") do
        content_tag(:span, options[:label], class: "cjs_view_all_comments_label")
      end
      content
    end
  end
end