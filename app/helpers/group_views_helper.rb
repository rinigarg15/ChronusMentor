module GroupViewsHelper

  def populate_group_row(group, group_view_columns, options = {})
    td_text = get_safe_string
    group_view_columns.each do |column|
      answers, names = get_group_list_view_answer(group, column, false, options)
      formated_answer = format_list_answer(answers, names , column, :for_csv => false)
      # Tried to code a very generic way of adding classes, for the below line.
      # But the related methods are very difficult to refactor and achieve that level of flexibility. So just adding the class for my feature :(
      td_text << content_tag(:td, formated_answer, class: list_view_row_class(column))
    end
    td_text
  end

  def list_view_row_class(group_view_column)
    (group_view_column.column_key == GroupViewColumn::Columns::Key::MENTORING_MODEL_TEMPLATES) ? "cjs_mentoring_model_list_view" : ""
  end

  def get_group_list_result_values(groups, group_view_columns, tab_number, options = {})
    tbody_value = get_safe_string
    role_based_activity = Group.get_role_based_details(groups, group_view_columns)

    groups.each do |group|
      options.merge!(build_role_based_activity_hash(role_based_activity, group.id))
      tbody_value << get_group_row_values(group, group_view_columns, tab_number, options)
    end
    tbody_value
  end

  def build_role_based_activity_hash(role_based_activity, group_id)
    return {
      slot_details: role_based_activity[:slot_details][group_id],
      login_activity: role_based_activity[:login_activity][group_id],
      scraps_activity: role_based_activity[:scraps_activity][group_id],
      posts_activity: role_based_activity[:posts_activity][group_id],
      role_id_name_hash: role_based_activity[:role_id_name_hash]
    }
  end

  def get_group_row_values(group, group_view_columns, tab_number, options = {})
    content_tag(:tr, :id => "group_pane_#{group.id}", :class => "cui_table_sort") do
      content_tag(:td, :class => "cjs_group_record_checkbox") do
        label_tag("cjs_groups_record_#{group.id}", "feature.group.label.select_this".translate(mentoring_connection: _mentoring_connection, connection_name: group.name), :for =>"cjs_groups_record_#{group.id}", :class => "sr-only") +
        content_tag(:input, get_safe_string, :type => "checkbox", :class => "cjs_groups_record", :id => "cjs_groups_record_#{group.id}", :value => "#{group.id}")
      end +
      populate_group_row(group, group_view_columns, options)
    end
  end

  def format_list_answer(answer, names, column, options = {})
    return format_user_answers(answer, names, column.profile_question, options) if column.ref_obj_type == GroupViewColumn::ColumnType::USER
    return format_group_question_answer(answer, column, options) if column.ref_obj_type == GroupViewColumn::ColumnType::GROUP
    return answer
  end

  def format_filetype_user_answer(answer, names, options = {})
    return format_filetype_user_answer_for_group_mentoring(answer, names, options) if answer.count > 1
    if answer[0].present?
      return ( options[:for_csv] ? answer[0][0] : link_to(answer[0][0], answer[0][1], :target => "_blank"))
    else
      return ""
    end
  end

  def format_filetype_user_answer_for_group_mentoring(answer, names, options = {})
    column_contents = get_safe_string
    answer.each_with_index do |ans, i|
      if options[:for_csv]
        column_contents += format_name_for_group_mentoring(names[i], :for_csv => true) + ans[0] + "\n" if ans.present?
      else
        column_contents += content_tag(:li, format_name_for_group_mentoring(names[i]) + link_to(ans[0], ans[1], :target => "_blank")) if ans.present?
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  def format_education_user_answer(answer, names, question, options = {})
    return format_education_user_answer_for_group_mentoring(answer, names, question, options) if answer.count > 1
    if answer[0].present?
      return prepare_more_less_answers(answer[0], question, options)
    else
      return ""
    end
  end

  def format_education_user_answer_for_group_mentoring(answer, names, question, options= {})
    column_contents = get_safe_string
    answer.each_with_index do |ans, i|
      column_content = prepare_more_less_answers(ans, question, options)
      if options[:for_csv]
        column_contents += (format_name_for_group_mentoring(names[i], :for_csv => true) + column_content) + "\n" if column_content.present?
      else
        column_contents += content_tag(:li, format_name_for_group_mentoring(names[i]) + column_content) if column_content.present?
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  def format_experience_user_answer(answer, names, question, options = {})
    return format_experience_user_answer_for_group_mentoring(answer, names, question, options) if answer.count > 1
    if answer[0].present?
      return prepare_more_less_answers(answer[0], question, options)
    else
      return ""
    end
  end

  def format_experience_user_answer_for_group_mentoring(answer, names, question, options = {})
    column_contents = get_safe_string
    answer.each_with_index do |ans, i|
      column_content = prepare_more_less_answers(ans, question, options)
      if options[:for_csv]
        column_contents += (format_name_for_group_mentoring(names[i], :for_csv => true) + column_content) + "\n" if column_content.present?
      else
        column_contents += content_tag(:li, format_name_for_group_mentoring(names[i]) + column_content) if column_content.present?
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  def format_publication_user_answer(answer, names, question, options = {})
    return format_publication_user_answer_for_group_mentoring(answer, names, question, options) if answer.reject(&:blank?).count > 1
    if answer[0].present?
      return prepare_more_less_answers(answer[0], question, options)
    else
      return ""
    end
  end

  def format_publication_user_answer_for_group_mentoring(answer, names, question, options = {})
    column_contents = get_safe_string
    answer.each_with_index do |ans, i|
      column_content = prepare_more_less_answers(ans, question, options)
      if column_content.present?
        name_formatted = (format_name_for_group_mentoring(names[i], :for_csv => options[:for_csv]) + column_content)
        column_contents += (options[:for_csv] ? (name_formatted + "\n") : content_tag(:li, name_formatted))
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  def format_manager_user_answer(answers, names, question, options = {})
    return format_manager_user_answer_for_group_mentoring(answers, names, question, options) if answers.reject(&:blank?).count > 1
    if answers[0].present?
      return format_manager_answer(answers[0], options)
    else
      return ""
    end
  end

  def format_manager_user_answer_for_group_mentoring(answers, names, question, options = {})
    column_contents = get_safe_string
    answers.each_with_index do |ans, i|
      column_content = prepare_more_less_answers([ans], question, options)
      if column_content.present?
        name_formatted = (format_name_for_group_mentoring(names[i], :for_csv => options[:for_csv]) + column_content)
        column_contents += (options[:for_csv] ? (name_formatted + "\n") : content_tag(:li, name_formatted))
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  def prepare_more_less_answers(answers, question, options = {})
    answers_arr = if question.education?
      answers.map { |a| safe_join(a.reject(&:blank?), ", ") }
    elsif question.experience?
      answers.map { |a| format_experience_answer(a, options) }
    elsif question.publication?
      answers.map { |a| format_publication_answer(a, options) }
    elsif question.manager?
      answers.map { |a| format_manager_answer(a, options) }
    end
    options[:for_csv] ? safe_join(answers_arr, "\n") : render_more_less_rows(answers_arr) if answers_arr
  end

  def format_simple_user_answer(answer, names, options = {})
    if answer.count > 1
      formated_answer = format_simple_user_answer_for_group_mentoring(answer, names, options)
    else
      formated_answer = answer[0] || ""
    end
    options[:truncate_size] ? render_more_less(formated_answer, options[:truncate_size]) : formated_answer
  end

  def format_simple_user_answer_for_group_mentoring(answer, names, options = {})
    column_contents = get_safe_string
    answer.each_with_index do |ans, i|
      if options[:for_csv]
        column_contents += (format_name_for_group_mentoring(names[i], options) + ans.html_safe) + "\n" if ans.present?
      else
        column_contents += content_tag(:li, format_name_for_group_mentoring(names[i]) + ans) if ans.present?
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  def format_group_question_answer(answer, column, options = {})
    if answer.present? &&  column.connection_question.try("file_type?".to_sym)
      return answer[0] if options[:for_csv]
      return link_to(answer[0], answer[1], :target => "_blank")
    end
    return answer
  end

  def group_view_sortable_actions(group_view_columns, sort_param, sort_order)
    header_th = get_safe_string
    roles_hsh = group_view_columns.present? ? group_view_columns[0].group_view.program.roles.includes(:translations, customized_term: :translations).index_by(&:id) : {}
    group_view_columns.each do |column|
      column_title = column.get_title(roles_hsh)
      html_options = {
        class: "cui-fixed-table-column whitespace-nowrap truncate-with-ellipsis ",
        data: {
          toggle: "tooltip",
          title: column_title
        },
        id: "column_#{column.id}"
      }
      if column.is_sortable?
        key = column.sorting_key(roles_hsh)
        order = (sort_param == key) ? sort_order : "both"
        html_options[:class] += " sort_#{order} pointer cjs_sortable_element"
        html_options[:data].merge!( {
          sort: key,
          url: groups_path(view: Group::View::LIST)
        } )
      end
      header_th += content_tag(:th, column_title, html_options)
    end
    header_th
  end

  def group_view_edit_column_mapper(optgroup, key)
    [optgroup, key].join(GroupViewColumn::COLUMN_SPLITTER)
  end

  def populate_group_view_default_options(group_view, tab_number)
    options_array = []
    program = group_view.program
    optgroup = GroupViewsController::GroupViewColumnGroup::DEFAULT
    invalid_column_keys = GroupViewColumn.get_invalid_column_keys(tab_number.to_i)

    selected_default_columns = group_view.get_group_view_columns(tab_number).select { |column| column.ref_obj_type == GroupViewColumn::ColumnType::NONE }
    selected_default_column_keys = selected_default_columns.collect {|col| [col.key, col.role_id].compact.join(GroupViewColumn::COLUMN_SPLITTER)}

    valid_default_column_keys = group_view.get_applicable_group_view_column_keys.select do |group_view_key|
      invalid_column_keys.exclude?(group_view_key.split(GroupViewColumn::COLUMN_SPLITTER)[0])
    end

    selected_default_column_keys.each do |key|
      options_array << [GroupViewColumn.get_default_title(key, program), group_view_edit_column_mapper(optgroup, key)]
    end

    (valid_default_column_keys - selected_default_column_keys).each do |key|
      options_array << [GroupViewColumn.get_default_title(key, program), group_view_edit_column_mapper(optgroup, key)]
    end
    options_for_select(options_array, selected_default_column_keys.map{|key| group_view_edit_column_mapper(optgroup, key)})
  end

  def populate_group_view_user_options(group_view_columns, role, profile_questions)
    options_array = []
    profile_questions ||= []
    optgroup = role.id

    selected_columns = group_view_columns.role_questions(role.id)
    selected_user_questions = selected_columns.collect(&:profile_question)
    selected_user_question_keys = selected_columns.collect(&:key)
    profile_questions.each do |pq|
      options_array << [pq.question_text, group_view_edit_column_mapper(optgroup, pq.id)]
    end
    options_for_select(options_array, selected_user_question_keys.map{|key| group_view_edit_column_mapper(optgroup, key)})
  end

  def populate_group_view_connection_options(group_view_columns, connection_questions)
    options_array = []
    connection_questions ||= []
    optgroup = GroupViewsController::GroupViewColumnGroup::CONNECTION

    selected_connection_questions = group_view_columns.group_questions.collect(&:connection_question)
    selected_connection_question_keys = group_view_columns.group_questions.collect(&:key)

    selected_connection_questions.each do |cq|
      options_array << [cq.question_text, group_view_edit_column_mapper(optgroup, cq.id)]
    end

    (connection_questions - selected_connection_questions).each do |cq|
      options_array << [cq.question_text, group_view_edit_column_mapper(optgroup, cq.id)]
    end

    options_for_select(options_array, selected_connection_question_keys.map{|key| group_view_edit_column_mapper(optgroup, key)})
  end


  def format_name_for_group_mentoring(name, options = {})
    return get_safe_string + name.to_s + " - " if options[:for_csv]
    return content_tag(:span, get_safe_string + name.to_s + " - ", :class => "strong")
  end

  def get_group_list_view_answer(group, column, for_csv, options = {})
    case column.ref_obj_type
    when GroupViewColumn::ColumnType::GROUP
      return get_group_answer(group, column), []
    when GroupViewColumn::ColumnType::USER
      return get_all_user_answers(group, column)
    when GroupViewColumn::ColumnType::NONE
      return get_default_answer(group, column, for_csv, options), []
    end
  end

  def get_all_user_answers(group, column)
    answers = []
    user_names = []
    users = group.members.where("connection_memberships.role_id = ?", column.role_id).includes(:member)
    profile_question = column.profile_question
    users.each do |user|
      answer = user.answer_for(profile_question)
      answers << get_user_answer(answer, profile_question, user.member)
      user_names << display_member_name(user.member)
    end
    return answers, user_names
  end

  def get_user_answer(answer, profile_question, ref_obj = nil)
    # file
    if profile_question.file_type?
      answer.present? && !answer.unanswered? ? [answer.attachment_file_name, answer.attachment.url] : nil
    # education
    elsif profile_question.education?
      (answer.present? && !answer.unanswered? ? answer.educations : []).map do |education|
        Education.export_column_names.map { |field, _| education[field] }
      end
    # experience
    elsif profile_question.experience?
      (answer.present? && !answer.unanswered? ? answer.experiences : []).map do |experience|
        Experience.export_column_names.map { |field, _| experience[field] }
      end
    # publication
    elsif profile_question.publication?
      (answer.present? && !answer.unanswered? ? answer.publications : []).map do |publication|
        Publication.export_column_names.map { |field, _| field == :date ? publication.send('formatted_' + field.to_s) : publication[field] }
      end
    # manager
    elsif profile_question.manager?
      return [] if (answer.blank? || answer.unanswered?)
      manager = answer.manager
      Manager.export_column_names.map { |field, _| manager[field] }
    # email
    elsif profile_question.email_type?
      ref_obj.email
    # all others
    elsif profile_question.choice_or_select_type?
      answer.present? ? answer.selected_choices_to_str(profile_question) : nil
    else
      answer.try(:answer_text).to_s.strip
    end
  end

  def get_group_answer(group, column)
    common_question = column.connection_question
    answer = group.answer_for(common_question)
    # file
    if common_question.file_type?
      answer.present? ? [answer.attachment_file_name, answer.attachment.url] : nil
    elsif common_question.choice_or_select_type?
      answer.present? ? answer.selected_choices_to_str(common_question) : '-'
    else
      answer.try(:answer_text) ? answer.try(:answer_text).to_s.strip : '-'
    end
  end

  def get_default_answer(group, column, for_csv, options = {})
    key = column.column_key
    case key
    when GroupViewColumn::Columns::Key::NAME
      render_group_name(group, @current_user, :disable_link => for_csv)
    when GroupViewColumn::Columns::Key::MEMBERS
      users = group.memberships.includes(user: :member).where(role_id: column.role_id).collect(&:user)
      users = for_csv ? users.collect{|user| user.name(name_only: true) + owner_content_for_user_name(group, user)} : users.collect{|user| link_to_user_for_admin(user, content_text: display_member_name(user.member) + owner_content_for_user_name(group, user))}
      users.join(", ").html_safe
    when GroupViewColumn::Columns::Key::NOTES
      group.notes ? group.notes : ''
    when GroupViewColumn::Columns::Key::ACTIVE_SINCE
      formatted_time_in_words(group.published_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::START_DATE
      DateTime.localize(group.start_date, format: :short)
    when GroupViewColumn::Columns::Key::CREATED_BY
      group.created_by.nil? ? "-" : display_member_name(group.created_by)
    when GroupViewColumn::Columns::Key::DRAFTED_SINCE
      formatted_time_in_words(group.created_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::AVAILABLE_SINCE
      formatted_time_in_words(group.pending_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::PENDING_REQUESTS_COUNT
      group.active_project_requests.count.to_s
    when GroupViewColumn::Columns::Key::LAST_ACTIVITY
      last_activity_time = @is_my_connections_view ? formatted_time_in_words(group.last_activity_at, :no_ago => for_csv, :no_time => true) : formatted_time_in_words(group.last_member_activity_at, :no_ago => for_csv, :no_time => true)
      last_activity_time ? last_activity_time : "feature.connection.content.No_activity_yet".translate
    when GroupViewColumn::Columns::Key::EXPIRES_ON
      content = formatted_time_in_words(group.expiry_time, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::CLOSED_BY
      if group.auto_terminated?
        "feature.connection.content.auto_closed".translate
      elsif group.closed_by.nil?
        group.program.organization.admin_custom_term.term
      else
        display_member_name(group.closed_by)
      end
    when GroupViewColumn::Columns::Key::CLOSED_ON # CLOSED_ON AND REJECTED_AT Filter with same closed_at but REJECTED AT is used for PBE Programs
      formatted_time_in_words(group.closed_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::REASON
      group.closure_reason.reason
    when GroupViewColumn::Columns::Key::GOALS_STATUS_V2
      mentoring_model_goals = group.mentoring_model_goals
      if mentoring_model_goals.any?
        required_tasks = group.mentoring_model_tasks.select(&:required?)
        content = []
        mentoring_model_goals.each_with_index do |goal, index|
          content << get_safe_string + "feature.mentoring_model.label.goal_title_with_space_and_completion_percent".translate(title: goal.title, percent: goal.completion_percentage(required_tasks).to_s)
        end
        if options[:csv_export].present?
          content.join(", ").html_safe
        else
          content.join(tag(:br)).html_safe
        end
      else
        "feature.mentoring_model.header.no_goals_yet".translate
      end
    when GroupViewColumn::Columns::Key::TASKS_OVERDUE_STATUS_V2
      group.mentoring_model_tasks.overdue.count.to_s
    when GroupViewColumn::Columns::Key::TASKS_PENDING_STATUS_V2
      group.mentoring_model_tasks.pending.count.to_s
    when GroupViewColumn::Columns::Key::TASKS_COMPLETED_STATUS_V2
      group.mentoring_model_tasks.status(MentoringModel::Task::Status::DONE).count.to_s
    when GroupViewColumn::Columns::Key::MILESTONES_OVERDUE_STATUS_V2
      group.mentoring_model_milestones.overdue.count.to_s
    when GroupViewColumn::Columns::Key::MILESTONES_PENDING_STATUS_V2
      group.mentoring_model_milestones.pending.count.to_s
    when GroupViewColumn::Columns::Key::MILESTONES_COMPLETED_STATUS_V2
      group.mentoring_model_milestones.completed.count.to_s
    when GroupViewColumn::Columns::Key::MEETINGS_ACTIVITY
      group.meetings_enabled? ? group.meetings_activity(column.role_id)[:role].to_s : '-'
    when GroupViewColumn::Columns::Key::MESSAGES_ACTIVITY
      group.scraps_enabled? ? options[:scraps_activity].try(:[], column.role_id).to_i : '-'
    when GroupViewColumn::Columns::Key::POSTS_ACTIVITY
      group.forum_enabled? ? options[:posts_activity].try(:[], column.role_id).to_i : '-'
    when GroupViewColumn::Columns::Key::LOGIN_ACTIVITY
      options[:login_activity].try(:[], column.role_id).to_i
    when GroupViewColumn::Columns::Key::MENTORING_MODEL_TEMPLATES
      Nokogiri::HTML.parse(display_mentoring_model_info(group.mentoring_model, true, for_csv).to_s).text
    when GroupViewColumn::Columns::Key::PROPOSED_BY
      group.created_by.nil? ? "feature.connection.header.removed_user_label".translate : (for_csv ? (group.created_by.name(name_only: true).to_s + owner_content_for_user_name(group, group.created_by)): link_to_user_for_admin(group.created_by, :content_text => display_member_name(group.created_by.member) + owner_content_for_user_name(group, group.created_by)))
    when GroupViewColumn::Columns::Key::PROPOSED_AT
      formatted_time_in_words(group.created_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::REJECTED_BY
      group.closed_by.nil? ? "feature.connection.header.removed_user_label".translate : group.closed_by.name.to_s
    when GroupViewColumn::Columns::Key::REJECTED_AT
      formatted_time_in_words(group.closed_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::WITHDRAWN_AT
      formatted_time_in_words(group.closed_at, :no_ago => for_csv, :no_time => true)
    when GroupViewColumn::Columns::Key::WITHDRAWN_BY
      group.closed_by.nil? ? "feature.connection.header.removed_user_label".translate : group.closed_by.name.to_s
    when GroupViewColumn::Columns::Key::SURVEY_RESPONSES
      admin_role = group.program.roles.with_name(RoleConstants::ADMIN_NAME)
      group.can_manage_mm_engagement_surveys?(admin_role) ? group.unique_survey_answers(false).count : "-"
    when GroupViewColumn::Columns::Key::TOTAL_SLOTS
      options[:slot_details].present? ? options[:slot_details][column.role_id][:total_slots] : group.membership_settings.where(role_id: column.role_id).first.try(:max_limit)
    when GroupViewColumn::Columns::Key::SLOTS_TAKEN
      options[:slot_details].present? ? options[:slot_details][column.role_id][:slots_taken] : group.memberships.where(role_id: column.role_id).size
    when GroupViewColumn::Columns::Key::SLOTS_REMAINING
      total_slots = options[:slot_details].present? ? options[:slot_details][column.role_id][:total_slots] : group.membership_settings.where(role_id: column.role_id).first.try(:max_limit)
      slots_taken = options[:slot_details].present? ? options[:slot_details][column.role_id][:slots_taken] : group.memberships.where(role_id: column.role_id).size
      if total_slots.present?
        remaining_slots = total_slots - slots_taken
        remaining_slots = (remaining_slots < 0) ? 0 : remaining_slots
      end
      remaining_slots
    end
  end
end
