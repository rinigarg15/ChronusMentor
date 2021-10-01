class MeetingOutcomesReport < OutcomesReportCommon

  include OutcomesReportUtils

  module Type
    CLOSED = "closed"
    POSITIVE_OUTCOMES = "positive_outcomes"
  end

  module FlashSectionElementId
    PREFIX = "flash_"

    def self.for_role(role)
      "#{PREFIX}#{role.name}"
    end
  end

  def initialize(program, options={})
    return if options[:skip_init]
    cache_key = options[:cache_key]
    common_initialization(program, options[:date_range], options[:enabled_status])
    @memberIds = cache_key.present? ? Rails.cache.read(cache_key+"_members") : nil
    for_positive_outcomes = (options[:type] == Type::POSITIVE_OUTCOMES)

    if(for_positive_outcomes)
      member_meeting_ids = @program.surveys.of_meeting_feedback_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: [:member_meeting, :answer_choices]]).where("common_answers.member_meeting_id is not NULL and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0").pluck("DISTINCT member_meetings.id")
      total_closed_meetings = remove_invalid_meetings(get_total_completed_meeting_data_between_for_positive_outcome(self.startDate, self.endDate), true, member_meeting_ids)
      old_total_closed_meetings = remove_invalid_meetings(get_total_completed_meeting_data_between_for_positive_outcome(self.oldStartTime, self.oldEndTime), true, member_meeting_ids) if self.getOldData
      closed_meetings = remove_invalid_meetings(get_total_completed_meeting_data_between(self.startDate, self.endDate))
      closed_meetings_user_ids = @program.users.where(member_id: closed_meetings.collect{|m| m["member_id"]}.uniq).pluck(:id)
      self.responseRate, self.marginError = get_positive_outcomes_survey_response_rate_and_error_rate(closed_meetings_user_ids)
    else
      total_closed_meetings = remove_invalid_meetings(get_total_completed_meeting_data_between(self.startDate, self.endDate))
      old_total_closed_meetings = remove_invalid_meetings(get_total_completed_meeting_data_between(self.oldStartTime, self.oldEndTime)) if self.getOldData
    end

    self.totalCount = get_meetings_count(total_closed_meetings)
    self.overallChange = get_diff_in_percentage(get_meetings_count(old_total_closed_meetings), self.totalCount) if self.getOldData

    self.userSummary = compute_user_summary_for_completed_meetings(total_closed_meetings, old_total_closed_meetings)
    self.rolewiseSummary = compute_rolewise_summary_for_completed_meetings(total_closed_meetings, old_total_closed_meetings, for_positive_outcomes)
    self.graphData = compute_graph_data_for_completed_meeting(total_closed_meetings)
  end

  def get_satisfaction_stats_for_meetings_between(start_date, end_date, options = {})
    surveys = Survey.where(program_id: options[:program_ids])
    meeting_ids = Meeting.in_programs(options[:program_ids]).non_group_meetings.between_time([start_date, end_date]).pluck(:id)
    positive_member_meeting_ids = survey_responses_scoped_to_meetings(get_total_positive_outcome_data_between(surveys), meeting_ids)
    survey_ids_with_positive_outcome = surveys.of_meeting_feedback_type.joins(:survey_questions_with_matrix_rating_questions).where("common_questions.positive_outcome_options IS NOT NULL").pluck(:id)
    total_member_meeting_ids = survey_responses_scoped_to_meetings(SurveyAnswer.joins(member_meeting: [:member, :meeting]).where(survey_id: survey_ids_with_positive_outcome), meeting_ids)
    positive_and_total_satisfaction_hash(positive_member_meeting_ids, total_member_meeting_ids)
  end

  private

  def survey_responses_scoped_to_meetings(query, meeting_ids)
    query.where("meetings.id in (?)", meeting_ids).pluck("distinct member_meetings.id")
  end

  def get_positive_outcomes_survey_response_rate_and_error_rate(closed_meetings_user_ids)
    closed_meetings_users_count = closed_meetings_user_ids.size
    positive_outcome_survey_ids = SurveyQuestion.where(survey_id: @program.surveys.of_meeting_feedback_type.pluck(:id)).positive_outcome_configured.pluck(:survey_id).uniq
    responded_user_ids_count = SurveyAnswer.where(survey_id: positive_outcome_survey_ids, user_id: closed_meetings_user_ids).pluck(:user_id).uniq.count

    response_rate = Survey.calculate_response_rate(responded_user_ids_count, closed_meetings_users_count) || 0
    error_rate = Survey.percentage_error(responded_user_ids_count, closed_meetings_users_count) || 0
    return [response_rate, error_rate]
  end

  def get_total_completed_meeting_data_between(start_date, end_date)
    end_time = get_end_time(end_date)
    query = @program.meetings.with_starttime_in(start_date.utc.beginning_of_day, end_time)
    unless @memberIds.nil?
      meeting_ids = MemberMeeting.where(member_id: @memberIds).pluck(:meeting_id)
      query = query.where("meetings.id IN (?)", meeting_ids)
    end
    get_meetings_data_hash_for_stats(query)
  end

  def get_total_completed_meeting_data_between_for_positive_outcome(start_date, end_date)
    end_time = get_end_time(end_date)
    meeting_ids = get_total_positive_outcome_data_between(@program.surveys).pluck("meetings.id").uniq
    query = @program.meetings.with_starttime_in(start_date.utc.beginning_of_day, end_time)
    unless @memberIds.nil?
      meeting_ids = meeting_ids & MemberMeeting.where(member_id: @memberIds).pluck(:meeting_id)
    end
    query = query.where("meetings.id IN (?)", meeting_ids)
    get_meetings_data_hash_for_stats(query)
  end

  def get_total_positive_outcome_data_between(surveys)
    surveys.of_meeting_feedback_type.joins(:survey_questions_with_matrix_rating_questions => [survey_answers: [:answer_choices, {member_meeting: :meeting}]]).where("common_answers.member_meeting_id is not NULL and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options) > 0")
  end

  def compute_user_summary_for_completed_meetings(total_closed_meetings, old_total_closed_meetings)
    total_memberships_count = total_closed_meetings.collect{|g| g["member_id"]}.uniq.count
    old_total_memberships_count = (self.getOldData ? old_total_closed_meetings.collect{|g| g["member_id"]}.uniq.count : 0)
    total_change = get_diff_in_percentage(old_total_memberships_count, total_memberships_count)
    userSummary = {name: "feature.outcomes_report.title.users".translate, count: total_memberships_count, change: total_change}
  end

  def compute_rolewise_summary_for_completed_meetings(total_closed_meetings, old_total_closed_meetings, for_positive_outcomes=false)
    rolewiseSummary = []

    @mentoring_roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).each do |role|
      operator = (role.name==RoleConstants::STUDENT_NAME) ? "==" : "!="
      total_role_memberships = total_closed_meetings.select{|g| g["member_id"].method(operator).(g["meeting_owner_id"])}
      old_total_role_memberships = (self.getOldData ? old_total_closed_meetings.select{|g| g["member_id"].method(operator).(g["meeting_owner_id"])} : nil)
      count = total_role_memberships.present? ? total_role_memberships.collect{|g| g["member_id"]}.uniq.count : 0
      old_count = old_total_role_memberships.present? ? old_total_role_memberships.collect{|g| g["member_id"]}.uniq.count : 0
      change = get_diff_in_percentage(old_count, count)
      id = for_positive_outcomes ? ConnectionOutcomesReport::PositiveOutcomesSectionElementId.for_role(role) : FlashSectionElementId.for_role(role)
      rolewiseSummary << {id: id, name: role.customized_term.pluralized_term, count: count, change: change}
    end
    return rolewiseSummary
  end

  def compute_graph_data_for_completed_meeting(total_closed_meetings)
    graph_data = {}
    total_closed_meetings.each do |total_closed_meeting|
      keyy = total_closed_meeting["meeting_start_time"].utc.at_beginning_of_month.to_i*1000
      graph_data[keyy].present? ? (graph_data[keyy] << total_closed_meeting) : (graph_data.merge!({keyy => [total_closed_meeting]}))
    end
    total_data = []
    total_user_data = []
    role_graph_data_mapping = {}
    @mentoring_roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).each do |role|
      role_graph_data_mapping.merge!({ role.id => []})
    end

    start_month_index = (self.startDate.utc.at_beginning_of_month.to_i)*1000
    end_month_index = (self.endDate.utc.at_beginning_of_month.to_i)*1000
    month_index = start_month_index
    next_month = self.startDate.at_beginning_of_month

    while (month_index <= end_month_index)
      months_data = graph_data[month_index]
      total_data << ((months_data.nil?) ? [month_index, 0] : [month_index, months_data.collect{|g| g["meeting_id"]}.uniq.count])
      total_user_data << ((months_data.nil?) ? [month_index, 0] : [month_index, months_data.collect{|g| g["member_id"]}.uniq.count])
      @mentoring_roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).each do |role|
        operator = (role.name==RoleConstants::STUDENT_NAME) ? "==" : "!="
        role_data = months_data.select{|g| g["member_id"].method(operator).(g["meeting_owner_id"])} if months_data.present?
        role_data = ((role_data.present?) ? [month_index, role_data.collect{|g| g["member_id"]}.uniq.count] : [month_index, 0])
        role_graph_data_mapping[role.id] += [role_data]
      end
      next_month += 1.month
      month_index = (next_month.at_beginning_of_month.to_i)*1000
    end

    graph_data = [{name: "feature.outcomes_report.title.users".translate, data: total_user_data, color: GraphColor::USERS, visibility: self.enabledStatusMapping[:users]}]
    @mentoring_roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).each do |role|
      graph_data << {name: "#{role.customized_term.pluralized_term}", data: role_graph_data_mapping[role.id], color: self.roleGraphColorMapping[role.id], visibility: self.enabledStatusMapping[role.id]}
    end
    graph_data << {name: "#{@program.term_for(CustomizedTerm::TermType::MEETING_TERM).pluralized_term}", data: total_data, color: GraphColor::CONNECTIONS, visibility: self.enabledStatusMapping[:total_connections_or_meetings]}
    return graph_data
  end

  def get_end_time(end_date)
    (end_date.utc.end_of_day > Time.now) ? Time.now : end_date.utc.end_of_day
  end

  def positive_and_total_satisfaction_hash(positive_member_meeting_ids, total_member_meeting_ids)
    {
      positive: MemberMeeting.users(positive_member_meeting_ids).size,
      total: MemberMeeting.users(total_member_meeting_ids).size
    }
  end
end