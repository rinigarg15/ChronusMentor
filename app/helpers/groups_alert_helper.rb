module GroupsAlertHelper

  # Notifies admin of the existing connections between student-mentor sets
  def existing_groups_alert(group_ids = [], student_ids_mentor_ids_sets = [], non_active_group_status = nil, context = nil, is_groups_bulk_action = false, html_options = {})
    return unless @current_program.show_existing_groups_alert?
    return if group_ids.blank? && student_ids_mentor_ids_sets.blank?

    group_ids = group_ids.map(&:to_i)
    student_ids_mentor_ids_sets = Group.get_student_ids_mentor_ids(group_ids) if student_ids_mentor_ids_sets.blank?
    alert_data = GroupsAlertData.existing_groups_alert_data(@current_program, student_ids_mentor_ids_sets, non_active_group_status)
    student_ids_mentor_ids_to_group_ids_map = alert_data[0]
    if student_ids_mentor_ids_to_group_ids_map.present?
      messages_list = get_messages_list_for_existing_groups_alert(alert_data, group_ids, non_active_group_status, context, is_groups_bulk_action)
      construct_groups_alert_container(messages_list, html_options)
    end
  end

  # Notifies admin of users added to the drafted connections created from 'Bulk Match' page
  def bulk_match_additional_users_alert(drafted_group_ids, is_groups_bulk_action = false)
    return if drafted_group_ids.empty?

    alert_data = GroupsAlertData.bulk_match_additional_users_alert_data(@current_program, drafted_group_ids)
    student_id_mentor_id_to_additional_users_map = alert_data[0]
    if student_id_mentor_id_to_additional_users_map.present?
      messages_list = get_messages_list_for_bulk_match_additional_users_alert(alert_data, is_groups_bulk_action)
      construct_groups_alert_container(messages_list, alert_class: "alert alert-info", icon_class: "fa fa-info-circle")
    end
  end

  # In matching settings page, mentor_request_style and mentor_offer are disabled based on this note
  def multiple_existing_groups_note
    return unless @current_program.show_existing_groups_alert?

    note_data = GroupsAlertData.multiple_existing_groups_note_data(@current_program)
    student_id_mentor_id_to_group_ids_map = note_data[0]
    return if student_id_mentor_id_to_group_ids_map.blank?

    messages_list = get_messages_list_for_multiple_existing_groups_note(note_data)
    alert_content = construct_groups_alert_container(messages_list, alert_class: "", icon_class: "")
    construct_multiple_existing_groups_note(alert_content)
  end

  def assign_template_alert(groups, new_mentoring_model)
    groups_to_settings_impacted_hash = groups.inject({}) do |result, group|
      group_id = group.id
      result[group_id] = {}
      result[group_id][:is_forum_impacted] = new_mentoring_model.impacts_group_forum?(group)
      result[group_id][:is_messaging_impacted] = new_mentoring_model.impacts_group_messaging?(group)
      result
    end

    groups_for_alert = groups.select do |group|
      group_id = group.id
      group.pending? && (groups_to_settings_impacted_hash[group_id][:is_forum_impacted] || groups_to_settings_impacted_hash[group_id][:is_messaging_impacted])
    end
    return if groups_for_alert.blank?

    messages_list = get_messages_list_for_assign_template_alert(groups_for_alert, new_mentoring_model, groups_to_settings_impacted_hash)
    construct_groups_alert_container(messages_list)
  end

  private

  def construct_groups_alert_container(messages_list, html_options = {})
    html_options.reverse_merge!(icon_class: "fa fa-exclamation-triangle", alert_class: "alert alert-warning")
    content = get_safe_string

    messages_list.each do |messages|
      inner_content = get_safe_string
      base_message = messages[:base_message]
      alert_messages = messages[:alert_messages]
      next if alert_messages.empty?

      inner_content += base_message.to_s
      if base_message.present? || alert_messages.size > 1
        inner_content += content_tag(:ul, class: "#{'m-t-xs' if base_message.present?} p-l-sm") do
          alert_messages.each { |alert_message| concat content_tag(:li, alert_message) }
        end
      else
        inner_content += alert_messages[0]
      end
      inner_content = append_text_to_icon(html_options[:icon_class], inner_content, media_padding_with_icon: true)
      content += content_tag(:div, inner_content, class: html_options[:alert_class])
    end
    content
  end

  def get_messages_list_for_existing_groups_alert(alert_data, group_ids, non_active_group_status, context, is_groups_bulk_action)
    active_group_alert_messages, non_active_group_alert_messages = get_messages_for_existing_groups_alert(alert_data, group_ids, non_active_group_status, is_groups_bulk_action)
    base_message_for_active_groups_alert = base_message_for_active_groups_alert(active_group_alert_messages, context, is_groups_bulk_action)
    base_message_for_non_active_groups_alert = base_message_for_non_active_groups_alert(non_active_group_alert_messages, non_active_group_status, is_groups_bulk_action)
    all_alerts = active_group_alert_messages + non_active_group_alert_messages

    if base_message_for_active_groups_alert.blank? && base_message_for_non_active_groups_alert.blank?
      [ { alert_messages: all_alerts } ]
    elsif base_message_for_non_active_groups_alert.blank?
      [ { base_message: base_message_for_active_groups_alert, alert_messages: all_alerts } ]
    elsif base_message_for_active_groups_alert.blank?
      [ { base_message: base_message_for_non_active_groups_alert, alert_messages: all_alerts } ]
    else
      [
        { base_message: base_message_for_active_groups_alert, alert_messages: active_group_alert_messages },
        { base_message: base_message_for_non_active_groups_alert, alert_messages: non_active_group_alert_messages }
      ]
    end
  end

  def get_messages_list_for_bulk_match_additional_users_alert(alert_data, is_groups_bulk_action)
    alert_messages = []
    student_id_mentor_id_to_additional_users_map, user_id_name_map, user_id_member_id_map = alert_data
    base_message = base_message_for_additional_users_alert(student_id_mentor_id_to_additional_users_map, is_groups_bulk_action)

    student_id_mentor_id_to_additional_users_map.each do |student_id_mentor_id, additional_user_ids|
      translation_options = { count: additional_user_ids.size, mentoring_connection: _mentoring_connection }
      translation_options[:existing_users_list] = student_id_mentor_id.map { |user_id| user_id_name_map[user_id] }.to_sentence
      translation_options[:additional_users_list] = additional_user_ids.map do |additional_user_id|
        link_to(user_id_name_map[additional_user_id], member_path(user_id_member_id_map[additional_user_id]))
      end.to_sentence.html_safe
      alert_messages << "feature.bulk_match.content.additional_users_alert.added_to_connection_between_html".translate(translation_options)
    end
    [ { base_message: base_message, alert_messages: alert_messages } ]
  end

  def get_messages_list_for_multiple_existing_groups_note(note_data)
    messages = []
    student_id_mentor_id_to_group_ids_map, group_id_name_map, user_id_name_map = note_data

    student_id_mentor_id_to_group_ids_map.each do |student_id_mentor_id, group_ids|
      student_id, mentor_id = student_id_mentor_id
      translation_options = {}
      translation_options[:student_name] = user_id_name_map[student_id]
      translation_options[:mentor_name] = user_id_name_map[mentor_id]
      translation_options[:group_links] = group_ids.map { |group_id| link_to(group_id_name_map[group_id], group_path(group_id)) }.to_sentence.html_safe
      messages << "program_settings_strings.content.actively_connected_in_html".translate(translation_options)
    end
    [ { alert_messages: messages } ]
  end

  def get_messages_for_existing_groups_alert(alert_data, group_ids, non_active_group_status, is_groups_bulk_action)
    active_group_alert_messages = []
    non_active_group_alert_messages = []
    student_ids_mentor_ids_to_group_ids_map, group_id_name_map, group_id_status_map, user_id_name_map = alert_data

    student_ids_mentor_ids_to_group_ids_map.each do |student_ids_mentor_ids, common_group_ids|
      student_ids, mentor_ids = student_ids_mentor_ids
      non_active_group_ids = common_group_ids.select { |common_group_id| group_id_status_map[common_group_id] == non_active_group_status }
      active_group_ids = common_group_ids - non_active_group_ids - group_ids

      # When bulk publishing drafted connections or bulk reactivating closed connections,
      # if multiple connections exist between the same students-mentors set within the selected connections
      # then the admin should be notified of it.
      if is_groups_bulk_action
        non_active_group_ids &= group_ids
        non_active_group_ids = [] if non_active_group_ids.size < 2
      else
        non_active_group_ids -= group_ids
      end

      translation_options = { count: mentor_ids.size, a_mentor: _a_mentor, mentors: _mentors }
      translation_options[:students_list] = student_ids.map { |student_id| user_id_name_map[student_id] }.to_sentence
      translation_options[:mentors_list] = mentor_ids.map { |mentor_id| user_id_name_map[mentor_id] }.to_sentence
      active_group_alert_messages << existing_groups_alert_message(translation_options, active_group_ids, group_id_name_map, group_id_status_map)
      non_active_group_alert_messages << existing_groups_alert_message(translation_options, non_active_group_ids, group_id_name_map, group_id_status_map, non_active_group_status)
    end
    [active_group_alert_messages.compact, non_active_group_alert_messages.compact]
  end

  def existing_groups_alert_message(translation_options, group_ids, group_id_name_map, group_id_status_map, non_active_group_status = nil)
    return if group_ids.empty?

    translation_options[:groups_list] = group_ids.map do |group_id|
      group_name = group_id_name_map[group_id]
      group_status = group_id_status_map[group_id]
      get_link_to_group(group_id, group_name, group_status)
    end.to_sentence.html_safe

    if non_active_group_status == Group::Status::DRAFTED
      "feature.connection.content.existing_groups_alert.drafted_as_mentors_to_in_groups_html".translate(translation_options)
    elsif non_active_group_status == Group::Status::CLOSED
      "feature.connection.content.existing_groups_alert.was_mentors_to_in_groups_html".translate(translation_options)
    else
      "feature.connection.content.existing_groups_alert.mentors_to_in_groups_html".translate(translation_options)
    end
  end

  def construct_multiple_existing_groups_note(popover_content)
    translation_options = { mentor: _mentor, mentee: _mentee, mentoring_connections: _mentoring_connections, mentoring_connection: _mentoring_connection }
    translation_options.merge!(Mentee: _Mentee, Mentor: _Mentor, Mentoring_Connections: _Mentoring_Connections)
    translation_options[:click_here] = link_to("display_string.click_here".translate, "javascript:void(0)", class: "cjs_multiple_groups_alert")
    popover_title = "program_settings_strings.content.student_mentor_pair_with_multiple_connections".translate(translation_options)

    content_tag(:span, "program_settings_strings.content.multiple_groups_alert".translate(translation_options), class: "m-r-xs") +
      content_tag(:span, "program_settings_strings.content.view_multiple_groups_html".translate(translation_options)) +
      popover(".cjs_multiple_groups_alert", popover_title, popover_content)
  end

  def get_messages_list_for_assign_template_alert(groups_for_alert, new_mentoring_model, groups_to_settings_impacted_hash)
    is_bulk_action = groups_to_settings_impacted_hash.keys.size > 1
    impacted_settings_term, impacted_settings_downcase_term = get_terms_for_impacted_mentoring_model_settings(groups_for_alert, groups_to_settings_impacted_hash)

    if is_bulk_action
      base_message = %Q[#{"feature.connection.content.assign_template_alert.bulk_action_message_1".translate(mentoring_connections: _mentoring_connections, Messages_or_Discussion_boards: impacted_settings_term)} #{"feature.connection.content.assign_template_alert.bulk_action_message_2".translate(mentoring_connections: _mentoring_connections, Messages_or_Discussion_boards: impacted_settings_term, messages_or_discussions: impacted_settings_downcase_term, template_name: new_mentoring_model.title)}]
      [{ base_message: base_message, alert_messages: groups_for_alert.collect(&:name) }]
    else
      alert_message = %Q[#{"feature.connection.content.assign_template_alert.individual_action_message_1".translate(Messages_or_Discussion_boards: impacted_settings_term)} #{"feature.connection.content.assign_template_alert.individual_action_message_2".translate(mentoring_connection: _mentoring_connection, messages_or_discussions: impacted_settings_downcase_term)}]
      [{ alert_messages: [alert_message] }]
    end
  end

  def get_terms_for_impacted_mentoring_model_settings(groups_for_alert, groups_to_settings_impacted_hash)
    is_forum_impacted = groups_for_alert.any? { |group| groups_to_settings_impacted_hash[group.id][:is_forum_impacted] }
    is_messaging_impacted = groups_for_alert.any? { |group| groups_to_settings_impacted_hash[group.id][:is_messaging_impacted] }

    if is_forum_impacted && is_messaging_impacted
      ["#{"feature.mentoring_model.information.Discussion_Boards".translate}/#{"feature.mentoring_model.description.message".translate}", "#{"feature.mentoring_model.information.discussions".translate}/#{"feature.profile.label.message".translate(count: 2)}"]
    elsif is_forum_impacted
      ["feature.mentoring_model.information.Discussion_Boards".translate, "feature.mentoring_model.information.discussions".translate]
    else
      ["feature.mentoring_model.description.message".translate, "feature.profile.label.message".translate(count: 2)]
    end
  end

  def get_link_to_group(group_id, group_name, group_status)
    group_link =
      if Group::Status::NOT_PUBLISHED_CRITERIA.include?(group_status)
        groups_path(tab: group_status, search_filters: { profile_name: group_name } )
      elsif !@current_program.admin_access_to_mentoring_area_disabled?
        group_path(group_id)
      end
    group_link.present? ? link_to(group_name, group_link, target: "_blank") : content_tag(:span, group_name, class: "font-bold")
  end

  def base_message_for_active_groups_alert(active_group_alert_messages, context, is_groups_bulk_action)
    return if context.nil? || active_group_alert_messages.empty?

    if context == :group
      translation_options = { count: active_group_alert_messages.size }
      translation_options[:mentoring_connection_term] = is_groups_bulk_action ? _mentoring_connections : _mentoring_connection
      "feature.connection.content.existing_groups_alert.following_set_already_actively_connected".translate(translation_options)
    elsif context == :user
      "feature.connection.content.existing_groups_alert.selected_users_already_connected".translate(mentoring_connections: _mentoring_connections)
    end
  end

  def base_message_for_non_active_groups_alert(non_active_group_alert_messages, non_active_group_status, is_groups_bulk_action)
    return if !is_groups_bulk_action || non_active_group_alert_messages.empty?

    translation_options = { mentoring_connections: _mentoring_connections, count: non_active_group_alert_messages.size }
    translation_options[:group_status] = GroupsHelper.state_to_string_downcase_map[non_active_group_status]
    "feature.connection.content.existing_groups_alert.following_set_status_connections".translate(translation_options)
  end

  def base_message_for_additional_users_alert(student_id_mentor_id_to_additional_users_map, is_groups_bulk_action)
    additional_user_ids = student_id_mentor_id_to_additional_users_map.values.flatten.uniq
    return if additional_user_ids.blank? || !is_groups_bulk_action

    translation_options = { count: additional_user_ids.size }
    translation_options[:mentoring_connection_term] = (student_id_mentor_id_to_additional_users_map.keys.size == 1) ? _mentoring_connection : _mentoring_connections
    "feature.bulk_match.content.additional_users_alert.following_user_added_to_drafted".translate(translation_options)
  end
end