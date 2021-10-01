module CommonQuestionsHelper
  include TranslationsService  

  # Returns the ActiveRecord object to be used by the form helper for the
  # <i>common_question</i>
  def form_object_for_common_question(common_question)
    common_question.is_a?(SurveyQuestion) ?
        [common_question.survey, common_question] : common_question
  end

  # Renders a preview plus edit form for the common_question
  def preview_and_edit_common_question(common_question)
    no_edit = common_question.non_editable?
    content_tag(:div, :id => "common_question_#{common_question.id}",
      :class => 'clearfix m-b-md well white-bg draggable animated fadeInDown') do
      content = render(:partial => 'common_questions/preview', :locals => {:common_question => common_question, :no_edit => no_edit, :form_obj => form_object_for_common_question(common_question)})
      unless no_edit
        content += render(:partial => 'common_questions/edit', :locals => {
        :common_question => common_question,
        :form_obj => form_object_for_common_question(common_question)})
      end
      content
    end
  end

  # Renders a preview of how the question will be presented to users.
  def preview_common_question(common_question, options = {})
    string = get_safe_string
    unless common_question.help_text.blank?
      help_text = help_text_content(common_question.help_text,common_question.id)
    else
      help_text = help_text_content(nil,common_question.id)
    end
    case common_question.question_type
    when CommonQuestion::Type::STRING
      string += text_field_tag "preview_#{common_question.id}", '', :class => 'textinput form-control'
    when CommonQuestion::Type::TEXT
      string += text_area_tag "preview_#{common_question.id}",'', :class => 'form-control', :rows => 4
    when CommonQuestion::Type::SINGLE_CHOICE
      string += preview_of_single_choice(common_question)
      string += preview_other_option(common_question) if common_question.allow_other_option?
    when CommonQuestion::Type::MULTI_CHOICE
      scroll_required = common_question.default_choices.size > MUTLI_CHOICE_TYPE_OPTIONS_LIMIT
      string += content_tag('div', :class => "choices_wrapper clearfix no-margins white-bg", :data => {:slim_scroll => scroll_required}) do
        substring = get_safe_string
        common_question.default_choices.each do |value|
          substring += content_tag(:label, (tag(:input, :type => "checkbox", :class => "multi_select_check_box") + value.to_s), :class => 'big checkbox multi_select_label')
        end
        if common_question.allow_other_option?
          substring += content_tag(:label, :class => 'big checkbox multi_select_label')  do
            check_box_tag(nil, 'other', false, :class => 'multi_select_check_box', :id => "select_#{common_question.id}_other",
              :onclick => "CustomizeQuestions.editMultiChoice('select_', #{common_question.id})") +
            "common_text.prompt_text.Other_prompt".translate
          end
          substring += preview_other_option(common_question, true)
          substring += javascript_tag("initialize.setSlimScroll()") if scroll_required
        end
        substring
      end

    when CommonQuestion::Type::RATING_SCALE
      string += choices_wrapper("feature.profile_question.label.choices".translate, class: "white-bg no-margins clearfix ratings_wrapper") do
        substring = get_safe_string
        common_question.default_choices.each do |value|
          substring << content_tag(:label, (tag(:input, :type => "radio", :name => "rating") + value.to_s), :class => "big radio multi_select_label")
        end
        substring
      end

    when CommonQuestion::Type::FILE
      string += file_field_tag "preview_#{common_question.id}"

    when CommonQuestion::Type::MULTI_STRING
      string += label_tag("multi_line[]", common_question.question_text, :for => "preview_#{common_question.id}", :class => "sr-only")
      string += content_tag('div', :id => "preview_div_#{common_question.id}", :class => "multi_line") do
        sub_string = text_field_tag "multi_line[]", '', :class => 'textinput form-control', :id => "preview_#{common_question.id}"
        sub_string += help_text
        sub_string += link_to_function(get_icon_content('fa fa-plus-circle') + "display_string.Add_more".translate, "MultiLineAnswer.addAnswer(jQuery('#question_help_text_#{common_question.id}'), 'multi_line[]', null, '#{"feature.common_questions.content.provide_another_answer".translate}', '#preview_#{common_question.id}_')", :class => "btn btn-white btn-sm no-shadow add_new_line")
        sub_string
      end
    when CommonQuestion::Type::MATRIX_RATING
      rating_questions = common_question.rating_questions
      choices = common_question.default_choices
      string += render(:partial => 'common_questions/matrix_question_preview', :locals => {:rating_questions => rating_questions, :choices => choices, :element_class => "matrix_answers_#{common_question.id}", :forced_ranking => common_question.matrix_setting == CommonQuestion::MatrixSetting::FORCED_RANKING, :matrix_question_answers_map => {}, :mobile_view => options[:mobile_view]})
    end
    unless common_question.question_type == CommonQuestion::Type::MULTI_STRING
      string += help_text
    end
    return string
  end

  def preview_of_single_choice(common_question, onchange_content_input_field="")
    onchange_content = onchange_content_input_field
    onchange_content += "CustomizeQuestions.editSingleChoice('preview_', #{common_question.id});"
    options = ["common_text.prompt_text.Select".translate] + common_question.default_choices
    options += [["common_text.prompt_text.Other_prompt".translate,"other"]] if common_question.allow_other_option?
    select_tag(common_question.question_text, options_for_select(options), {:class => "form-control cjs_expand_contract", :id => "preview_#{common_question.id}", :onchange => onchange_content})
  end

  def preview_other_option(common_question, multi_select = false)
    if common_question.question_type == CommonQuestion::Type::MULTI_CHOICE
      placeholder = 'common_text.placeholder.non_single_choice'.translate
    else
      placeholder = 'common_text.placeholder.single_choice'.translate
    end
    content_tag(:div, :id => "other_option_#{common_question.id}", :class => "col-xs-12 m-t-xs hide") do
      label_tag("preview_other_option_#{common_question.id}", "feature.profile_question.label.other_option".translate, :class => "sr-only") +
      text_field_tag("preview_other_option_#{common_question.id}", '', :class => 'form-control', :placeholder => placeholder)
    end
  end

  def needs_false_label_common_question?(common_question)
    [CommonQuestion::Type::MULTI_STRING,
      CommonQuestion::Type::MULTI_CHOICE,
      CommonQuestion::Type::RATING_SCALE].include?(common_question.question_type)
  end

  def get_bulk_add_common_choices_link(id_used)
    content_tag :div, link_to("feature.profile_question.choices.label.button_bulk_add_choices".translate, "javascript:void(0)",  class: "pull-right", id: "cjs_bulk_add_choices_#{id_used}"), class: "clearfix control-label", id: "cjs_bulk_add_wrapper_#{id_used}"
  end

  def show_matrix_question_rows(matrix_question)
    id_used = matrix_question.id || "new"
    content_tag(:div, (get_rows_well(matrix_question, id_used)).html_safe, id: "matrix_question_multi_rows_#{id_used}")
  end

  def get_rows_well(matrix_question, id_used)
    find_select_str = dynamic_text_filter_box(
                          "find_and_select_rows_#{id_used}",
                          "find_matrix_question_rows_#{id_used}",
                          "MultiSelectAnswerSelector",
                          {handler_argument: "#matrix_question_rows_#{id_used}",
                          filter_box_additional_class: "no-padding m-t-0",
                          display_show_helper: false,
                          quick_find_additional_class: "no-border-left no-border-top no-border-right"})

    str = get_rows_and_order(matrix_question, id_used)

    find_select_script = javascript_tag(%Q[jQuery("#quick_find_matrix_question_rows_#{id_used}").quicksearch("#matrix_question_rows_#{id_used} .cjs_quicksearch_item");])

    content = content_tag(:div, content_tag(:div, str, id: "matrix_question_rows_#{id_used}", data: {slim_scroll: true}), class: "col-xs-12 no-padding")
    content_tag(:div, (find_select_str + content + find_select_script), class: "well white-bg clearfix m-b-0 no-padding") + javascript_tag("initialize.setSlimScroll()")
  end

  def get_rows_and_order(matrix_question, id_used)
    row_questions = get_row_questions(matrix_question)
    row_choice_jst = File.open(Rails.root.join("app/assets/javascripts/templates/common_questions/row_question.jst.ejs")).read

    str = content_tag(:ul, id: "matrix_question_rows_list_#{id_used}",class: "list-group disabled_for_editing_false", data: {"matrix_question_id" => id_used}) do
      row_questions.map do |question|
        EJS.evaluate(row_choice_jst, {"matrix_question_id" => id_used, question_id: question.id, question_text: question.question_text, placeholder_text: 'feature.common_questions.label.rows_place_holder'.translate})
      end.join(" ").html_safe
    end.html_safe

    str << hidden_field_tag("matrix_question[rows][new_order]", row_questions.collect(&:id).join(","), id: "matrix_question_#{id_used}_new_order")
  end

  def get_row_questions(matrix_question)
    rating_questions = matrix_question.matrix_rating_question_records
    return rating_questions unless rating_questions.blank?
    return [Struct.new(:id, :question_text).new(1, "")] # To show empty choice on load
  end

  def get_delete_confirmation_warning(common_question)
    effects_hash = get_effects_of_deletion(common_question)
    effects_hash[:impact].present? ? "feature.common_questions.content.delete_confirm_v1.confirmation_message".translate(impact: effects_hash[:impact].to_sentence, impacted_areas: effects_hash[:impacted_areas].to_sentence) : "feature.common_questions.content.delete_confirm".translate
  end

  def get_checked_and_disabled_summary_question_values(common_question, summary)
    return [false, true] if common_question.file_type?
    checked = summary.present? ? !(summary.connection_question != common_question) : false
    disabled = summary.present? ? (summary.connection_question != common_question) : false
    [checked, disabled]
  end

  private

  def get_effects_of_deletion(common_question)
    effects_hash = { impact: [], impacted_areas: [] }
    if common_question.in_health_report?
      effects_hash[:impact] << "#{'feature.common_questions.content.delete_confirm_v1.affects_health_report_v1'.translate(program: _program)}"
      effects_hash[:impacted_areas] <<  "feature.reports.label.program_health_report_name".translate(Program: _Program)
    end
    if common_question.is_a?(SurveyQuestion)
      positive_outcome_warning = get_positive_outcomes_warning(common_question)
      if positive_outcome_warning.present?
        effects_hash[:impact] << positive_outcome_warning
        effects_hash[:impacted_areas] << "feature.reports.header.program_outcomes_report".translate(Program: _Program)
      end
    end
    effects_hash
  end

  def get_positive_outcomes_warning(common_question)
    positive_outcomes = []
    positive_outcomes << "feature.common_questions.content.delete_confirm_v1.admin_dashboard".translate(admin: common_question.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::ADMIN_NAME).term_downcase) if common_question.tied_to_dashboard?
    positive_outcomes << "feature.common_questions.content.delete_confirm_v1.positive_outcome_reports".translate(Program: _Program) if common_question.tied_to_positive_outcomes_report?
    return unless positive_outcomes.present?
    "#{'feature.common_questions.content.delete_confirm_v1.affects_positive_outcomes'.translate(positive_outcomes: positive_outcomes.to_sentence)}"
  end
end
