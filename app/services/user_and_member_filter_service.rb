class UserAndMemberFilterService
  extend DateProfileFilter

  def self.filter_members_based_on_user_status(member_ids, filter_params)
    return member_ids unless filter_params[:member_status].present? && filter_params[:member_status][:user_state].present?
    case filter_params[:member_status][:user_state].to_i
    when AdminView::UserState::MEMBER_WITH_ACTIVE_USER
      Member.where(id: member_ids).joins(:users).where("users.state='#{User::Status::ACTIVE}'").pluck("members.id").uniq
    when AdminView::UserState::MEMBER_WITHOUT_ACTIVE_USER
      # If Member State is Dormant or when member does not have any user active status
      Member.where(id: member_ids).joins("LEFT OUTER JOIN users ON users.member_id=members.id").group("members.id").select("GROUP_CONCAT(DISTINCT users.state) AS user_uniq_status_list, members.id").select {|member| member.user_uniq_status_list.nil? || member.user_uniq_status_list.split(",").all? {|state| state != User::Status::ACTIVE} }.collect(&:id)
    when AdminView::UserState::IGNORE_USER_STATUS
      member_ids
    end
  end

  def self.apply_profile_filtering(user_or_member_ids, profile_field_filters, options = {})
    user_or_member_superset = user_or_member_ids
    set_select_cond_and_program_cond(options[:is_program_view], options[:program_id])

    for_filter_type, filter_options = get_for_filter_type_and_filter_options(options)
    ignored_fields = []
    grouped_profile_field_filters = get_grouped_profile_field_filters(profile_field_filters)
    profile_field_filters.each do |filter|
      profile_question = get_profile_question(filter, for_filter_type)
      profile_question_scope = for_filter_type ? nil : AdminViewColumn.find(filter["field"].split("column").last).column_sub_key
      if should_filter_profile_question?(profile_question, ignored_fields, filter)
        filter = handle_filter_by_question_type(profile_question, filter, ignored_fields, grouped_profile_field_filters)
        user_or_member_superset = get_filtered_user_or_member_superset({profile_question: profile_question, filter: filter}, user_or_member_superset, filter_options.merge!({profile_question_scope: profile_question_scope}), options)
      end
    end
    return user_or_member_superset
  end

  private

  def self.get_for_filter_type_and_filter_options(options_hash)
    [
      (options_hash[:for_survey_response_filter] || options_hash[:for_report_filter] || options_hash[:for_groups_index_filter]),
      (options_hash.delete(:filter_options) || {})
    ]
  end

  def self.handle_filter_by_question_type(profile_question, filter, ignored_fields, grouped_profile_field_filters)
    if profile_question.date? && date_profile_filter_from_admin_view?(filter)
      ignored_fields << filter["field"] if (grouped_profile_field_filters[filter["field"]].size > 1)
      from_date = grouped_profile_field_filters[filter["field"]].first.try(:[], "value")
      to_date = grouped_profile_field_filters[filter["field"]].second.try(:[], "value")
      filter["value"] = "#{from_date || to_date}#{DATE_RANGE_SEPARATOR}#{to_date || from_date}"
    end
    filter
  end

  def self.should_filter_profile_question?(profile_question, ignored_fields, filter)
    profile_question.present? && !ignored_fields.include?(filter["field"])
  end

  def self.get_filtered_user_or_member_superset(profile_question_and_filter, user_or_member_superset, filter_options, options)
    profile_question = profile_question_and_filter[:profile_question]
    filter = profile_question_and_filter[:filter]
    value = get_value(profile_question, filter, options)
    operator = filter["operator"] || SurveyResponsesDataService::Operators::CONTAINS
    response_that_match_filter(operator, value, profile_question, user_or_member_superset, filter_options)
  end

  def self.get_value(profile_question, filter, options)
    return [filter["value"]] unless profile_question.choice_or_select_type?

    if options[:for_report_filter]
      filter["choice"]
    else
      filter["value"]
    end
  end

  def self.response_that_match_filter(operator, value, profile_question, user_or_member_superset, options = {})
    mem = ActiveRecord::Base.connection.quote("Member")
    case operator
    when SurveyResponsesDataService::Operators::CONTAINS
      return users_or_members_with_answer_that_contains(value, profile_question, mem, user_or_member_superset, options)
    when SurveyResponsesDataService::Operators::NOT_CONTAINS
      return users_or_members_with_answer_that_does_not_contain(value, profile_question, mem, user_or_member_superset, options)
    when SurveyResponsesDataService::Operators::FILLED
      return users_or_members_with_answer_filled(profile_question, mem, user_or_member_superset)
    when SurveyResponsesDataService::Operators::NOT_FILLED
      return users_or_members_with_answer_not_filled(profile_question, mem, user_or_member_superset)
    when SurveyResponsesDataService::Operators::DATE_TYPE
      return filter_users_or_members_on_date_profile_question(value, profile_question, user_or_member_superset, mem)
    end
  end

  def self.filter_users_or_members_on_date_profile_question(value, profile_question, user_or_member_superset, mem)
    query_suffix = "AND users.program_id = #{@scoped_program_id}" if @program_cond.present?
    user_or_member_superset & ActiveRecord::Base.connection.select_values(get_date_query(value.first, query_prefix: "#{@select_cond} #{profile_question_answer_join_query(mem)}", join_date_answers: true, profile_question: profile_question, query_suffix: query_suffix))
  end

  def self.users_or_members_with_answer_that_contains(value, profile_question, mem, user_or_member_superset, options = {})
    if profile_question.file_type?
      single_choice = value.size == 1
      if single_choice
        if value.first.to_boolean
          user_or_member_ids = users_or_members_with_answer_filled(profile_question, mem, user_or_member_superset)
        else
          user_or_member_ids = users_or_members_with_answer_not_filled(profile_question, mem, user_or_member_superset)
        end
      end
    else
      ans_cond = get_answer_condition(profile_question, value, options)
      query = users_or_members_who_answered_with_query(ans_cond, mem, profile_question.id)
      all_users_or_members = ActiveRecord::Base.connection.select_values(query)
      user_or_member_ids =  (user_or_member_superset & all_users_or_members)
    end
    return user_or_member_ids
  end

  def self.users_or_members_with_answer_that_does_not_contain(value, profile_question, mem, user_or_member_superset, options = {})
    removed_user_or_member_ids = users_or_members_with_answer_that_contains(value, profile_question, mem, user_or_member_superset)
    options[:removed_user_or_member_ids] = removed_user_or_member_ids if options[:get_removed_user_or_member_ids]
    (user_or_member_superset - removed_user_or_member_ids)
  end

  def self.users_or_members_with_answer_filled(profile_question, mem, user_or_member_superset)
    all_users_or_members = ActiveRecord::Base.connection.select_values(users_or_members_who_answered_query(mem, profile_question.id))
    (user_or_member_superset & all_users_or_members)
  end

  def self.users_or_members_with_answer_not_filled(profile_question, mem, user_or_member_superset)
    user_or_member_superset - users_or_members_with_answer_filled(profile_question, mem, user_or_member_superset)
  end

  def self.set_select_cond_and_program_cond(is_program_view, program_id)
    @select_cond, @program_cond = if is_program_view
      ["SELECT DISTINCT users.id FROM users join members on users.member_id = members.id", "users.program_id = #{program_id} AND "]
    else
      ["SELECT DISTINCT members.id FROM members", ""]
    end
    @scoped_program_id = program_id if @program_cond.present?
  end

  def self.get_profile_question(filter, for_survey_response_or_meeting_filter)
    if for_survey_response_or_meeting_filter
      ProfileQuestion.find(filter["field"].split("column").last.to_i)
    else
      AdminViewColumn.find(filter["field"].split("column").last).profile_question
    end
  end

  def self.get_answer_condition(profile_question, value, options = {})
    if profile_question.choice_or_select_type?
      @answer_choices_join ||= "LEFT JOIN answer_choices ON (answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type = \'#{ProfileAnswer.name}\')"
      "(answer_choices.question_choice_id IN (#{value}))"
    elsif profile_question.location? && options[:profile_question_scope]
      @locations_join ||= "LEFT JOIN locations ON locations.id = profile_answers.location_id"
      value.map { |val| "locations.#{options[:profile_question_scope]} LIKE #{val.format_for_mysql_query(delimit_with_percent: true)}" }.join(' OR ')
    # date profile question will be handled here for admin view kendo filter
    elsif profile_question.date?
      @date_answers_join ||= join_date_answers(join_type: "left")
      get_date_query(value.first, exclude_where: true)
    else
      value.map { |val| "profile_answers.answer_text LIKE #{val.format_for_mysql_query(delimit_with_percent: true)}" }.join(' OR ')
    end
  end

  def self.users_or_members_who_answered_query(mem, question_id)
    "#{@select_cond}
    #{profile_question_answer_join_query(mem)}
    LEFT JOIN answer_choices ON answer_choices.ref_obj_id = profile_answers.id AND answer_choices.ref_obj_type = \'#{ProfileAnswer.name}\'
    WHERE (#{@program_cond} profile_questions.id = #{question_id}) AND 
          ((profile_questions.question_type = #{ProfileQuestion::Type::FILE} AND attachment_updated_at IS NOT NULL) OR 
           (profile_questions.question_type NOT IN (#{([ProfileQuestion::Type::FILE] + ProfileQuestion::Type.choice_based_types).join(',')}) AND answer_text != \'\') OR
            (profile_questions.question_type IN (#{ProfileQuestion::Type.choice_based_types.join(',')}) AND answer_choices.ref_obj_id IS NOT NULL AND answer_choices.ref_obj_type = \'#{ProfileAnswer.name}\'))"
  end

  def self.users_or_members_who_answered_with_query(ans_cond, mem, question_id)
    "#{@select_cond}
     #{profile_question_answer_join_query(mem)}
     #{@answer_choices_join}
     #{@locations_join}
     #{@date_answers_join}
     WHERE (#{@program_cond} (#{ans_cond}) AND
     profile_questions.id = #{question_id})"
  end

  def self.get_grouped_profile_field_filters(profile_field_filters)
    profile_field_filters.group_by{|profile_field| profile_field["field"]}
  end

  def self.date_profile_filter_from_admin_view?(filter)
    filter["operator"] == SurveyResponsesDataService::Operators::CONTAINS
  end
end