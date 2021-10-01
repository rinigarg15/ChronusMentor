module CommonAnswersHelper
  # Renders a label the answer for common_question.
  # Adds some special help text for complex question types, like multiple choice.
  def common_answer_label(common_question, options = {})
    content = common_question.question_text
    content = set_required_field_label(content) if common_question.required
    if needs_false_label_common_question?(common_question)
      content_tag :label, :class => "control-label false-label m-b-xs #{options[:class]}" do
        content
      end
    else
      content_tag :label, :class => "control-label #{options[:class]}", :for => "common_answers_#{common_question.id}" do
        content
      end
    end
  end

  # Given an common_answer, format it for showing in profile. Autolink the
  # content so that email or other urls get linked.
  def formatted_common_answer(common_answer, common_question = common_answer.common_question, options = {})
    return content_tag(:i, "common_text.Not_specified".translate, class: "text-muted") if common_answer.nil? || common_answer.unanswered?
    question_type = common_question.question_type

    # Link to file in case of 'file' type.
    if question_type == CommonQuestion::Type::FILE
      ans_text = get_safe_string + common_answer.attachment_file_name +
        content_tag(:small, '('.html_safe + link_to("display_string.download".translate, common_answer.attachment.url, :target => "_blank", :class => 'cjs_android_download_files', :data => {:filename => common_answer.attachment_file_name, :targeturl => common_answer.attachment.url}) + ')'.html_safe, :class => 'ans_file')
    elsif [CommonQuestion::Type::MULTI_STRING, CommonQuestion::Type::MULTI_CHOICE].include?(question_type) && common_answer.answer_value.size > 1
      ans_text = content_tag(:ul, common_answer.answer_value.collect{|v| content_tag(:li, v)}.join.html_safe)
    elsif question_type == CommonQuestion::Type::TEXT
      if options[:no_paragraph]
        ans_text = textilize_without_paragraph(h(common_answer.answer_text)).html_safe
      else
        ans_text = textilize(h(common_answer.answer_text)).html_safe
      end
    elsif question_type.in?(CommonQuestion::Type.choice_based_types)
      ans_text = common_answer.selected_choices_to_str_for_view(common_question)
    else
      ans_text = common_answer.answer_text
    end

    chronus_auto_link(ans_text)
  end

  # Renders the appropriate field edit control for a given common_answer
  #
  #               Type                   |               Control
  #  ------------------------------------+--------------------------------------
  #  String                              | Text field
  #  Text                                | Text area
  #  SingleChoice                        | Combox
  #  MultiChoice                         | Set of checkboxes
  #  File                                | File field
  #
  # The helpers generate controls with the name: <answer_prefix>[<question-id>].
  # So, in the update method, these fields are received as an common_answers
  # hash as :common_answers
  # => {<question_id> => <common_answer> ...} For multiselect, the value will be an
  # array. Eg. :common_answers => { <multi_choice_question_id> => [ans1, ans2,
  # ...] } Look at UsersController#update to see how the update is handled.
  def edit_common_answer_field(common_answer, common_question = common_answer.common_question, options = {})
    string = "".html_safe
    unless common_question.help_text.blank?
      help_text = help_text_content(common_question.help_text, common_question.id)
    else
      help_text = "".html_safe
    end
    case common_question.question_type
    when CommonQuestion::Type::STRING
      string += edit_string_field_common_answer(common_answer)
    when CommonQuestion::Type::MULTI_STRING
      string += edit_multi_string_field_common_answer(common_answer)
    when CommonQuestion::Type::TEXT
      string += edit_text_field_common_answer(common_answer)
    when CommonQuestion::Type::SINGLE_CHOICE
      string += edit_single_choice_field_type(common_answer, common_question)
    when CommonQuestion::Type::MULTI_CHOICE
      string += edit_multi_choice_field_type(common_answer, common_question, options[:skip_quick_search].present?)
    when CommonQuestion::Type::RATING_SCALE
      string += edit_rating_scale_type(common_answer, common_question)
    when CommonQuestion::Type::FILE
      string += edit_file_type(common_answer)
    when CommonQuestion::Type::MATRIX_RATING
      rating_questions = common_question.rating_questions
      choices = common_question.default_choices
      string += render(:partial => 'common_questions/matrix_question_preview', :locals => {:rating_questions => rating_questions, :choices => choices, :element_class => "matrix_answers_#{common_question.id}", :forced_ranking => common_question.matrix_setting == CommonQuestion::MatrixSetting::FORCED_RANKING, :matrix_question_answers_map => options[:matrix_question_answers_map]||{}, :mobile_view => options[:mobile_view]})
    end
    unless common_question.question_type == CommonQuestion::Type::MULTI_STRING
      string += help_text
    end
    return string
  end

  def edit_string_field_common_answer(common_answer)
    text_field_tag("#{answer_field_prefix(common_answer)}[#{common_answer.common_question.id}]",
      common_answer.answer_text, :class => 'form-control',
      :id => "common_answers_#{common_answer.common_question.id}")
  end

  def edit_multi_string_field_common_answer(common_answer)
    q_id = common_answer.common_question.id
    control_name = "#{answer_field_prefix(common_answer)}[#{q_id}][]"
    user_common_answers = common_answer.answer_value || []
    input_id = "#{answer_field_prefix(common_answer)}_#{q_id}_"

    string = "".html_safe
    string += label_tag(control_name, common_answer.common_question.question_text, :for => "#{answer_field_prefix(common_answer)}_#{q_id}", :class => "sr-only")
    string += content_tag('div', :id => "common_answers_#{q_id}", :class => "multi_line") do
      if user_common_answers.empty?
        sub_string = text_field_tag control_name, '', :class => 'form-control', :id => "#{answer_field_prefix(common_answer)}_#{q_id}"
      else
        sub_string = text_field_tag control_name, user_common_answers[0], :class => 'form-control', :id => "#{answer_field_prefix(common_answer)}_#{q_id}"
        user_common_answers[1..-1].each do |ans|
          sub_string += javascript_tag("jQuery(document).ready(function(){MultiLineAnswer.addAnswer(jQuery('#add_new_#{q_id}'), '#{control_name}', '#{ans}', '#{"feature.common_questions.content.provide_another_answer".translate}', '#{input_id}')});")
        end
      end
      if common_answer.common_question.help_text.blank?
        sub_string += link_to_function(append_text_to_icon('fa fa-plus-circle text-default',"display_string.Add_more".translate), "MultiLineAnswer.addAnswer(this , '#{control_name}', null, '#{"feature.common_questions.content.provide_another_answer".translate}', '#{input_id}')", :class => "help-block add_new_line btn btn-white btn-sm m-t", :id => "add_new_#{q_id}")
      else
        sub_string += help_text_content(common_answer.common_question.help_text,q_id)
        sub_string += link_to_function(append_text_to_icon('fa fa-plus-circle text-default',"display_string.Add_more".translate), "MultiLineAnswer.addAnswer(jQuery('#question_help_text_#{q_id}'), '#{control_name}', null, '#{"feature.common_questions.content.provide_another_answer".translate}', '#{input_id}')", :class => "help-block add_new_line btn btn-white btn-sm m-t", :id => "add_new_#{q_id}")
      end
      sub_string
    end

  end

  def edit_text_field_common_answer(common_answer)
    text_area_tag("#{answer_field_prefix(common_answer)}[#{common_answer.common_question.id}]",
      common_answer.answer_text, :rows=> 5, :class => 'form-control cjs_supress_auto_resize',
      :id => "common_answers_#{common_answer.common_question.id}")
  end

  def edit_single_choice_field_type(common_answer, common_question = common_answer.common_question)
    answer_choices = common_question.default_choices
    default_answer = common_answer.selected_choices(common_question, default_choices: true)[0]
    other_text = common_answer.selected_choices(common_question, other_choices: true)[0]
    other_value = other_text.blank? ? "other" : other_text
    selected_or_not = other_text.blank? ? false : "selected"
    control_name = "#{answer_field_prefix(common_answer)}[#{common_question.id}]"
    options = content_tag(:option, "common_text.prompt_text.Select".translate, :value => "")
    options += options_from_collection_for_select(answer_choices, "to_s", "to_s", default_answer)
    options += content_tag(:option, "common_text.prompt_text.Other_prompt".translate, :value => "#{other_value}", :selected => selected_or_not) if common_question.allow_other_option?
    str = content_tag(:div) do
      select_tag(control_name, options, {:id => "common_answers_#{common_question.id}", :class => "cjs_expand_contract form-control big", :onchange => "CustomizeQuestions.editOtherOptionSingleChoice(#{common_question.id})"})
    end
    str << edit_other_option_type(common_answer, false, other_text, false, false, -1, :div_class => "m-t-sm no-padding") if common_question.allow_other_option?
    str
  end

  def edit_multi_choice_field_type(common_answer, common_question = common_answer.common_question, skip_quick_search = false)
    default_question_choices = common_question.default_choice_records
    answered_qc_ids = common_answer.answer_choices.collect(&:question_choice_id)
    default_answer_qc_ids = default_question_choices.collect(&:id) & answered_qc_ids

    unless skip_quick_search
      find_select_str = dynamic_text_filter_box("find_and_select_#{common_question.id}",
        "find_common_answer_#{common_question.id}",
        "MultiSelectAnswerSelector",
        { :handler_argument => "common_answers_#{common_question.id}",
          :filter_box_additional_class => "no-padding"
        })
    end

    # Values for this field should be parsed as an array
    control_name = "#{answer_field_prefix(common_answer)}[#{common_question.id}][]"

    str = "".html_safe
    default_question_choices.collect{|qc| [qc.id, qc.text]}.each do |qc_id, choice|
      r_id = "common_answers_#{common_question.id}_#{choice}_container".to_html_id
      str << content_tag(:div, :class => 'col-xs-12 clearfix checkbox cjs_quicksearch_item big', :id => r_id) do
        # JS observer to select a check box on clicking on a corresponding label is handled at *MultiSelectAnswerSelector()*
            content_tag(:label, :class => "multi_select_label", :id => escape_javascript("common_answers_label_#{common_question.id}_#{choice}".to_html_id)) do
              check_box_tag(control_name, choice, default_answer_qc_ids.include?(qc_id),
                :id => "common_answers_#{common_question.id}_#{choice}".to_html_id,
                :class => "multi_select_check_box") +
              choice
            end
      end
    end

    if common_question.allow_other_option?
      other_text = common_answer.selected_choices(common_question, other_choices: true).join(", ")

      r_id = "common_answers_#{common_question.id}_other_container".to_html_id
      other_value = other_text.blank? ? "display_string.other".translate : other_text
      str << content_tag('div', :class => "col-xs-12 clearfix checkbox cjs_quicksearch_item
        big", :id => r_id) do
        label = content_tag(:label, :class => "multi_select_label", :id => escape_javascript("common_answers_label_#{common_answer.common_question.id}_other".to_html_id)) do
          check_box_tag(control_name, other_value, other_text.present?, :class => 'multi_select_check_box', :id => "common_answers_#{common_answer.common_question.id}_other",
            :onclick=>"CustomizeQuestions.editOtherOptionMultiChoice(#{common_answer.common_question.id})") +
          "common_text.prompt_text.Other_prompt".translate
        end
        hidden_mirror = content_tag(:span, other_text, :class => "hide", :id => "quicksearch_other_mirror_#{common_answer.common_question_id}")
        other_input = edit_other_option_type(common_answer, true, other_text, false, false, -1, :div_class => "no-padding")
        label + hidden_mirror + other_input
      end
    end

    str << hidden_field_tag(control_name) # This is required in the case the user de-selects all the choices, so that an empty array is returned

    find_select_script = javascript_tag( %Q[
        QuicksearchBox.initializeWithOther(
                  '#quick_find_common_answer_#{common_question.id}',
                  '#common_answers_#{common_question.id}',
                  '#common_answers_#{common_question.id}_other',
                  '#other_option_#{common_question.id} input',
                  '#quicksearch_other_mirror_#{common_question.id}');
      ]) unless skip_quick_search
    well_class = "p-t-xxs choices_wrapper white-bg clearfix"
    scroll_required = default_question_choices.size > MUTLI_CHOICE_TYPE_OPTIONS_LIMIT
    scroll_script = scroll_required ? javascript_tag("initialize.setSlimScroll()") : ""
    content = content_tag(:div, choices_wrapper("feature.profile_question.label.choices".translate, :data => {:slim_scroll => scroll_required}, :id => ""){ str }, :class => 'col-xs-12 no-padding')
    ((default_question_choices.size > MUTLI_CHOICE_TYPE_OPTIONS_LIMIT) && !skip_quick_search) ? content_tag(:div, (find_select_str + content + find_select_script), :class => well_class, :id => "common_answers_#{common_question.id}") + scroll_script : content_tag(:div, content, :class => well_class, :id => "common_answers_#{common_question.id}") + scroll_script
  end

  def edit_rating_scale_type(common_answer, common_question = common_answer.common_question)
    str = get_safe_string

    control_name = "#{answer_field_prefix(common_answer)}[#{common_question.id}]"
    user_common_answer = common_answer.answer_value(common_question)
    str << hidden_field_tag(control_name)
    common_question.default_choices.each do |choice|
      # Another dummy wrapper to make the HTML markup similar to that of other
      # choice type questions. This is done in order to reuse the JS validation.
      str <<  content_tag(:label, class: "radio big") do
                radio_button_tag(control_name, choice, choice == user_common_answer,
                  id: "common_answers_#{common_question.id}_#{choice}".to_html_id)  +
                choice
              end
    end

    choices_wrapper("feature.profile_question.label.choices".translate, class: 'ratings_wrapper white-bg p-t-xxs clearfix', id: "common_answers_#{common_question.id}"){ str }
  end

  def edit_other_option_type(answer, multi_select = false, other_text = "", profile_a = false, ordered_type = false, opt_index = -1, options = {})
    question_id = profile_a ? answer.profile_question_id : answer.common_question_id
    section_id = answer.profile_question.section.id if profile_a
    hide_or_show = other_text.blank? ? "hide " : "inline "
    div_id = ordered_type ? "other_option_#{question_id}_#{opt_index}" : "other_option_#{question_id}"
    preview_id = ordered_type ? "preview_#{question_id}_#{opt_index}" : "preview_#{question_id}"
    if profile_a && answer.profile_question.ordered_options_type?
      onchange_method =  "CustomizeQuestions.updateAnswerValueOrderedChoice( #{question_id}, #{opt_index}, #{section_id});"
    else
      onchange_method = multi_select ? "CustomizeQuestions.updateAnswerMultiChoice(#{question_id});" : "CustomizeQuestions.updateAnswerSingleChoice(#{question_id});"
    end
    is_prof_comp = @is_profile_completion || false
    onchange_method << "CustomizeProfileQuestions.toggleDependentQuestionsInputField('.cjs_dependent_#{question_id}', '.cjs_question_#{question_id}', #{is_prof_comp});" if profile_a
    if (profile_a && answer.profile_question.question_type == ProfileQuestion::Type::MULTI_CHOICE) || (!profile_a && answer.common_question.question_type == CommonQuestion::Type::MULTI_CHOICE)
      placeholder = 'common_text.placeholder.non_single_choice'.translate
    else
      placeholder = 'common_text.placeholder.single_choice'.translate
    end
    margins = ordered_type ? "m-t-xs no-padding" : ""
    content_tag(:div, :id => div_id, :class => "#{hide_or_show} #{margins} col-xs-12 #{options[:div_class]}") do
      label_tag(preview_id, "feature.common_questions.content.other_option".translate, :for => preview_id, :class => 'sr-only') +
      text_field_tag(preview_id, other_text, :class => 'form-control', :placeholder => placeholder,
              :onchange => onchange_method)
    end
  end

  # Customization fields for question of type <i>CommonQuestion::Type::FILE</i>
  def edit_file_type(common_answer)
    upload_tag = file_field_tag("#{answer_field_prefix(common_answer)}[#{common_answer.common_question.id}]",
        :id =>  "common_answers_#{common_answer.common_question.id}".to_html_id, :class => "form-control-static")
    file_type_content = if common_answer.present? && !common_answer.unanswered?
      get_safe_string + common_answer.attachment_file_name +
      content_tag(:small, '('.html_safe + link_to_function("display_string.edit".translate, "jQuery('#edit_profile_upload_toggle_common_answers_#{common_answer.common_question.id}').toggle()") + ')'.html_safe, :class => 'ans_file')  +
        content_tag(:div, upload_tag, :id => "edit_profile_upload_toggle_common_answers_#{common_answer.common_question.id}", :class=> "hide m-t-sm")
      else
        upload_tag
      end
    content_tag(:div, file_type_content, class: "cjs_file_field_wrapper")
  end

  # Returns the form element array prefix to use for the common_answer
  def answer_field_prefix(common_answer)
    klassname = common_answer.class.name
    klassname.underscore.gsub('/', '_').pluralize
  end
end
