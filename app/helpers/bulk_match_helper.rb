module BulkMatchHelper

  def create_students_json_array(students = [], options)
    result_array = []
    students.each do |student|
      student_hash = get_user_common_details(student)
      student_hash.merge!(get_student_details(student, options[:selected_mentors], options[:suggested_mentors], options))
      result_array << student_hash
    end
    return result_array.to_json
  end

  def create_mentors_json_array(mentors = [], mentor_slot_hash = {}, options = {})
    result_array = []
    mentors.each do |mentor|
      mentor_hash = get_user_common_details(mentor, {is_mentor: true, recommend_mentors: options[:recommend_mentors]})
      mentor_hash.merge!(get_mentor_details(mentor, mentor_slot_hash, options))
      result_array << mentor_hash
    end
    return result_array.to_json
  end

  def get_mentor_details(mentor, mentor_slot_hash, options)
    mentor_options = {}
    if is_mentor_to_mentee_view?(options[:orientation_type])
      mentor_options.merge!(get_mentor_details_for_mentor_to_mentee_view(mentor, mentor_slot_hash, options[:selected_students], options[:suggested_students], options))
    else
      mentor_options.merge!(get_mentor_availabilty_details(mentor, options[:program], mentor_slot_hash, options[:pickable_slots], options[:recommended_count]))
    end
    mentor_options
  end

  def get_student_details(student, selected_mentors = {}, suggested_mentors = {}, options)
    student_options = {}
    bulk_match_type = options[:bulk_match_type] || BulkMatch.name
    if is_mentee_to_mentor_view?(options[:orientation_type])
      student_options.merge!(get_selected_and_suggested_mentor_details(student, selected_mentors, suggested_mentors))
      student_options.merge!(get_group_details(options[:group_status], student, selected_mentors, bulk_match_type, {}))
      student_options.merge!(get_primary_and_secondary_labels(student_options[:group_status], bulk_match_type))
    end
    student_options.merge!(get_users_links_for_drafted_and_connected_groups(student, true, options))
    student_options.merge!(get_pickable_slots(student, options[:pickable_slots], options[:orientation_type]))
    student_options
  end

  def get_mentor_details_for_mentor_to_mentee_view(mentor, mentor_slot_hash, selected_students = {}, suggested_students = {}, options)
    mentor_options = {}
    mentor_options.merge!(get_selected_and_suggested_student_details(mentor, selected_students, suggested_students))
    mentor_options.merge!(get_group_details(options[:group_status], mentor, selected_students, "BulkMatch", {pickable_slots: options[:pickable_slots]}))
    mentor_options.merge!(get_mentor_availabilty_details(mentor, options[:program], mentor_slot_hash, options[:pickable_slots], options[:recommended_count]))
    mentor_options.merge!(get_users_links_for_drafted_and_connected_groups(mentor, false, options))
    mentor_options.merge!(get_primary_and_secondary_labels(mentor_options[:group_status], "BulkMatch"))
    mentor_options
  end

  def get_users_links_for_drafted_and_connected_groups(user, for_mentee, options)
    group_users_options = {}
    group_users_options.merge!(group_users_links_for_bulk_match(user, :drafted, options[:drafted_groups], for_mentee))
    group_users_options.merge!(group_users_links_for_bulk_match(user, :connected, options[:active_groups], for_mentee))
    return group_users_options
  end

  def get_primary_and_secondary_labels(status, bulk_match_type)
    bulk_match_type == BulkMatch.name ? get_primary_and_secondary_labels_for_bulk_match(status) : get_primary_and_secondary_labels_for_bulk_recommendation(status)
  end

  def get_pickable_slots(student, student_slot_hash, orientation_type)
    return {} if is_mentee_to_mentor_view?(orientation_type)
    options = {
      pickable_slots: student_slot_hash[student.id]
    }
    options
  end

  def get_primary_and_secondary_labels_for_bulk_match(status)
    options = {}
    case status
      when "feature.bulk_match.js_message.selected".translate
        options.merge!(primary_action_label: "feature.bulk_match.js_message.draft_match_v1".translate, secondary_action_label: "feature.bulk_match.js_message.publish".translate)
      when "feature.bulk_match.js_message.drafted".translate
        options.merge!(primary_action_label: "feature.bulk_match.js_message.publish".translate, secondary_action_label: "feature.bulk_match.js_message.discard_draft".translate)
      else
        options.merge!(primary_action_label: "", secondary_action_label: "")
    end
    options
  end

  def get_primary_and_secondary_labels_for_bulk_recommendation(status)
    options = {}
    case status
      when "feature.bulk_match.js_message.selected".translate
        options.merge!(primary_action_label: "feature.bulk_recommendation.action.draft".translate, secondary_action_label: "feature.bulk_recommendation.js_message.send_recommendations".translate)
      when "feature.bulk_match.js_message.drafted".translate
        options.merge!(primary_action_label: "feature.bulk_recommendation.js_message.send_recommendations".translate, secondary_action_label: "feature.bulk_match.js_message.discard_draft".translate)
      else
        options.merge!(primary_action_label: "feature.bulk_recommendation.action.discard".translate, secondary_action_label: "")
    end
    options
  end

  def get_user_common_details(user, options = {})
    user_id = user.id
    user_name = display_member_name(user.member)
    size_sym = options[:is_mentor] && options[:recommend_mentors] ? :small : :medium
    options = {
      :id => user_id,
      :name => user_name,
      :picture_with_profile_url => (user_picture(user, {no_name: true, size: size_sym, member_name: user_name, bulk_match_view: true, row_fluid: true}, { })),
      :name_with_profile_url => link_to_user_for_admin(user, :content_text => user_name),
    }
    options
  end

  def get_mentor_availabilty_details(mentor, current_program, mentor_slot_hash ={}, pickable_slots= {}, recommended_count ={})
    options = {
      :slots_available => mentor_slot_hash[mentor.id],           # Number of mentoring slots available for mentor in general
      :pickable_slots => pickable_slots[mentor.id],              # Number of remaining times mentor can be matched/recommended
      :recommended_count => recommended_count[mentor.id],        # Number of times mentor used in Bulk Match/Recommendation
      :connections_count => mentor.mentoring_groups.active.size, # Number of Mentoring connections active(published)
      :mentor_prefer_one_time_mentoring_and_program_allowing => current_program.consider_mentoring_mode? && (mentor.mentoring_mode == User::MentoringMode::ONE_TIME)
    }
    options
  end

  def get_selected_and_suggested_mentor_details(student, selected_mentors, suggested_mentors)
    student_id = student.id
    options = {
      :selected_mentors => selected_mentors[student_id],
      :selected_count => selected_mentors[student_id].try(:count).to_i,
      :suggested_mentors => suggested_mentors[student_id],
      :suggested_mentors_length => BulkMatch::DEFAULT_SUGGESTION_LENGTH,
    }
    options
  end

  def get_selected_and_suggested_student_details(mentor, selected_students, suggested_students)
    mentor_id = mentor.id
    options = {
      :selected_students => selected_students[mentor_id],
      :selected_count => selected_students[mentor_id].try(:count).to_i,
      :suggested_students => suggested_students[mentor_id],
      :suggested_students_length => BulkMatch::DEFAULT_SUGGESTION_LENGTH,
    }
    options
  end

  def get_group_details(group_status = {}, user, selected_users, bulk_match_type, group_options)
    user_id = user.id
    options = {
      :group_status => group_status[user_id].present? ? get_status_label(group_status[user_id][:status], bulk_match_type) : (selected_users[user_id].try(:length).to_i == 0 ? get_unmatched_label(user, group_options) : "feature.bulk_match.js_message.selected".translate),
      :group_id => group_status[user_id].try(:[], :group_id),
    }
    options
  end

  def get_unmatched_label(user, group_options)
    if group_options.present? && group_options[:pickable_slots][user.id] == 0
      "feature.bulk_match.js_message.not_available".translate
    else
      "feature.bulk_match.js_message.unmatched_v1".translate
    end
  end

  def get_status_label(status, bulk_match_type)
    if bulk_match_type == BulkMatch.name
      get_bulk_match_status_label(status)
    else
      get_bulk_match_recommendation_label(status)
    end
  end

  def get_bulk_match_status_label(status)
    if status == Group::Status::DRAFTED
      "feature.bulk_match.js_message.drafted".translate
    elsif status == Group::Status::ACTIVE || status == Group::Status::INACTIVE
      "feature.bulk_match.js_message.published".translate
    end
  end

  def get_bulk_match_recommendation_label(status)
    if status == MentorRecommendation::Status::DRAFTED
      "feature.bulk_match.js_message.drafted".translate
    elsif status == MentorRecommendation::Status::PUBLISHED
      "feature.bulk_recommendation.js_message.published".translate
    end
  end

  def render_mentoring_model_selector(mentoring_models, options = {})
    return unless @current_program.mentoring_connections_v2_enabled?
    default_mentoring_model_id = mentoring_models.find(&:default?).id
    mentoring_model_options = mentoring_models.collect { |mentoring_model| [mentoring_model_pane_title(mentoring_model), mentoring_model.id] }
    element_id = "cjs_assign_mentoring_model"
    element_id += "_#{options[:id_suffix]}" if options[:id_suffix].present?
    control_group do
      get_mentoring_model_selector_label(element_id, options) +
      controls do
        select_tag(:mentoring_model, options_for_select(mentoring_model_options, default_mentoring_model_id), id: element_id, class: "form-control cjs_assign_mentoring_model")
      end
    end
  end

  def build_bulk_match_vars(bulk_match)
    klass = bulk_match.class.name.underscore
    klass_plural = klass.pluralize
    bulk_match_vars = {
      :sort_order => bulk_match.sort_order,
      :sort_value => bulk_match.sort_value || 'best_mentor_score',
      :show_drafted => bulk_match.show_drafted,
      :show_published => bulk_match.show_published,
      :request_notes => bulk_match.request_notes,
      :update_status_path => send("update_#{klass}_pair_#{klass_plural}_path"),
      :bulk_update_status_path => send("bulk_update_#{klass}_pair_#{klass_plural}_path"),
      :update_settings_path => send("update_settings_#{klass_plural}_path", format: :js),
      :fetch_notes_path => fetch_notes_bulk_matches_path,
      :summary_details_path => send("fetch_summary_details_bulk_matches_path"),
      :alter_pickable_slots_path => send("alter_pickable_slots_#{klass_plural}_path"),
      :groups_alert_path => groups_alert_bulk_matches_path,
      :recommend_mentors => bulk_match.is_a?(BulkRecommendation),
      :type => bulk_match.type,
      :max_suggestion_count => bulk_match.max_suggestion_count || 1,
      :range => 'display_string.NA'.translate,
      :average_score => 'display_string.NA'.translate,
      :deviation => 'display_string.NA'.translate,
      update_type: {
        draft: AbstractBulkMatch::UpdateType::DRAFT,
        publish: AbstractBulkMatch::UpdateType::PUBLISH,
        discard: AbstractBulkMatch::UpdateType::DISCARD
      },
      orientation_type: bulk_match.orientation_type
    }.to_json
    bulk_match_vars
  end

  def group_users_links_for_bulk_match(bulk_match_user, key, groups = [], for_mentee = true)
    user_id_group_id_list, users = get_group_users_for_bulk_match(bulk_match_user, groups, for_mentee)
    user_links = safe_join(users.uniq.collect { |user| link_to_user_for_admin(user, content_text: display_member_name(user.member)) }, COMMON_SEPARATOR)
    if for_mentee
      { "#{key}_mentor_id_group_id_list" => user_id_group_id_list, "#{key}_mentors_html" => user_links }.symbolize_keys!
    else
      { "#{key}_student_id_group_id_list" => user_id_group_id_list, "#{key}_students_html" => user_links }.symbolize_keys!
    end
  end

  def get_group_users_for_bulk_match(bulk_match_user, groups, for_mentee)
    user_id_group_id_list = []
    users = []

    user_groups = for_mentee ? bulk_match_user.studying_groups : bulk_match_user.mentoring_groups
    groups &= user_groups
    groups.each do |group|
      group_users = for_mentee ? group.mentors : group.students
      group_users.each do |group_user|
        user_id_group_id_list << [group_user.id, group.id]
        users << group_user
      end
    end
    return [user_id_group_id_list, users]
  end

  def get_view_options(admin_view_role_hash, role)
    admin_view_role_hash[role].collect{|view| {:id => view.id, :title => h(view.title), :icon => view.favourite_image_path} }
  end

  def get_view_user_details(current_program, user_ids)
    return unless user_ids
    drafted_group_ids = current_program.groups.drafted.pluck(:id)
    active_group_ids = current_program.groups.active.pluck(:id)
    connected_user_ids = current_program.connection_memberships.where(user_id: user_ids, group_id: active_group_ids).pluck("DISTINCT user_id")
    drafted_user_ids = current_program.connection_memberships.where(user_id: user_ids - connected_user_ids, group_id: drafted_group_ids).pluck("DISTINCT user_id")
    connected_user_ids_size = connected_user_ids.size
    drafted_user_ids_size = drafted_user_ids.size
    {
      connected: connected_user_ids_size,
      drafted: drafted_user_ids_size,
      unconnected: user_ids.size - connected_user_ids_size - drafted_user_ids_size
    }
  end

  def get_publish_action_label(bulk_match_type = BulkMatch.name)
    case bulk_match_type
    when BulkMatch.name
      "feature.bulk_match.js_message.publish".translate
    when BulkRecommendation.name
      "feature.bulk_recommendation.js_message.send_recommendations".translate
    end
  end

  def bulk_match_action_text(bulk_match, action_type, display_request_message, notes)
    if action_type.present?
      action_type = get_translated_text(action_type, bulk_match: bulk_match)
      if display_request_message
        action_type
      elsif notes.present?
        "feature.bulk_match.header.update_notes_with_action".translate(action: action_type)
      else
        "feature.bulk_match.header.add_notes_with_action".translate(action: action_type)
      end
    else
      notes.present? ? "feature.bulk_match.header.update_notes".translate : "feature.bulk_match.header.add_notes".translate
    end
  end

  def get_translated_text(action_type, options = {})
    case action_type
    when AbstractBulkMatch::UpdateType::DRAFT
      'feature.bulk_match.js_message.draft'.translate
    when AbstractBulkMatch::UpdateType::PUBLISH
      get_publish_action_label(options[:bulk_match].try(:type))
    when AbstractBulkMatch::UpdateType::DISCARD
      'feature.bulk_match.js_message.discard'.translate
    end
  end

  def get_drafted_and_published_labels_for_settings(recommend_mentors, orientation_type)
    if recommend_mentors
      ["feature.bulk_recommendation.label.show_drafted".translate, "feature.bulk_recommendation.label.show_published".translate]
    elsif is_mentee_to_mentor_view?(orientation_type)
      ["feature.bulk_match.label.show_drafted_v1".translate(mentees: _mentees, mentoring_connections: _mentoring_connections), "feature.bulk_match.label.show_published_v1".translate(mentees: _mentees, mentoring_connections: _mentoring_connections)]
    else
      ["feature.bulk_match.label.show_drafted_mentors".translate(mentors: _mentors, mentoring_connections: _mentoring_connections), "feature.bulk_match.label.show_published_mentors".translate(mentors: _mentors, mentoring_connections: _mentoring_connections)]
    end
  end

  def get_max_pickable_slots_label_for_settings(recommend_mentors, orientation_type)
    if recommend_mentors
      ["feature.bulk_recommendation.label.mentees_per_mentor".translate(mentor: _mentor), "feature.bulk_recommendation.content.max_pickable_slots_tooltip".translate(:mentor => _mentor, :mentors => _mentors)]
    elsif is_mentee_to_mentor_view?(orientation_type)
      ["feature.bulk_match.label.users_per_suggested_user".translate(role_plural: _mentees, suggested_role: _mentor), "feature.bulk_match.content.max_pickable_slots_tooltip_for_user".translate(role: _mentor)]
    else
      ["feature.bulk_match.label.users_per_suggested_user".translate(suggested_role: _mentee, role_plural: _mentors), "feature.bulk_match.content.max_pickable_slots_tooltip_for_user".translate(role: _mentee)]
    end
  end

  def is_mentee_to_mentor_view?(orientation_type)
    orientation_type == BulkMatch::OrientationType::MENTEE_TO_MENTOR
  end

  def is_mentor_to_mentee_view?(orientation_type)
    orientation_type == BulkMatch::OrientationType::MENTOR_TO_MENTEE
  end

  def get_orientation_based_role_params(student, mentor, orientation_type)
    student_name = student.name(name_only: true)
    mentor_name = mentor.name(name_only: true)
    if is_mentee_to_mentor_view?(orientation_type)
      return [_mentee, _mentor, student_name, mentor_name, _mentees]
    else
      return [_mentor, _mentee, mentor_name, student_name, _mentors]
    end
  end

  private

  def get_mentoring_model_selector_label(element_id, options = {})
    return get_safe_string if options[:without_label].present?
    label_tag(:mentoring_model, "feature.multiple_templates.header.connection_multiple_templates_title_v1".translate(Mentoring_Connection: _Mentoring_Connection),  for: element_id, class: "control-label")
  end

end