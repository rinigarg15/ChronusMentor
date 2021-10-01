module SurveyResponsesHelper
  KENDO_GRID_ID = "cjs_survey_responses_listing_kendogrid"

  def survey_responses_header_wrapper(title, options={})
    options[:class] = options[:class].to_s + " cjs_sr_header"
    content_tag(:span, title, options)
  end

  def survey_response_checkbox(id)
    content_tag(:input, "", type: "checkbox", class: "cjs_select_all_record cjs_survey_response_checkbox cjs_select_all_checkbox_#{id}", id: "cjs_sr_checkbox_#{id}", value: "#{id}") +
      label_tag("cjs_sr_checkbox_#{id}", "#{id}", class: 'sr-only')
  end

  def survey_responses_actions(survey, response_id)
    content = content_tag :div, :class => "strong cjs_actions_#{response_id}" do
      link_to(get_icon_content("fa fa-align-justify text-default") + set_screen_reader_only_content("display_string.View".translate), survey_response_path(:survey_id => survey.id, :id => response_id), class: "has-next-1 cjs_actions_email_#{response_id}", :title => "display_string.View".translate) +
      link_to(get_icon_content("fa fa-download text-default") + set_screen_reader_only_content("display_string.Download".translate), export_as_xls_survey_responses_path(survey, :id => response_id, :format => :xls), class: "cjs_actions_xls_#{response_id}", :title => "display_string.Download".translate)
    end
    content
  end

  def survey_responses_additional_survey_information(survey, response)
    if survey.engagement_survey?
      link_to(response[:group].name, group_url(response[:group])) if response[:group].present?
    elsif survey.meeting_feedback_survey?
      link_to_if(response[:meeting].active?, response[:meeting_name], meeting_path(response[:meeting], current_occurrence_time: response[:meeting].first_occurrence))
    end
  end

  def survey_responses_primary_columns(survey)
    columns = [ { title: get_primary_checkbox_for_kendo_grid, field: "check_box", width: "40px", encoded: false, sortable: false, filterable: false } ]
    columns << { field: "actions", width: "65px", headerTemplate: "feature.survey.responses.fields.actions".translate, filterable: false, sortable: false, encoded: false }.merge(column_format(:centered))
    choices_map = {}

    survey.survey_response_columns.of_default_columns.each do |column|
      if column.column_key == SurveyResponseColumn::Columns::Roles
        roles = survey.engagement_survey? ? current_program.roles.for_mentoring : current_program.roles
        choices_map[column.kendo_column_field] = roles.collect { |role| { title: role.customized_term.term, value: role.name } }
      end
      filterable_options = get_kendo_filterable_options(column.kendo_column_field, choices_map, extra: (column.column_key == SurveyResponseColumn::Columns::ResponseDate))
      column_options = { field: column.column_key, width: "200px", headerTemplate: column.kendo_field_header, encoded: false, filterable: filterable_options }.merge(column_format(:centered))
      if column.column_key == SurveyResponseColumn::Columns::ResponseDate
        column_options.merge!(template: "#= kendo.toString(#{SurveyResponseColumn::Columns::ResponseDate},'MMM dd, yyyy') #")
      end
      columns << column_options
    end
    columns
  end

  def profile_questions_based_columns(survey, choices_map)
    profile_question_id_to_column_map = survey.survey_response_columns.of_profile_questions.index_by(&:profile_question_id)
    survey.profile_questions_to_display.collect do |profile_question|
      column = profile_question_id_to_column_map[profile_question.id]
      field_name = column.kendo_column_field
      column_options = {
        field: field_name,
        width: "300px",
        headerTemplate: survey_responses_header_wrapper(column.profile_question.question_text),
        encoded: false,
        filterable: get_kendo_filterable_options(field_name, choices_map, extra: profile_question.date?)
      }
      column_options.merge(column_format(:centered))
    end
  end

  def survey_responses_survey_answer_columns(survey, choices_map)
    survey.get_questions_from_response_columns_for_display.collect do |question|
      field_name = question.kendo_column_field
      {
        field: field_name,
        width: "300px",
        headerTemplate: survey_responses_header_wrapper(question.question_text_for_display),
        encoded: false,
        filterable: get_kendo_filterable_options(field_name, choices_map)
      }.merge(column_format(:centered))
    end
  end

  def survey_responses_columns(survey)
    choices_map = get_choices_map_for_survey(survey)
    survey_responses_primary_columns(survey) + survey_responses_survey_answer_columns(survey, choices_map) + profile_questions_based_columns(survey, choices_map)
  end

  def survey_responses_kendo_fields
    {
      id: { type: :string },
      name: { type: :string },
      date: { type: :date }
    }
  end

  def survey_responses_kendo_options(survey)
    {
      columns: survey_responses_columns(survey),
      fields: survey_responses_kendo_fields,
      dataSource: data_survey_responses_path(survey, format: :json),
      grid_id: "cjs_survey_responses_listing_kendogrid",
      selectable: false,
      serverPaging: true,
      serverFiltering: true,
      serverSorting: true,
      sortable: {
        allowUnsort: false
      },
      sortField: SurveyResponseColumn::Columns::ResponseDate,
      sortDir: "desc",
      pageable: {
        messages: {
          display: 'feature.survey.responses.kendo.pageable_message'.translate,
          empty: "feature.survey.responses.kendo.no_responses".translate
        }
      },
      pageSize: SurveyResponsesDataService::DEFAULT_PAGE_SIZE,
      filterable: {
        messages: kendo_operator_messages
      },
      fromPlaceholder: 'display_string.From'.translate,
      toPlaceholder: 'display_string.To'.translate,
      autoCompleteFields: [SurveyResponseColumn::Columns::SenderName],
      dateFields: SurveyResponseColumn.date_range_columns(survey),
      numericFields: [],
      autoCompleteUrl: auto_complete_for_name_users_path(format: :json, show_all_users: true),
      customAccessibilityMessages: kendo_custom_accessibilty_messages
    }
  end

  def get_choices_map_for_survey(survey)
    choices_map = {}

    survey_questions = survey.get_questions_from_response_columns_for_display
    filterable_survey_questions = survey_questions.select do |survey_question|
      survey_question.question_type.in? CommonQuestion::Type.checkbox_filterable
    end
    profile_questions = survey.profile_questions_to_display
    filterable_profile_questions = profile_questions.select(&:choice_or_select_type?)

    questions_data = [
      [filterable_survey_questions, "answers"],
      [filterable_profile_questions, "column"]
    ]
    questions_data.each do |data|
      questions, field_name_prefix = data
      questions.each do |question|
        field_name = "#{field_name_prefix}#{question.id}"
        values_and_choices = question.values_and_choices
        choices_map[field_name] = values_and_choices.collect do |value, choice|
          { title: h(choice), value: h(value) }
        end
      end
    end
    choices_map
  end

  def initialize_survey_responses_script(survey, total_entries)
    options = survey_responses_kendo_options(survey)
    javascript_tag %Q[ProgressReports.initializeBulkActions('#{"feature.survey.responses.errors.select_atleast_one_response".translate}');CommonSelectAll.initializeSelectAll(#{total_entries}, #{KENDO_GRID_ID});ProgressReports.initializeKendo(#{options.to_json})]
  end

  def survey_responses_page_actions(survey)
    bulk_actions = [{:label => get_icon_content("fa fa-envelope") +  "Email report", :url => "javascript:void(0);", class: 'cjs_bulk_action', id: "email_report_popup",
                    :data => {:js => 'ProgressReports.emailReportBulkAction();', url: email_report_popup_survey_responses_path(survey)}},
                    {:label => get_icon_content("fa fa-download") + "Export to xls", :url => "javascript:void(0);", class: 'cjs_bulk_action',
                    :data => {:js => 'ProgressReports.xlsBulkAction();'}}]
    get_kendo_bulk_actions_box(bulk_actions)
  end

  def format_user_roles(user, group, connection_role_id)
    role_names =
      if group.present?
        connection_role_id ? current_program.roles.find(connection_role_id).customized_term.term : "-"
      else
        RoleConstants.to_program_role_names(current_program, user.role_names)
      end
    content_tag(:ul, [*role_names].inject(get_safe_string) { |role_names_html, role_name| role_names_html + content_tag(:li, role_name) }, class: "unstyled no-margin")
  end

  def get_data_hash_for_survey_response_link(answer)
    { user_id: answer.user_id, response_id: answer.response_id, survey_id: answer.survey.id, format: :js }
  end
end