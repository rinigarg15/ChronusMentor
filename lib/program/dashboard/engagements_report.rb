module Program::Dashboard::EngagementsReport
  extend ActiveSupport::Concern

  GROUPS_ENGAGEMENT_TYPE = "_Mentoring_Connections"
  MEETINGS_ENGAGEMENT_TYPE = "_Meetings"

  def get_engagements_reports_to_display
    DashboardReportSubSection::Type::Engagements.all.select{|report_type| self.is_report_enabled?(report_type)}
  end

  def get_engagement_type
    self.only_one_time_mentoring_enabled? ? MEETINGS_ENGAGEMENT_TYPE : GROUPS_ENGAGEMENT_TYPE
  end

  def get_engagements_survey_responses_data(date_range, page_number=1)
    self.only_one_time_mentoring_enabled? ? get_meetings_survey_responses_data(date_range, page_number) : get_groups_survey_responses_data(date_range, page_number)
  end

  def get_engagements_health_data(date_range)
    self.only_one_time_mentoring_enabled? ? get_meetings_health_data(date_range) : get_groups_health_data(date_range)
  end

  private

  def get_groups_survey_responses_data(date_range, page_number=1)
    {survey_responses_count: get_groups_survey_responses_count(date_range), survey_responses: get_groups_survey_responses_to_show(date_range, page_number)}
  end

  def get_meetings_survey_responses_data(date_range, page_number=1)
    {survey_responses_count: get_meetings_survey_responses_count(date_range), survey_responses: get_meetings_survey_responses_to_show(date_range, page_number)}
  end

  # Ongoing

  def get_groups_survey_responses_count(date_range)
    get_groups_survey_responses(date_range).count
  end

  def get_groups_survey_responses_to_show(date_range, page_number=1)
    get_groups_survey_responses(date_range).paginate(page: page_number, per_page: Group::GROUP_SURVEY_RESPONSE_COUNT)
  end

  def get_groups_survey_responses(date_range)
    columns_for_select = "common_answers.common_question_id, common_answers.user_id, common_answers.group_id, common_answers.response_id, common_answers.last_answered_at"
    tables_to_include = [survey_question: [{survey: :translations}], user: [{ member: :profile_picture}]]
    survey_answers_in_date_range = SurveyAnswer.where(group_id: self.groups.published.select(:id)).last_answered_in_date_range(date_range)
    survey_answers_in_date_range.select(columns_for_select).order("last_answered_at DESC").includes(tables_to_include).to_a.uniq{|ans| [ans.user_id, ans.group_id, ans.response_id]}
  end

  # Flash

  def get_meetings_survey_responses_count(date_range)
    get_meetings_survey_responses(date_range).count
  end

  def get_meetings_survey_responses_to_show(date_range, page_number=1)
    get_meetings_survey_responses(date_range).paginate(page: page_number, per_page: Group::GROUP_SURVEY_RESPONSE_COUNT)
  end

  def get_meetings_survey_responses(date_range)
    columns_for_select = "common_answers.common_question_id, common_answers.user_id, common_answers.member_meeting_id, common_answers.response_id, common_answers.last_answered_at"
    tables_to_include = [survey_question: [{survey: :translations }], user: [{ member: :profile_picture}]]
    member_meeting_ids = MemberMeeting.where(meeting_id: self.get_attended_meeting_ids).select(:id)
    survey_answers_in_date_range = SurveyAnswer.where(member_meeting_id: member_meeting_ids).last_answered_in_date_range(date_range)
    survey_answers_in_date_range.select(columns_for_select).order("last_answered_at DESC").includes(tables_to_include).to_a.uniq{|ans| [ans.user_id, ans.member_meeting_id, ans.response_id]}
  end

  #################################################Health Data###############################################################

  def get_groups_health_data(date_range)
    {engagements_with_good_survey_responses_count: get_group_data_for_positive_outcome_between(date_range).size, engagements_with_not_good_survey_responses_count: get_group_data_for_neutral_outcome_between(date_range).size, engagements_without_survey_responses_count: groups_with_overdue_survey_responses_and_active_within(date_range).size}
  end

  def get_meetings_health_data(date_range)
    {engagements_with_good_survey_responses_count: get_meeting_data_for_positive_outcome_completed_between(date_range).count, engagements_with_not_good_survey_responses_count: get_meeting_data_for_neutral_outcome_completed_between(date_range).count, engagements_without_survey_responses_count: meetings_with_no_survey_responses_and_completed_between(date_range).count}
  end

  # Ongoing

  def get_group_data_for_positive_outcome_between(date_range)
    self.surveys.of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options_management_report) > 0 AND common_answers.last_answered_at >= ? AND common_answers.last_answered_at < ?", date_range.first, date_range.last).pluck(:group_id).uniq
  end

  def get_group_data_for_neutral_outcome_between(date_range)
    positive_group_ids = get_group_data_for_positive_outcome_between(date_range)
    SurveyAnswer.where(survey_id: dashboard_positive_outcome_survey_ids).where.not(group_id: positive_group_ids).where("common_answers.last_answered_at >= ? AND common_answers.last_answered_at <= ?", date_range.begin, date_range.end).pluck(:group_id).uniq
  end

  def groups_with_overdue_survey_responses_and_active_within(date_range)
    valid_group_ids = groups.where.not(id: group_ids_with_survey_responses(date_range)).active_between(date_range.begin, date_range.end).select(:id)
    # Passing valid_group_ids in IN clause. It will be performant for now. Needed fix if the count goes beyond 10x.
    tasks_due_for_surveys_of_active_groups = MentoringModel::Task.due_date_in(date_range.begin, date_range.end).for_the_survey_id(dashboard_positive_outcome_survey_ids).of_groups_with_ids(valid_group_ids.pluck(:id)).select(:id, :group_id)
    tasks_not_answered_in_time = tasks_due_for_surveys_of_active_groups.joins("LEFT JOIN common_answers ON mentoring_model_tasks.id = common_answers.task_id").where("common_answers.last_answered_at IS NULL OR common_answers.last_answered_at > ? OR common_answers.is_draft = ?", date_range.end, true)
    tasks_not_answered_in_time.select("mentoring_model_tasks.group_id").collect(&:group_id).uniq
  end

  def group_ids_with_survey_responses(date_range)
    SurveyAnswer.where(survey_id: dashboard_positive_outcome_survey_ids).where("common_answers.last_answered_at >= ? AND common_answers.last_answered_at <= ?", date_range.begin, date_range.end).select(:group_id).uniq
  end

  # Flash

  def get_meeting_data_for_positive_outcome_completed_between(date_range)
    meeting_ids = self.surveys.of_meeting_feedback_type.joins(:survey_questions_with_matrix_rating_questions => [:survey_answers => [:answer_choices, {:member_meeting => :meeting}]]).where("common_answers.member_meeting_id is not NULL and FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options_management_report) > 0").pluck("meetings.id").uniq
    Meeting.where(id: meeting_ids).completed.with_endtime_in(date_range.begin, date_range.end).select(:id)
  end

  def get_meeting_data_for_neutral_outcome_completed_between(date_range)
    positive_meeting_ids = get_meeting_data_for_positive_outcome_completed_between(date_range)
    meetings_which_answered_surveys = SurveyAnswer.where(survey_id: dashboard_positive_outcome_survey_ids).joins(:member_meeting).select("member_meetings.meeting_id")
    Meeting.where(id: meetings_which_answered_surveys).where.not(id: positive_meeting_ids).completed.with_endtime_in(date_range.begin, date_range.end).select(:id)
  end

  def meetings_with_no_survey_responses_and_completed_between(date_range)
    if dashboard_positive_outcome_survey_ids.any?
      meetings_which_answered_surveys = SurveyAnswer.where(survey_id: dashboard_positive_outcome_survey_ids).joins(:member_meeting).select("member_meetings.meeting_id")
      Meeting.where(id: self.get_attended_meeting_ids).where.not(id: meetings_which_answered_surveys).completed.with_endtime_in(date_range.begin, date_range.end).select(:id)
    else
      return []
    end
  end

  def dashboard_positive_outcome_survey_ids
    if self.only_one_time_mentoring_enabled?
      self.surveys.of_meeting_feedback_type.joins(:survey_questions_with_matrix_rating_questions).where("common_questions.positive_outcome_options_management_report IS NOT NULL").pluck(:id)
    else
      self.surveys.of_engagement_type.joins(:survey_questions_with_matrix_rating_questions).where("common_questions.positive_outcome_options_management_report IS NOT NULL").pluck(:id)
    end
  end
end