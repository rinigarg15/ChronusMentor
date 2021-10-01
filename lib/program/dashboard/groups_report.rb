module Program::Dashboard::GroupsReport
  extend ActiveSupport::Concern

  def get_groups_reports_to_display
    DashboardReportSubSection::Type::Groups.all.select{|report_type| self.is_report_enabled?(report_type)}
  end

  private

  def get_groups_survey_responses_data(date_range)
    {survey_responses_count: get_survey_responses_count(date_range), survey_responses: get_survey_responses(date_range)}
  end

  def get_groups_health_data(date_range)
    {groups_with_good_survey_responses_count: get_groups_with_good_survey_responses_count(date_range), groups_with_not_good_survey_responses_count: get_groups_with_not_good_survey_responses_count(date_range), groups_without_survey_responses_count: get_groups_without_survey_responses_count(date_range)}
  end

  def get_groups_with_good_survey_responses_count(date_range)
    get_group_survey_responses(date_range)
    @group_ids_with_good_survey_responses.count 
  end

  def get_groups_with_not_good_survey_responses_count(date_range)
    get_group_survey_responses(date_range)
    @group_ids_with_not_good_survey_responses.count
  end

  def get_groups_without_survey_responses_count(date_range)
    get_group_survey_responses(date_range)
    @groups_without_survey_responses_count
  end

  def get_survey_responses_count(date_range)
    get_group_survey_responses(date_range)
    @group_survey_responses.count
  end

  def get_survey_responses(date_range)
    get_group_survey_responses(date_range)
    @group_survey_responses.first(Group::GROUP_SURVEY_RESPONSE_COUNT)
  end

  def get_group_survey_responses(date_range)
    groups = self.groups
    group_ids = groups.pluck(:id)
    @group_survey_responses ||= groups.map{|group| group.unique_survey_answers(true, date_range)}.flatten

    group_ids_with_survey_responses = @group_survey_responses.collect(&:group_id).uniq
    @groups_without_survey_responses_count ||= (group_ids - group_ids_with_survey_responses).count
    @group_ids_with_good_survey_responses ||= self.surveys.of_engagement_type.joins(survey_questions_with_matrix_rating_questions: [survey_answers: :answer_choices]).where("common_answers.group_id IS NOT NULL AND FIND_IN_SET(answer_choices.question_choice_id, common_questions.positive_outcome_options_management_report) > 0 AND common_answers.last_answered_at >= ? AND common_answers.last_answered_at < ?", date_range.first, date_range.last).pluck("DISTINCT group_id")
    @group_ids_with_not_good_survey_responses ||= group_ids_with_survey_responses - @group_ids_with_good_survey_responses
  end 
end