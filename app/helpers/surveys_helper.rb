module SurveysHelper
  # Displays appropriate message
  #
  # Params: <tt>survey</tt> : the survey for which to show the status
  # <tt>active_tab</tt> : which tab in survey page are we in.
  #                       One of :summary, :questions and :reponses
  # <tt>response_count</tt> : number of responses to the survey
  #
  def survey_status_message(survey, active_tab, response_count)
    if survey.program_survey? && survey.overdue?
      # Survey has past due date. Give link to reponses page, unless already there
      if active_tab != :responses
        content_tag(:p, :id => 'survey_overdue_notice') do
          content = get_safe_string + "feature.survey.content.status.expired".translate

          if response_count == 0
            content << "feature.survey.content.status.no_response_expired".translate
          else
            response_link = link_to(
              "feature.survey.content.survey_response".translate(count: response_count), report_survey_path(survey))
            content << "feature.survey.content.status.n_response_expired_html".translate(n_responses: response_link)
          end
          content
        end
      end
    elsif survey.survey_questions.empty?
      # No questions yet. Ask user to add some questions, unless he is already
      # in questions page
      if active_tab != :questions
        content_tag(:p, {:id => 'no_survey_questions_notice'}) do
          "feature.survey.content.status.no_questions_active_html".translate(add_questions: link_to("feature.survey.content.add_questions".translate, survey_survey_questions_path(survey)))
        end
      end
    elsif response_count == 0
      if survey.program_survey?
        # If There were no responses yet, guide user by prompting him to create
        # and announcement for telling about the survey
        content_tag(:p, {:id => 'survey_announcement_notice'}) do
          "feature.survey.content.status.no_response_active_html".translate(creating_an_announcement: link_to("feature.survey.action.creating_an_announcement".translate, new_announcement_path(:survey_id => survey.id), :id => 'announce_link'),
                                                                            survey_link: link_to("feature.survey.content.survey_link".translate, edit_answers_survey_path(survey), :target => :_blank))
        end
      elsif survey.engagement_survey? && survey.program.mentoring_connections_v2_enabled?
        # If there were no responses yet, prompt him to add this survey to engement survey
        content_tag(:p) do
          "feature.survey.content.status.no_response_active_engagement_survey_html".translate(create_survey_type_task: link_to("feature.survey.action.create_survey_type_task".translate, add_to_engagement_plan_link(survey)), mentoring_connection: _mentoring_connection)
        end
      end
    end
  end

  def add_to_engagement_plan_link(survey)
    program = survey.program
    (program.mentoring_models.size > 1) ? mentoring_models_path : mentoring_model_path(program.mentoring_models.first, action_item_id: survey.id)
  end

  def render_survey_header_bar(survey)
    program = survey.program

    actions = []
    content = get_safe_string

    if survey.engagement_survey? && program.mentoring_connections_v2_enabled?
      actions << {
        label: append_text_to_icon("fa fa-plus", "feature.survey.action.Add_to_engagement_plan_v1".translate(Mentoring_Connection: _Mentoring_Connection)),
        url: add_to_engagement_plan_link(survey),
        class: "action action_2"
      }
    end
    actions << {
      label: append_text_to_icon("fa fa-pencil", "display_string.Edit".translate),
      url: 'javascript:void(0);',
      class: "action action_2 cui_edit_survey",
      data: { toggle: "modal", target: "#modal_edit_survey_#{survey.id}" }
    }

    unless survey.meeting_feedback_survey?
      # Connection Feedback Survey is an engagement-type survey and its accessible in V2 disabled programs also.
      # So, blocking the cloning of engagement-type surveys in V2 disabled programs.
      if !survey.engagement_survey? || program.mentoring_connections_v2_enabled?
        actions << {
          label: append_text_to_icon("fa fa-copy", "display_string.Make_a_copy".translate),
          url: 'javascript:void(0);',
          class: "action",
          data: { toggle: "modal", target: "#modal_clone_survey_name_popup_form" }
        }
        content << render(partial: 'surveys/name_clone', locals: { survey: survey } )
      end
      actions << {
        label: append_text_to_icon("fa fa-download", "feature.survey.action.export_question".translate),
        url: export_questions_survey_path(survey),
        data: { type: survey.type },
        class: "action action_2 export_survey_questions"
      }
    end

    deletion_action, deletion_content = get_survey_deletion_action(survey)
    actions << deletion_action if deletion_action.present?
    content << deletion_content if deletion_content.present?
    return actions, content
  end

  def get_survey_deletion_action(survey)
    program = survey.program
    if survey.engagement_survey?
      closed_group_ids = program.groups.closed.pluck(:id)
      associated_tasks_in_closed_groups = MentoringModel::Task.where(group_id: closed_group_ids, action_item_id: survey.id, action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY)
    end

    action = {}
    content = get_safe_string

    unless survey.meeting_feedback_survey?
      if survey.engagement_survey? && survey.has_associated_tasks_in_active_groups_or_templates?
        action = {
          label: append_text_to_icon("fa fa-trash", "display_string.Delete".translate),
          url: destroy_prompt_survey_path(survey, format: :js),
          class: "action action_2 cui_delete_survey survey-#{survey.id}-delete",
          remote: true,
          data: { toggle: "modal", target: "#modal_survey-#{survey.id}-destroy" }
        }
        content = render(partial: 'surveys/destroy_popup', locals: { survey_id: survey.id } )
      else
        action = {
          label: append_text_to_icon("fa fa-trash", "display_string.Delete".translate),
          url: survey_path(survey),
          class: "action action_2 cui_delete_survey survey-#{survey.id}-delete",
          method: :delete,
          data: { confirm: survey_deletion_warning(survey.name, associated_tasks_in_closed_groups: associated_tasks_in_closed_groups.present?, tied_to_health_report: survey.tied_to_health_report?, tied_to_outcomes_report: survey.tied_to_outcomes_report?) }
        }
      end
    end
    return [action, content]
  end

  def render_user_survey_matrix_answer(matrix_question, survey_answers, options = {})
     rating_questions = matrix_question.rating_questions
     content = "".html_safe
      content += profile_field_container(get_question_text(matrix_question, options), nil)

     rating_questions.each do |question|
      answer = survey_answers[question.id].try(:first)

      content +=survey_matrix_rating_question_container( question.question_text, (answer.present?  ? formatted_common_answer(answer, question) : content_tag(:span, "common_text.Not_Specified".translate, :class => "text-muted")),:class => "col-md-2 p-l-0 m-b-xs",:answer_class => "text-muted m-b-xs") + content_tag(:hr,nil,:class => "m-t-0 m-b-xs p-t-0 p-b-0")
     end
     return content
  end

  def survey_matrix_rating_question_container(definition_term, definition_data, options = {})
    content_tag(:strong, definition_term, :class => options[:class], :id => options[:heading_id]) + content_tag(:div, definition_data, :class => options[:answer_class])
  end

  def render_user_survey_answer_for_groups_listing_page(question, survey_answers)
    if question.matrix_question_type?
      rating_questions = question.rating_questions
      content = "".html_safe
      rating_questions.each do |question|
        answer = survey_answers[question.id]
        content += content_tag(:div, "#{question.question_text} - #{formatted_common_answer(answer, question)}".html_safe)
      end
      return content
    elsif question.choice_or_select_type?
      survey_answers[question.id].try(:selected_choices_to_str_for_view, question) || "-"
    else
      chronus_auto_link(survey_answers[question.id].try(:answer_text)) || "-"
    end
  end

  def render_user_survey_answer(question, answer, options = {})
    content = "".html_safe
    content += profile_field_container(get_question_text(question, options), (answer.present? ? formatted_common_answer(answer, question) : content_tag(:span, "common_text.Not_Specified".translate, :class => "text-muted")))
  end

  def get_question_text(question, options = {})
    return question.question_text if options[:pdf_view].present?
    get_icon_content("fa fa-comments-o") + question.question_text
  end

  def get_survey_info(group, meeting)
    if meeting.present?
      "feature.survey.content.survey_for_meeting_v1".translate(meeting_term: _Meeting, meeting_name: meeting.topic)
    elsif group.present?
      "feature.survey.content.survey_for_group_v1_html".translate(connection_term: _Mentoring_Connection, group_url: link_to(group.name, group_path(group)))
    end
  end

  def render_background_color(percentage)
    percentage = percentage.ceil
    color_hash = { 0 => "color-0",
    1..10 => "color-1-10",
    11..20 => "color-11-20",
    21..30 => "color-21-30",
    31..40 => "color-31-40",
    41..50 => "color-41-50",
    51..60 => "color-51-60",
    61..70 => "color-61-70",
    71..80 => "color-71-80",
    81..90 => "color-81-90",
    91..100 => "color-91-100"} 

   return color_hash.select {|color| color === percentage }.values.first
  end

  def render_class_for_matrix_rating_question(question)
    question.matrix_question_type? ? "matrix_report_table":nil
  end

  def render_choice_answers_count(percent,total_count)
    ((percent*total_count)/100).round 
  end

  def populate_survey_response_column_options(survey, optgroup)
    options_array = []
    selected_columns = get_selected_columns(survey, optgroup)
    selected_column_keys = get_selected_column_keys(selected_columns, optgroup)

    selected_columns.each do |column|
      options_array << [title_for_column(survey, column, optgroup), survey_response_edit_column_mapper(get_column_key(column, optgroup), optgroup)]
    end

    (get_all_columns(survey, optgroup)-selected_columns).each do |column|
      options_array << [title_for_column(survey, column, optgroup), survey_response_edit_column_mapper(get_column_key(column, optgroup), optgroup)]
    end

    options_for_select(options_array, selected_column_keys.map{|key| survey_response_edit_column_mapper(key, optgroup)})
  end

  def set_survey_role_check_box_tag_value(survey,role_name)
    (survey.present? && survey[:recipient_role_names].present? && survey[:recipient_role_names].include?(role_name)) ? true : false
  end

  def get_selected_columns(survey, optgroup)
    case optgroup
    when SurveysController::SurveyResponseColumnGroup::DEFAULT
      survey.survey_response_columns.of_default_columns.collect(&:key)
    when SurveysController::SurveyResponseColumnGroup::SURVEY
      survey.survey_response_columns.of_survey_questions.collect(&:survey_question)
    when SurveysController::SurveyResponseColumnGroup::PROFILE
      survey.profile_questions_to_display
    end
  end

  def get_all_columns(survey, optgroup)
    case optgroup
    when SurveysController::SurveyResponseColumnGroup::DEFAULT
      survey.get_default_survey_response_column_keys
    when SurveysController::SurveyResponseColumnGroup::SURVEY
      survey.survey_questions
    when SurveysController::SurveyResponseColumnGroup::PROFILE
      profile_questions = survey.program.profile_questions_for(survey.program.roles_without_admin_role.pluck(:name), {default: false, skype: false, fetch_all: true})
    end
  end

  def get_selected_column_keys(selected_columns, optgroup)
    optgroup == SurveysController::SurveyResponseColumnGroup::DEFAULT ? selected_columns : selected_columns.collect(&:id).map{|id| id.to_i}
  end

  def get_column_key(column, optgroup)
    optgroup == SurveysController::SurveyResponseColumnGroup::DEFAULT ? column : column.id
  end

  def title_for_column(survey, column, optgroup)
    optgroup == SurveysController::SurveyResponseColumnGroup::DEFAULT ? SurveyResponseColumn.get_default_title(column, survey) : column.question_text
  end

  def survey_response_edit_column_mapper(key, optgroup)
    [optgroup, key].join(SurveysController::SURVEY_RESPONSE_COLUMN_SPLITTER)
  end

  def link_to_responses_in_last_week(survey)
    one_week_ago = Time.zone.now.beginning_of_day-1.week
    responses_in_last_week = survey.survey_answers.group(:response_id).maximum(:last_answered_at).select{|response_id, response_time| response_time > one_week_ago}.size
    ("(" + link_to("feature.survey.survey_table.responses_in_last_week".translate(:count => responses_in_last_week), survey_responses_path(survey, :last_week_response => true), {:class => "light_green_link"}) + ")").html_safe if responses_in_last_week > 0
  end

  def get_select2_options(survey, choices, report_param)
    content = content_tag(:div, id: "filter_survey_report_by_role_container") do
      controls do
        label_tag("role_choice", "feature.survey.survey_report.filters.label.select_role_label".translate, for: "role_choice", class: "sr-only") +
        hidden_field_tag("roles_filter", "", class: "col-xs-12 no-padding", :id => "role_choice", data: {placeholder: "feature.connection.header.survey_response_filter.placeholder.select_choices".translate})
      end
    end

    choices_ids_string = choices.map{|c| c[:id]}.join(CommonQuestion::SEPERATOR)
    choices_texts_string = choices.map{|c| c[:text]}.join(CommonQuestion::SEPERATOR)
    content += javascript_tag(%Q[ReportFilters.displaySelect2Choices('#{j(choices_ids_string)}', '#{j(choices_texts_string)}', '#{CommonQuestion::SEPERATOR}', 'role_choice')])

    return content
  end

  def get_role_select2_choices(roles, program)
    roles.map{|role| {:id => role.name, :text => program.term_for(CustomizedTerm::TermType::ROLE_TERM, role.name).term}}
  end

  def get_question_choices_for_select2(questions, options = {})
    choices_id_hash = {}
    choices_text_hash = {}
    questions.each do |question|
      next unless question.choice_or_select_type?
      key = if options[:id_as_key]
              question.id.to_s
            else
              question.is_a?(SurveyQuestion) ? "answers#{question.id}" : "column#{question.id}"
            end

      choices = question.values_and_choices.map{|qc_id, current_locale_text| {:id => qc_id, :text => current_locale_text} }
      choices_ids_string = choices.map{|c| c[:id]}.join(CommonQuestion::SELECT2_SEPARATOR)
      choices_texts_string = choices.map{|c| c[:text]}.join(CommonQuestion::SELECT2_SEPARATOR)
      choices_id_hash[key] = choices_ids_string
      choices_text_hash[key] = choices_texts_string
    end
    return choices_id_hash, choices_text_hash
  end

  def survey_received_responses_text(survey, response_rate_hash)
    survey.engagement_survey? ? "feature.survey.responses.fields.users_connections_responses_html".translate(users: response_rate_hash[:users_responded], connections: response_rate_hash[:users_responded_groups_or_meetings_count], :mentoring_connections => _mentoring_connections, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS,'', :id => "users_connections_responses_received_text")) : "feature.survey.responses.fields.members_meetings_responses_html".translate(users_count: response_rate_hash[:users_responded], meetings_count: response_rate_hash[:users_responded_groups_or_meetings_count], :_meetings => _meetings)
  end

  def survey_overdue_responses_text(survey, response_rate_hash)
    survey.engagement_survey? ? "feature.survey.responses.fields.users_connections_responses_html".translate( users: response_rate_hash[:users_overdue], connections: response_rate_hash[:users_overdue_groups_or_meetings_count], :mentoring_connections => _mentoring_connections, tooltip: embed_icon(TOOLTIP_IMAGE_CLASS,'', :id => "users_connections_overdue_responses_text")) :  "feature.survey.responses.fields.members_meetings_responses_html".translate(users_count: response_rate_hash[:users_overdue], meetings_count: response_rate_hash[:users_overdue_groups_or_meetings_count], :_meetings => _meetings)
  end

  def options_for_select_for_questions(questions, is_survey_type)
    options = []
    options << ["common_text.prompt_text.Select".translate, ""]
    key = is_survey_type ? "answers" : "column"
    questions.each do |question|
      question_text = is_survey_type ? question.question_text_for_display : question.question_text
      options << [question_text, "#{key}#{question.id}", {class: get_class_for_profile_question_filter_options(question, is_survey_type)}]
    end
    options_for_select(options)
  end

  def questions_container_operator_options
    [
      ["common_text.prompt_text.Select".translate, ""],
      ["feature.survey.survey_report.filters.operators.Contains".translate, SurveyResponsesDataService::Operators::CONTAINS, :class => "cjs_additional_text_box"],
      ["feature.survey.survey_report.filters.operators.not_contains".translate, SurveyResponsesDataService::Operators::NOT_CONTAINS, :class => "cjs_additional_text_box cjs_choice_based_operator"],
      ["feature.survey.survey_report.filters.operators.filled".translate, SurveyResponsesDataService::Operators::FILLED],
      ["feature.survey.survey_report.filters.operators.not_filled".translate, SurveyResponsesDataService::Operators::NOT_FILLED]
    ]
  end

  def role_filter_label(survey)
    case survey.type
    when Survey::Type::PROGRAM
      "feature.survey.survey_report.filters.header.user_role".translate
    when Survey::Type::ENGAGEMENT
      "feature.survey.survey_report.filters.header.user_role_in_engagement".translate(connection_term: _Mentoring_Connection)
    end
  end

  def get_survey_type_for_ga(survey)
    survey.meeting_feedback_survey? ? "#{survey.role_name.capitalize}#{survey.type}" : survey.type
  end

  def get_survey_question_condition_options
    [
      ["feature.survey.content.condition.always".translate, SurveyQuestion::Condition::ALWAYS],
      ["feature.survey.content.condition.completed".translate(meeting: _meeting), SurveyQuestion::Condition::COMPLETED],
      ["feature.survey.content.condition.cancelled".translate(meeting: _meeting), SurveyQuestion::Condition::CANCELLED]
    ]
  end

  def last_question_of_completed_or_cancelled_type_error_flash(condition)
    other_condition = (condition == SurveyQuestion::Condition::COMPLETED) ? "feature.survey.content.condition.completed".translate(meeting: _meeting) : "feature.survey.content.condition.cancelled".translate(meeting: _meeting)
    "flash_message.survey_flash.completed_or_cancelled_last_question_error_v1".translate(other_condition: other_condition)
  end

  def render_surveys_title(survey_name, survey_type)
    title_with_tooltip = "feature.survey.header.survey_label".translate(Survey_Name: survey_name) +
      content_tag(:span, get_icon_content("fa fa-info-circle"), data: {title: "feature.survey.header.label_description.#{survey_type}".translate(Survey_Name: survey_name, program: _program, meeting: _meeting), toggle: "tooltip"}, :class => "m-l-xs")
    header = content_tag(:h5, title_with_tooltip.html_safe, class: "col-xs-8 no-padding font-600")

    header += link_to("feature.survey.action.New_Survey".translate, new_survey_path(survey_type: survey_type), class: 'btn btn-primary btn-sm cjs_new_survey_button pull-right') if Survey::Type.admin_createable.include?(survey_type)
    header
  end

  def render_progress_report_checkbox(survey, options = {})
    wrapper_options = {id: "engagement_survey_options"}
    wrapper_options[:class] = options[:wrapper_class] if options[:wrapper_class]
    content_tag(:div, wrapper_options) do
      controls(id: "progress_report", class: "col-sm-offset-3 col-sm-9 #{options[:class]}") do
        content_tag(:label, class: "checkbox inline") do
          (check_box_tag 'survey[progress_report]', true, survey.progress_report) +
          "feature.survey.label.progress_report".translate(mentoring_connection: _mentoring_connection)
        end
      end
    end
  end

  def render_share_progress_report_checkbox(survey, group)
    return unless survey.can_share_progress_report?(group)

    content_tag(:div, class: "well no-border white-bg clearfix no-vertical-margins p-b-0") do
      content_tag(:label, class: "checkbox inline") do
        (check_box_tag 'share_progress_report', true, true) +
        "feature.survey.label.share_progress_report".translate(mentoring_connection: _mentoring_connection)
      end
    end
  end

  private

  def survey_deletion_warning(survey_name, options = {})
    content = get_safe_string
    content += "feature.survey.content.deletion_warning_content.general_html".translate(survey_name: h(survey_name).to_str)
    content += if options[:associated_tasks_in_closed_groups]
      " #{'feature.survey.content.deletion_warning_content.removes_responses_and_closed_groups_tasks'.translate(mentoring_connections: _mentoring_connections)}"
    else
      " #{'feature.survey.content.deletion_warning_content.removes_responses'.translate}"
    end
    affected_areas = []
    affected_areas << "feature.reports.label.program_health_report_name".translate(Program: _Program) if options[:tied_to_health_report]
    affected_areas << "feature.reports.header.program_outcomes_report".translate(Program: _Program) if options[:tied_to_outcomes_report]
    content += " #{'feature.survey.content.deletion_warning_content.affects_health_report_or_positive_outcomes'.translate(affected_areas: affected_areas.to_sentence)}" if affected_areas.present?
    content += " #{'display_string.do_you_want_to_proceed'.translate}"
    content
  end

  def get_class_for_profile_question_filter_options(question, is_survey_type)
    if question.choice_or_select_type?
      "cjs_choice_based_question"
    elsif question.file_type?
      "cjs_file_question"
    elsif !is_survey_type && question.date?
      "cjs_date_question"
    else
      "cjs_text_question"
    end
  end
end