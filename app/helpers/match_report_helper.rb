module MatchReportHelper

  def get_match_report_section_settings(section)
    case section
    when MatchReport::Sections::MentorDistribution
      render(partial: "match_reports/mentor_distribution/mentor_distribution_settings", locals: {section: section})
    when MatchReport::Sections::MenteeActions
      render(partial: "match_reports/mentee_actions/mentee_actions_settings", locals: {section: section})
    end
  end

  def get_kendo_options_for_filters(filters)
    options = {
      filterData: filters.collect{|profile_question, count| {questionText: profile_question.question_text, count: count}},
      fields: { questionText: { type: "string" }, count: { type: "number" } },
      columns: [{ field: "questionText", title: "common_text.Applied_Filters".translate, width: "80%" }, { field: "count", title: "feature.reports.label.count".translate, width: "20%", headerAttributes: { class: "text-center" }, attributes: { class: "text-center" } }],
      perPage: MatchReport::MenteeActions::FILTERS_POPUP_LISTING_LIMIT,
      scrollable: true,
      sortable: true,
      pageable: true
    }
    return options
  end

  def get_search_keywords_data(search_keywords)
    search_keywords.map{|search_keyword| {name: search_keyword[:keyword], value: search_keyword[:count]}}
  end

  def get_kendo_options_for_mentee_needs(match_config)
    options = {
      dataSource: get_discrepancy_table_data_match_reports_path(match_config_id: match_config.id, format: :json),
      fields: { questionText: { type: "string" }, menteeCount: { type: "number" }},
      column_names: { questionText: match_config.mentor_question.profile_question.question_text, menteeCount: "feature.match_report.label.no_of_users".translate(role: _mentees), mentorCount: "feature.match_report.label.no_of_users".translate(role: _mentors), discrepancy: "feature.match_report.label.mentor_gap".translate(Mentor: _Mentor)},
      perPage: MatchReport::MenteeActions::FILTERS_POPUP_LISTING_LIMIT,
      scrollable: true,
      sortable: true,
      pageable: true
    }
    return options
  end

  def get_current_status_subsections(program, data)
    headers = Hash.new
    if program.is_ongoing_carrer_based_matching_by_admin_alone?
      headers = get_current_status_headers("feature.match_report.content.match_rate".translate(Mentee: _Mentee), "feature.match_report.content.drafted".translate(mentees: _mentees), "feature.match_report.content.never_connected".translate(mentees: _mentees))
      tooltips = get_current_status_tooltips(true)
    else
      headers = get_current_status_headers("feature.match_report.content.sent_requests".translate(Mentees: _Mentees), "feature.match_report.content.accepted_requests".translate(Mentees: _Mentees), "feature.match_report.content.match_rate".translate(Mentee: _Mentee))
      tooltips = get_current_status_tooltips(false)
    end
    return [[headers[:first], tooltips[:first], 'current_status_total_data'], [headers[:second], tooltips[:second], 'current_status_success_data'], [headers[:third], tooltips[:third], 'current_status_result_data']]
  end

  def get_current_status_headers(first_header, second_header, third_header)
    headers = Hash.new
    headers[:first] = first_header
    headers[:second] = second_header
    headers[:third] = third_header
    return headers
  end

  def get_current_status_tooltips(is_admin_match_alone)
    tooltips = Hash.new
    if is_admin_match_alone
      tooltips[:first] = "feature.match_report.tooltips.admin_match.match_rate".translate(mentees: _mentees)
      tooltips[:second] = "feature.match_report.tooltips.admin_match.drafted".translate(mentees: _mentees)
      tooltips[:third] = "feature.match_report.tooltips.admin_match.never_connected".translate(mentees: _mentees)
    else
      tooltips[:first] = "feature.match_report.tooltips.non_admin_match.sent_request".translate(mentees: _mentees)
      tooltips[:second] = "feature.match_report.tooltips.non_admin_match.accepted_request".translate(mentees: _mentees)
      tooltips[:third] = "feature.match_report.tooltips.non_admin_match.match_rate".translate(mentees: _mentees)
    end
    return tooltips
  end
end