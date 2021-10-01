module FlagsHelper

  def popup_link_to_flag_content(content, options = {})
    user = current_user
    return "" if current_program.nil? || !current_program.flagging_enabled? || user.nil?
    return "" if !(user.is_admin? && Flag.flagged_and_unresolved?(content, current_program)) && Flag.content_owner_is_user?(content, user)

    if user.is_admin? && Flag.flagged_and_unresolved?(content, current_program)
      icon_class = "fa fa-flag text-danger"
      action_name = content_tag(:span, "feature.flag.action.Resolve_Flagging_v1".translate, class: "#{options[:label_name_class]}")
      action = "jQueryShowQtip('#centered_content', 600, '#{content_related_flags_path(content_type: content.class, content_id: content.id)}', '', {modal: true, draggable: true});"
      other_options = { class: "cjs_red_flag #{options[:link_class]}" }

    elsif Flag.flagged_and_unresolved_by_user?(content, user)
      icon_class = "fa fa-flag text-danger"
      action_name = content_tag(:span, "feature.flag.content.flagged_note_v1".translate, class: "#{options[:label_name_class]}")
      action = "javascript:void(0)"
      other_options = { class: "cjs_red_flag btn-link disabled #{options[:link_class]}" }

    else
      icon_class = "fa fa-flag"
      action_name = content_tag(:span, "feature.flag.content.flag_note_v1".translate, class: "#{options[:label_name_class]}")
      action = "jQueryShowQtip('#centered_content', 600, '#{new_flag_path(content_type: content.class, content_id: content.id)}', '', {draggable: true , modal: true});"
      other_options = { class: "cjs_grey_flag #{options[:link_class]}" }
    end

    label = append_text_to_icon("#{icon_class} #{options[:additional_icon_class]}", action_name)
    if options[:get_hash]
      { label: label, js: action }.merge(other_options)
    else
      link_to_function(label, action, other_options).html_safe
    end
  end

  def flag_status_text(flag)
    text = ''
    case flag.status
    when Flag::Status::UNRESOLVED
      text = "feature.flag.header.Unresolved".translate
    when Flag::Status::DELETED
      text = "feature.flag.header.Deleted".translate
    when Flag::Status::EDITED
      text = "feature.flag.header.Edited".translate
    when Flag::Status::ALLOWED
      text = "feature.flag.header.Allowed".translate
    end
    text
  end

  def form_flag_content_preview(text, content)
    content_tag(:div, truncate(text, length:60, omission: '..') ) +
    content_tag(:div, "feature.flag.content.flagged_info_html".translate(count: Flag.count_for_content(content, current_program), time_ago_in_words: formatted_time_in_words(content.created_at, no_time: true, on_str: true), flagged_by: link_to_user(content.user)), class: 'dim small nowrap')
  end

  def flag_content_preview(flag)
    ret = ''
    content = flag.content
    case content.class.to_s
    when 'Article'
      ret = content_tag(:div, truncate(content.article_content.title, length:60, omission: '..') )
      ret += content_tag(:div, "feature.flag.content.flagged_info_html".translate(
              count: Flag.count_for_content(content, current_program),
              time_ago_in_words: formatted_time_in_words(content.created_at, no_time: true, on_str: true),
              flagged_by: link_to(content.author.name, member_path(content.author))), class: 'dim small nowrap')
    when 'Post'
      post_body = truncate(content.body, length:60, omission: '..')
      ret = content_tag(:div, post_body)
      forum = content.topic.forum
      ret += content_tag(:div, "feature.flag.content.forum_flagged_info_html".translate(
              count: Flag.count_for_content(content, current_program),
              time_ago_in_words: formatted_time_in_words(content.created_at, no_time: true, on_str: true),
              flagged_by: link_to_user(content.user),
              flagged_in: link_to(forum.name, forum_path(forum))), class: 'dim small nowrap')
    when 'Comment'
      ret = form_flag_content_preview(content.body, content)
    when 'QaQuestion'
      ret = form_flag_content_preview(content.summary, content)
    when 'QaAnswer'
      ret = form_flag_content_preview(content.content, content)
    when "NilClass" # content is deleted
      ret = content_tag(:i, "feature.flag.content.content_deleted_html".translate)
    end
    ret
  end

  def flag_content_view_links(flag)
    ret = ''
    content = flag.content
    link_class = "btn btn-white btn-xs btn-block-xxs m-b-xs"
    case content.class.to_s
    when 'Article'
      ret = content_tag(:div, link_to("feature.flag.action.view_content".translate, article_path(content, from_flags: true, scroll_to: "view_article"), :class => link_class) )
    when 'Post'
      ret = content_tag(:div, link_to("feature.flag.action.view_content".translate, forum_topic_path(content.topic.forum, content.topic, from_flags: true, scroll_to: "post_#{content.id}"), :class => link_class) )
    when 'Comment'
      ret = content_tag(:div, link_to("feature.flag.action.view_content".translate, article_path(content.article, from_flags: true, scroll_to: "comment_#{content.id}"), :class => link_class) )
    when 'QaQuestion'
      ret = content_tag(:div, link_to("feature.flag.action.view_content".translate, qa_question_path(content, :root => content.program.root, from_flags: true), :class => link_class) )
    when 'QaAnswer'
      ret = content_tag(:div, link_to("feature.flag.action.view_content".translate, qa_question_path(content.qa_question, :root => content.qa_question.program.root, from_flags: true, scroll_to: "qa_answer_#{content.id}"), :class => link_class) )
    when "NilClass" # content is deleted
      ret = content_tag(:i, "feature.flag.content.content_deleted_html".translate)
    end
    ret
  end

  def flag_actions(flag, options = {})
    css_class = options[:as_button] ? 'btn btn-white m-r-xs' : 'font-bold'
    allow_link_text = options[:allow_text] || "feature.flag.action.Allow".translate
    delete_link_text = options[:delete_text] || "display_string.Delete".translate
    allow_link_url = options[:allow_all] ? flag_path(flag, allow_all: true) : flag_path(flag, allow: true)
    allow_link = link_to(allow_link_text, allow_link_url, method: :patch, class: css_class, title: "feature.flag.content.ignore_note".translate)
    specific_links = get_safe_string
    content = flag.content
    delete_confirm_msg = "feature.flag.content.delete_confirm".translate(content_type: flag.content_type_name.downcase)
    case content.class.to_s
    when 'Post'
      specific_links += link_to(delete_link_text, forum_topic_post_path(content.topic.forum, content.topic, content), method: :delete, class: css_class, data: { confirm: delete_confirm_msg, remote: true } )
    when 'Article'
      specific_links += link_to(delete_link_text, article_path(content), method: :delete, class: css_class, data: {confirm: delete_confirm_msg})
    when 'Comment'
      specific_links += link_to(delete_link_text, article_comment_path(content.article, content), method: :delete, class: css_class, data: {confirm: delete_confirm_msg})
    when 'QaQuestion'
      specific_links += link_to(delete_link_text, qa_question_path(content, :root => content.program.root), method: :delete, class: css_class, data: {confirm: delete_confirm_msg})
    when 'QaAnswer'
      specific_links += link_to(delete_link_text, qa_question_qa_answer_path(content.qa_question, content, root: content.qa_question.program.root, answer_deleted: true), method: :delete, remote: true, class: css_class, data: {confirm: delete_confirm_msg})
    when "NilClass" # content is deleted
      ret = content_tag(:i, "feature.flag.content.not_possible_html".translate)
    end
    ret = content_tag(:span, (specific_links + allow_link))
    ret
  end
end