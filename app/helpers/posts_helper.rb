module PostsHelper

  def get_post_moderation_actions(post, from_moderatable_posts, dropdown_options = {})
    return if post.published?

    topic = post.topic
    forum = topic.forum
    actions = []
    actions << {
      label: append_text_to_icon("fa fa-check", "display_string.Publish".translate),
      url: moderate_publish_forum_topic_post_path(forum, topic, post, publish: true),
      method: :post
    }
    actions << {
      label: append_text_to_icon("fa fa-ban", "display_string.Decline".translate),
      js: %Q[jQueryShowQtip('#inner_content', 600, '#{moderate_decline_forum_topic_post_path(forum, topic, post, from_moderate_content: from_moderatable_posts)}', '', {modal: true})].html_safe
    }
    dropdown_buttons_or_button(actions, dropdown_options)
  end

  def get_actions_for_published_post(post, dropdown_options = {})
    return unless post.published?

    topic = post.topic
    forum = topic.forum
    actions = []
    if post.can_be_deleted?(current_user)
      actions << {
        label: append_text_to_icon("fa fa-trash", "display_string.Delete".translate),
        data: {
          ajax_url: forum_topic_post_path(forum, topic, post),
          ajax_method: "delete",
          confirm: "common_text.confirmation.sure_to_delete_this".translate(title: "feature.forum.label.post".translate)
        },
        additional_class: "delete_link"
      }
    end
    if forum.allow_flagging?
      flag_content_action = popup_link_to_flag_content(post, get_hash: true)
      actions << flag_content_action if flag_content_action.present?
    end
    dropdown_buttons_or_button(actions, dropdown_options)
  end

  def formatted_post_body(post)
    # Post body used to be a Ckeditor-based attribute
    strip_tags(post.body).gsub("\n", "<br/>").html_safe
  end

  def post_html_id(post)
    "post_#{post.id}"
  end

  def post_modal_id
    "cjs_new_post_modal"
  end

  def post_comments_container_id(post)
    "cjs_post_comments_#{post.id}"
  end

  def new_post_action(topic, mobile_footer_action = false, options = {})
    return unless topic.can_be_accessed_by?(current_user)

    options.merge!(
      url: "javascript:void(0)",
      data: { toggle: "modal", target: "##{post_modal_id}" }
    )

    if mobile_footer_action
      options.merge!(
        icon_class: "fa fa-comment",
        sr_text: "feature.forum.action.reply_to_this_conversation".translate
      )
    else
      options[:label] = append_text_to_icon("fa fa-comment", "feature.forum.action.reply_to_this_conversation".translate)
      render_action_for_dropdown_button(options)
    end
  end

  def post_comments_container(post, only_comments = false)
    return unless post.published?

    topic = post.topic
    can_reply = post.can_be_accessed_by?(current_user)
    comments, unmoderated_comments_count = post.fetch_children_and_unmoderated_children_count(current_user)

    options = {
      comment_partial: "topics/post_content",
      comment_partial_key: :post,
      comment_partial_locals: { is_root: false },
      no_bottom_padding: can_reply
    }
    return build_comments_list(comments, false, options) if only_comments

    options.merge!(
      no_bottom_padding: false,
      new_comment_partial: (can_reply ? "topics/post_reply_form" : nil),
      new_comment_partial_locals: (can_reply ? { root: post } : nil),
      container_id: post_comments_container_id(post),
      view_all_options: {
        label: view_all_comments_label(comments.size, unmoderated_comments_count),
        url: fetch_all_comments_forum_topic_path(topic, forum_id: topic.forum_id, root_id: post.id)
      }
    )
    comments_container(comments, options)
  end

  def view_all_comments_label(comments_count, unmoderated_comments_count)
    content = content_tag(:span, "feature.mentoring_model_task_comment.action.view_all_comments".translate(comments_count: comments_count, count: 0))
    if unmoderated_comments_count > 0
      content += content_tag(:span, "(#{'feature.mentoring_model_task_comment.action.count_moderated'.translate(comments_count: unmoderated_comments_count)})", class: "m-l-xs text-danger")
    end
    content
  end
end