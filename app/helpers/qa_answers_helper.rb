module QaAnswersHelper
  def get_actions_for_qa_answer(qa_answer)
    actions = []
    flag_content_action = popup_link_to_flag_content(qa_answer, get_hash: true)
    actions << flag_content_action if flag_content_action.present?
    if qa_answer.user == current_user || current_user.is_admin?
      actions << {
        label: append_text_to_icon("fa fa-trash", "display_string.Delete".translate),
        url: qa_question_qa_answer_path(qa_answer.qa_question_id, qa_answer, format: :js),
        method: :delete,
        data: {
          confirm: "common_text.confirmation.sure_to_delete_this".translate(title: "feature.question_answers.label.answer".translate),
          remote: true
        }
      }
    end
    actions
  end

  def qa_answer_html_id(qa_answer)
    "qa_answer_#{qa_answer.id}"
  end

  def get_like_button_container(qa_answer)
    liked = qa_answer.helpful?(current_user)
    contents = get_toggle_contents_for_like_following_button(qa_answer.score, liked, label_key: "feature.question_answers.content.n_like", label_icon: "fa fa-thumbs-up")
    toggle_button(helpful_qa_question_qa_answer_path(qa_answer.qa_question_id, qa_answer, format: :js), contents,
      liked, class: "btn btn-sm noshadow", handle_html_data_attr: true, toggle_class: { active: "btn-primary", inactive: "btn-white" } )
  end

  def get_toggle_contents_for_like_following_button(current_score, liked_or_following, options = {})
    active_score = liked_or_following ? current_score : (current_score + 1)
    inactive_score = liked_or_following ? (current_score - 1) : current_score

    active_content = content_tag(:span, class: "font-bold") do
      content = get_safe_string
      content += content_tag(:span, active_score, class: "m-r-xs") if active_score != 0 || options[:show_zero]
      content += content_tag(:span, options[:label_key].translate(count: active_score), class: "hidden-xs")
    end
    inactive_content = get_safe_string
    inactive_content += content_tag(:span, inactive_score, class: "m-r-xs") if inactive_score != 0 || options[:show_zero]
    inactive_content += content_tag(:span, options[:label_key].translate(count: inactive_score), class: "hidden-xs")

    return {
      active: append_text_to_icon(options[:label_icon], active_content),
      inactive: append_text_to_icon(options[:label_icon], inactive_content)
    }
  end
end