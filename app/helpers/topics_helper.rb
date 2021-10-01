module TopicsHelper

  def get_topic_actions(topic, dropdown_options = {})
    actions = []
    if topic.can_be_deleted?(current_user)
      actions << {
        label: append_text_to_icon("fa fa-trash", "display_string.Delete".translate),
        url: forum_topic_path(topic.forum, topic),
        method: :delete,
        data: { confirm: "common_text.confirmation.sure_to_delete_this".translate(title: "feature.forum.label.conversation".translate) }
      }
    end
    dropdown_buttons_or_button(actions, dropdown_options)
  end

  def formatted_topic_body(topic)
    body = topic.body.to_s.gsub("\n", "<br/>").html_safe unless contains_html?(body)
    chronus_sanitize_while_render(body, sanitization_version: @current_organization.security_setting.sanitization_version)
  end

  def topic_modal_id(id)
    if id.empty?
      "cjs_new_topic_modal"
    else
      "cjs_new_topic_modal_" + id
    end
  end

  def new_topic_action(forum, mobile_footer_action = false, return_link = false, options = {})
    return unless forum.can_be_accessed_by?(current_user)
    id_suffix = options.delete(:id) || ""
    id = topic_modal_id(id_suffix)
    options.merge!(
      url: "javascript:void(0)",
      data: { toggle: "modal", target: "##{id}" }
    )
    if mobile_footer_action
      options.merge!(
        icon_class: "fa fa-plus m-t-xs",
        sr_text: "feature.forum.action.start_conversation".translate
      )
    else
      options[:label] = append_text_to_icon("fa fa-comment", "feature.forum.action.start_conversation".translate)
      return_link ? render_action_for_dropdown_button(options) : options
    end
  end

  def topic_link(topic, use_ajax = false, options = {})
    topic_url = forum_topic_path(topic.forum, topic)

    default_options = { label: topic.title }
    if use_ajax
      default_options[:url] = "javascript:void(0)"
      default_options[:data] = { ajax_url: topic_url, show_title: options.delete(:show_title) }
    else
      default_options[:url] = topic_url
    end
    render_action_for_dropdown_button(default_options.merge(options))
  end

  def follow_topic_link(topic, return_link = false, from_topics_listing = false)
    following = topic.subscribed_by?(current_user)
    options = {
      url: "javascript:void(0)",
      class: "cjs_follow_topic_link_#{topic.id} #{from_topics_listing ? 'btn btn-sm btn-white noshadow' : 'btn btn-primary'}",
      data: {
        ajax_url: follow_forum_topic_path(topic.forum, topic, subscribe: !following, from_topics_listing: from_topics_listing),
        ajax_method: "post",
        ajax_hide_loader: true
      }
    }
    options[:label] =
      if following
        if from_topics_listing
          (get_icon_content("fa fa-check text-navy") + "feature.forum.action.following".translate)
        else
          append_text_to_icon("fa fa-check", "feature.forum.action.following".translate)
        end
      else
        append_text_to_icon("fa fa-plus-square", "feature.forum.action.follow".translate)
      end
    return_link ? render_action_for_dropdown_button(options) : options
  end

  def render_community_widget_topic_content(topic)
    content_tag(:div, class: "clearfix height-65 overflowy-ellipsis break-word-all") do
      link_to(content_tag(:h4, truncate_html(topic.title, max_length: 65), class: "m-b-xs maxheight-30 overflowy-ellipsis h5 no-margins text-info"), forum_topic_path(topic.forum, topic, src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET), class: "btn-link") +
      content_tag(:div, class: "m-t-xs inline m-b-sm") do
        content_tag(:span, append_text_to_icon("fa fa-clock-o", "feature.resources.content.time_ago".translate(time: time_ago_in_words(topic.updated_at))), class: "small text-muted")
      end
    end +
    content_tag(:div, class: "height-54 break-word-all overflowy-ellipsis p-r-xs") do
      HtmlToPlainText.plain_text(topic.body)
    end
  end

  def display_group_topic_follow_icon(topic)
    content_tag(:span, class: "cjs_group_topic_follow_icon") do
      if topic.subscribed_by?(current_user)
        tooltip_options = { title: "feature.forum.action.following".translate, toggle: "tooltip" }
        get_icon_content("fa fa-check-circle fa-lg text-navy m-l-xs", data: tooltip_options)
      end
    end
  end

  private

  def contains_html?(text)
    text != sanitize(text)
  end
end