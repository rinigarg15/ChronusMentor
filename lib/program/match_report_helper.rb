module Program::MatchReportHelper
  
  def set_current_status_graph_data(start_date, end_date, program)
    mentee_role = self.roles.find_by(name: RoleConstants::STUDENT_NAME)
    total_active_mentee_ids = program.student_users.active.pluck(:id)
    query_params = [self, start_date, end_date, ids: total_active_mentee_ids, role: mentee_role]
    return self.get_graph_data_for_program(total_active_mentee_ids, query_params)
  end

  def get_graph_data_for_program(total_active_mentee_ids, query_params)
    if self.only_career_based_ongoing_mentoring_enabled? && (self.matching_by_mentee_alone? || self.matching_by_mentee_and_admin_with_preference?)
      return get_data_for_ongoing_self_match_and_preferred_mentoring(total_active_mentee_ids, query_params)
    elsif self.is_ongoing_carrer_based_matching_by_admin_alone?
      return get_data_for_ongoing_admin_match(total_active_mentee_ids, query_params)
    elsif self.calendar_enabled?
      return get_data_for_flash_only_program(total_active_mentee_ids)
    end
  end

  private

  def get_data_for_ongoing_self_match_and_preferred_mentoring(total_active_mentee_ids, query_params)
    sent_request_mentee_ids = (self.mentor_requests.pluck(:sender_id) & total_active_mentee_ids).uniq
    accepted_requests_mentee_ids = (self.mentor_requests.accepted.pluck(:sender_id) & sent_request_mentee_ids).uniq
    return get_data_values_for_self_match_and_preferred_mentoring(sent_request_mentee_ids, total_active_mentee_ids, accepted_requests_mentee_ids, query_params)
  end

  def get_data_values_for_self_match_and_preferred_mentoring(sent_request_mentee_ids, total_active_mentee_ids, accepted_requests_mentee_ids, query_params)
    data = Hash.new
    data[:first] = rounded_percentage(sent_request_mentee_ids.count, total_active_mentee_ids.count)
    data[:second] = rounded_percentage(accepted_requests_mentee_ids.count, sent_request_mentee_ids.count)
    data[:third] = rounded_percentage((User.get_ids_of_connected_users_active_between(*query_params) & total_active_mentee_ids).uniq.count, total_active_mentee_ids.count)
    return data
  end

  def get_data_for_ongoing_admin_match(total_active_mentee_ids, query_params)
    mentees_count_in_published_groups = (User.get_ids_of_connected_users_active_between(*query_params) & total_active_mentee_ids).uniq.count
    mentees_count_in_drafted_groups = (Connection::Membership.user_ids_in_groups(self.groups.drafted.pluck(:id), self, RoleConstants::STUDENT_NAME) & total_active_mentee_ids).uniq.count
    return get_data_values_for_ongoing_admin_match(mentees_count_in_published_groups, total_active_mentee_ids, mentees_count_in_drafted_groups)
  end

  def get_data_values_for_ongoing_admin_match(mentees_count_in_published_groups, total_active_mentee_ids, mentees_count_in_drafted_groups)
    data = Hash.new
    data[:first] = rounded_percentage(mentees_count_in_published_groups, total_active_mentee_ids.count)
    data[:second] = rounded_percentage(mentees_count_in_drafted_groups, total_active_mentee_ids.count)
    data[:third] = rounded_percentage((total_active_mentee_ids.count - mentees_count_in_published_groups), total_active_mentee_ids.count)
    return data
  end

  def get_data_for_flash_only_program(total_active_mentee_ids)
    sent_request_mentee_ids = (self.meeting_requests.pluck(:sender_id) & total_active_mentee_ids).uniq
    accepted_requests_mentee_ids = (self.meeting_requests.accepted.pluck(:sender_id) & sent_request_mentee_ids).uniq
    active_mentee_member_ids = User.where(id: total_active_mentee_ids).pluck(:member_id)
    accepted_meeting_mentee_ids = ((self.meetings.accepted_meetings.pluck(:mentee_id) + User.where(id: accepted_requests_mentee_ids).pluck(:member_id)) & active_mentee_member_ids).uniq
    
    return get_data_values_for_flash_only_program(sent_request_mentee_ids, total_active_mentee_ids, accepted_requests_mentee_ids, accepted_meeting_mentee_ids, active_mentee_member_ids)
  end

  def get_data_values_for_flash_only_program(sent_request_mentee_ids, total_active_mentee_ids, accepted_requests_mentee_ids, accepted_meeting_mentee_ids, active_mentee_member_ids)
    data = Hash.new
    data[:first] = rounded_percentage(sent_request_mentee_ids.count, total_active_mentee_ids.count)
    data[:second] = rounded_percentage(accepted_requests_mentee_ids.count, sent_request_mentee_ids.count)
    data[:third] = rounded_percentage(accepted_meeting_mentee_ids.count , active_mentee_member_ids.count)
    return data
  end

  def rounded_percentage(numerator, denominator, round_to=0)
    if denominator.zero?
      numerator.zero? ? 0 : 100 
    else
      (numerator.to_f*100/denominator).round(round_to)
    end
  end
end