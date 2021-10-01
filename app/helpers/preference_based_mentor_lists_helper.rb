module PreferenceBasedMentorListsHelper
  def get_preference_based_mentor_lists_icon(object)
    icon_class = object.is_a?(QuestionChoice) ? "fa fa-list fa-fw" : "fa fa-map-marker fa-fw"
    get_icon_content(icon_class, container_class: "fa fa-circle fa-fw", stack_class: "text-navy")
  end

  def get_preference_based_mentor_lists_title(object)
    object.is_a?(QuestionChoice) ? object.text : object.city
  end

  def get_preference_based_mentor_lists_description(object)
    object.is_a?(QuestionChoice) ? object.ref_obj.question_text : "app_constant.question_type.Location".translate
  end

  def get_link_to_filtered_mentors_list(list_item)
    applied_filter_param = "#filters="
    applied_filter_param += get_applied_availabilty_filters_for_list(current_user, current_program)
    applied_filter_param += (list_item.type == Location.name) ? get_link_to_filtered_mentors_list_for_location_based(list_item) : get_link_to_filtered_mentors_list_for_choice_based(list_item)
    applied_filter_param
  end

  def get_link_to_filtered_mentors_list_for_choice_based(list_item)
    profile_question = list_item.profile_question
    question_choice_index = profile_question.values_and_choices.keys.find_index(list_item.ref_obj.id).to_s
    'chQ_' + profile_question.id.to_s + "~" + question_choice_index + '~!'
  end

  def get_link_to_filtered_mentors_list_for_location_based(list_item)
    "search_filters_location_#{list_item.profile_question.id}_name" + "~" + list_item.ref_obj.full_city + '~!'
  end

  def get_applied_availabilty_filters_for_list(user, program)
    if program.ongoing_mentoring_enabled?
      applied_filter = UsersIndexFilters::Values::AVAILABLE if user.can_send_mentor_request?
    else
      applied_filter = UsersIndexFilters::Values::CALENDAR_AVAILABILITY
    end
    applied_filter_param = get_applied_availability_filter_params_for_list(applied_filter)
    applied_filter_param += "filter_show_no_match~show_no_match~!" if program.allow_non_match_connection?
    applied_filter_param
  end

  def get_applied_availability_filter_params_for_list(applied_filter)
    applied_filter_param = ""
    if applied_filter.present?
      get_availablility_status_filter_fields(RoleConstants::MENTOR_NAME).collect do |visible_filter|
        if visible_filter[:value] == applied_filter
          applied_filter_param += "filter_#{visible_filter[:class]}" + "~" + applied_filter + '~!'
        end
      end
    end
    applied_filter_param
  end

  def render_ignore_preference_based_mentor_list(list)
    ref_obj = list.ref_obj
    dropdown_title = get_icon_content("fa fa-ellipsis-h fa-fw fa-lg m-r text-muted") + content_tag(:span, "display_string.Ignore".translate, class: "sr-only")
    actions = []
    actions << { label: "feature.implicit_preference.mentors_lists.dont_show_again".translate, url: ignore_preference_based_mentor_lists_path, additional_class: "cjs-ignore-preference-based-mentor-list-item", title: "common_text.dont_show_again".translate,
                 data: { pbml: { ref_obj_id: ref_obj.id, ref_obj_type: ref_obj.class.name, profile_question_id: list.profile_question_id, weight: list.weight }}}
    build_dropdown_filters_without_button(dropdown_title, actions, btn_group_class: "pull-right m-l", font_class: "text-default cui_quick_connect_no_border_link", without_caret: true)
  end
end