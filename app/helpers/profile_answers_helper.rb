module ProfileAnswersHelper
  # Renders a label the answer for profile_question.
  # Adds some special help text for complex question types, like multiple choice.
  def profile_answer_label(profile_question, ref_obj, options = {})
    program = ref_obj.program
    role_names = ref_obj.role_names
    required = options[:required].nil? ? profile_question.required_for(program, role_names) : options[:required]
    private_for = options[:private].nil? ? profile_question.private_for(program, role_names) : options[:private]

    content = get_safe_string + profile_question.question_text
    content << " *".html_safe if required
    if private_for && !options[:skip_visibility_info]
      private_text = private_question_help_text(profile_question, program, role_names)
      if private_text.present?
        content << content_tag(:span, private_text, :id => "question_private_tooltip_#{profile_question.id}", :class => "help_tip", :style=> "display:none;")
        content << " ".html_safe + embed_icon("fa fa-lock m-r-0", "", :id => "question_private_icon_#{profile_question.id}")
        content << tooltip("question_private_icon_#{profile_question.id}", private_text)
      end
    end
    if needs_false_label_profile_question?(profile_question, :non_editable => options[:non_editable])
      content_tag :div, :class => "word_break false-label control-label #{options[:class].to_s}" do
        content
      end
    else
      content_tag :label, :for => "profile_answers_#{profile_question.id}", :class => (options[:class] || '') + ' control-label word_break' do
        content
      end
    end
  end

  # Given an common_answer, format it for showing in profile. Autolink the
  # content so that email or other urls get linked.
  def formatted_profile_answer(profile_answer, profile_question, options = {})
    return content_tag(:i, 'display_string.not_applicable'.translate, :class => "text-muted") if profile_answer.present? && profile_answer.not_applicable?
    return content_tag(:i, 'common_text.Not_Specified'.translate, :class => "text-muted") if profile_answer.nil? || profile_answer.unanswered?
    question_type = profile_question.question_type
    other_options = {question_type: question_type}.merge(options.slice(:other_question))
    if [ProfileQuestion::Type::MULTI_STRING, ProfileQuestion::Type::MULTI_CHOICE].include?(question_type)
      answer_value = profile_answer.answer_value(profile_question)
      ans_text = (answer_value.size > 1) ? content_tag(:ul, profile_answer.answer_value(profile_question).collect{|v| content_tag(:li, fetch_highlighted_answers(v, options[:common_values], other_options))}.join, {class: "p-l-m"}, false) : fetch_highlighted_answers(answer_value.first, options[:common_values], other_options)
    elsif question_type == ProfileQuestion::Type::TEXT
      ans_text = textilize(fetch_highlighted_answers(profile_answer.answer_text, options[:common_values], other_options))
    elsif question_type == ProfileQuestion::Type::ORDERED_OPTIONS
      ans_text = content_tag(:ol, profile_answer.answer_value(profile_question).collect{|v| content_tag(:li, fetch_highlighted_answers(v, options[:common_values], other_options))}.join, {class: "p-l-m"}, false)
    elsif question_type == ProfileQuestion::Type::SINGLE_CHOICE
      ans_text = fetch_highlighted_answers(profile_answer.answer_value(profile_question), options[:common_values], other_options)
    elsif question_type == ProfileQuestion::Type::LOCATION
      ans_text = content_tag(:i, nil, class: "fa fa-map-marker m-r-xs") + profile_answer.answer_text
    elsif question_type == ProfileQuestion::Type::DATE
      ans_text = format_date_answer(profile_answer)
    else
      ans_text = fetch_highlighted_answers(profile_answer.answer_text, options[:common_values], other_options)
    end

    ans_text
  end

  def format_user_answers(answers, names, question, options = {})
    return format_filetype_user_answer(answers, names, options) if question.file_type?
    return format_education_experience_publication_user_answer(answers, names, question, options) if question.education_or_experience_or_publication?
    return format_manager_user_answer(answers, names, question, options) if question.manager?
    return format_date_answers(answers, names, options) if question.date?
    return format_simple_user_answer(answers, names, options)
  end

  def format_education_experience_publication_user_answer(answer, names, question, options)
    return format_education_user_answer(answer, names, question, options) if question.education?
    return format_experience_user_answer(answer, names, question, options) if question.experience?
    return format_publication_user_answer(answer, names, question, options) if question.publication?
  end

  def format_date_answers(answers, names, options = {})
    if (answers.count > 1)
      format_date_answers_for_group(answers, names, options)
    else
      format_date_answer(answers[0])
    end
  end

  def format_date_answers_for_group(answers, names, options = {})
    column_contents = get_safe_string
    answers.each_with_index do |ans, i|
      if options[:for_csv]
        column_contents += (format_name_for_group_mentoring(names[i], options) + format_date_answer(ans).html_safe) + "\n" if ans.present?
      else
        column_contents += content_tag(:li, format_name_for_group_mentoring(names[i]) + format_date_answer(ans)) if ans.present?
      end
    end
    return options[:for_csv] ? column_contents : content_tag(:ul, column_contents)
  end

  # input : profile_answer object or answer string
  def format_date_answer(profile_answer)
    answer_text = profile_answer.is_a?(ProfileAnswer) ? profile_answer.answer_text : profile_answer
    DateTime.localize(Date.parse(answer_text), format: :full_display_no_time) if answer_text.present?
  end

  def fetch_formatted_profile_answers(ref_obj, question, all_answers, is_listing, options = {})
    answer = all_answers[question.id][0] if all_answers[question.id].present?
    answered_question = answer && !answer.unanswered?
    if question.education? && answered_question
      education = get_safe_string
      education_answers = is_listing ? answer.educations[0..(UsersController::MAX_MENTOR_EDU_EXP_IN_INDEX - 1)] : answer.educations
      extra_edu_answers = is_listing ? answer.educations[UsersController::MAX_MENTOR_EDU_EXP_IN_INDEX..-1] : []
      educations = education_answers.map{|edu| formatted_education_in_listing(edu, options)}
      education += render_more_less_rows(educations, DEFAULT_TRUNCATION_ROWS_LIMIT, :divider => "")
      if extra_edu_answers.present?
        education += content_tag(:div, "...")
      end
      education
    elsif question.experience? && answered_question
      experience = get_safe_string
      experience_answers = is_listing ? answer.experiences[0..(UsersController::MAX_MENTOR_EDU_EXP_IN_INDEX - 1)] : answer.experiences
      extra_exp_answers = is_listing ? answer.experiences[UsersController::MAX_MENTOR_EDU_EXP_IN_INDEX..-1] : []
      experiences = experience_answers.map{|exp| formatted_work_experience_in_listing(exp, options)}
      experience += render_more_less_rows(experiences, DEFAULT_TRUNCATION_ROWS_LIMIT, :divider => "")
      if extra_exp_answers.present?
        experience += content_tag(:div, "...")
      end
      experience
    elsif question.publication? && answered_question
      publication = get_safe_string
      publication_answers = is_listing ? answer.publications[0..(UsersController::MAX_MENTOR_EDU_EXP_IN_INDEX - 1)] : answer.publications
      extra_publication_answers = is_listing ? answer.publications[UsersController::MAX_MENTOR_EDU_EXP_IN_INDEX..-1] : []
      publications = publication_answers.map{|pub| formatted_publication_in_listing(pub, is_listing, options)}
      publication += render_more_less_rows(publications, DEFAULT_TRUNCATION_ROWS_LIMIT, :divider => "")
      if extra_publication_answers.present?
        publication += content_tag(:div, "...")
      end
      publication
    elsif question.manager? && answered_question
      formatted_manager_in_listing(answer.manager)
    elsif question.email_type?
      ref_obj ? sanitize(auto_link(ref_obj.email)) : formatted_profile_answer(nil, nil)
    elsif question.name_type?
      ref_obj ? sanitize(ref_obj.name) : formatted_profile_answer(nil, nil)
    elsif question.file_type?
      handle_file_type_answer(answer, is_listing)
    elsif question.skype_id_type? && answered_question
      append_text_to_icon("fa fa-skype", answer.answer_text)
    else
      formatted_profile_answer(answer, question, options)
    end
  end

  def fetch_highlighted_answers(answer, answer_collection, options = {})
    options.reverse_merge!(highlight: true)
    is_text_or_string = is_chronus_string_or_text(options[:question_type], options[:other_question].try(:question_type))
    answers = is_text_or_string ? answer.split(/\s+/) : [answer]
    output_string = [get_safe_string]
    answers.each do |ans|
      if options[:highlight] && (answer_collection.present? && answer_collection.flatten.include?(ans.try(:remove_braces_and_downcase)))
        output_string << content_tag(:strong, ans, class: options[:class])
      else
        output_string << ans
      end
    end
    safe_join(output_string, get_safe_string(is_text_or_string ? "&nbsp;" : ""))
  end

  def is_chronus_string_or_text(question_type, other_question_type)
    return unless question_type.present?
    [RoleQuestion::MatchType::MATCH_TYPE_FOR_QUESTION_TYPE[question_type], RoleQuestion::MatchType::MATCH_TYPE_FOR_QUESTION_TYPE[other_question_type]].all? {|q| [Matching::ChronusString, Matching::ChronusText].include?(q)}
  end

  # Renders the appropriate field edit control for a given common_answer
  #
  # Type | Control
  # ------------------------------------+--------------------------------------
  # String | Text field
  # Text | Text area
  # SingleChoice | Combox
  # MultiChoice | Set of checkboxes
  # File | File field
  #
  # The helpers generate controls with the name: <answer_prefix>[<question-id>].
  # So, in the update method, these fields are received as an common_answers
  # hash as :common_answers
  # => {<question_id> => <common_answer> ...} For multiselect, the value will be an
  # array. Eg. :common_answers => { <multi_choice_question_id> => [ans1, ans2,
  # ...] } Look at UsersController#update to see how the update is handled.
  def edit_profile_answer_field(profile_answer, profile_question, options = {})
    string = get_safe_string
    help_text = fetch_help_text(profile_question)
    is_prof_comp = @is_profile_completion || false
    onchange_content = "CustomizeProfileQuestions.toggleDependentQuestionsInputField('.cjs_dependent_#{profile_question.id}', '.cjs_question_#{profile_question.id}', #{is_prof_comp});"
    string +=
    case profile_question.question_type
    when ProfileQuestion::Type::STRING
      edit_string_field_profile_answer(profile_answer)
    when ProfileQuestion::Type::MULTI_STRING
      edit_multi_string_field_profile_answer(profile_answer, profile_question)
    when ProfileQuestion::Type::TEXT
      edit_text_field_profile_answer(profile_answer)
    when ProfileQuestion::Type::SINGLE_CHOICE
      edit_single_choice_profile_answer(profile_answer, profile_question, onchange_content)
    when ProfileQuestion::Type::MULTI_CHOICE
      edit_multi_choice_profile_answer(profile_answer, profile_question, onchange_content)
    when ProfileQuestion::Type::LOCATION
      edit_location_profile_answer(profile_answer)
    when ProfileQuestion::Type::RATING_SCALE
      edit_rating_scale_profile_answer(profile_answer, profile_question, onchange_content)
    when ProfileQuestion::Type::FILE
      edit_file_profile_answer(profile_answer, options)
    when ProfileQuestion::Type::SKYPE_ID
      edit_string_field_profile_answer(profile_answer)
    when ProfileQuestion::Type::ORDERED_OPTIONS
      edit_ordered_options_profile_answer(profile_answer, profile_question, onchange_content)
    when ProfileQuestion::Type::DATE
      edit_date_field_profile_answer(profile_answer)
    end
    if [ProfileQuestion::Type::MULTI_STRING, ProfileQuestion::Type::STRING].include?(profile_question.question_type)
      string += content_tag(:span, "", :class => 'help-block')
      string = content_tag(:div, string)
    end
    unless profile_question.question_type == ProfileQuestion::Type::MULTI_STRING
      string += chronus_auto_link(help_text)
    end
    string
  end

  def edit_date_field_profile_answer(profile_answer, options = {})
    ans_text = format_date_answer(profile_answer)
    id = options[:id] || "profile_answers_#{profile_answer.profile_question_id}"
    name = options[:name] || "profile_answers[#{profile_answer.profile_question_id}]"
    init_js = javascript_tag("jQuery(function () { initialize.setDatePicker(); });")
    construct_input_group([ { type: "addon", icon_class: "fa fa-calendar" } ], [], {:input_group_class => "m-b-xs"}) do
      text_field_tag(name, ans_text, wrapper: :datepicker_input, id: id, class: "form-control #{options[:class]}", data: date_picker_options) 
    end + init_js
  end

  def edit_string_field_profile_answer(profile_answer)
    text_field_tag("profile_answers[#{profile_answer.profile_question_id}]", profile_answer.answer_text, :id => "profile_answers_#{profile_answer.profile_question_id}",
     :class => "form-control")
  end

  def edit_multi_string_field_profile_answer(profile_answer, profile_question)
    q_id = profile_answer.profile_question_id
    control_name = "profile_answers[#{q_id}][]"
    user_profile_answers = profile_answer.answer_value(profile_question) || []
    input_id = "profile_answers_#{q_id}_"

    string = get_safe_string
    string += label_tag(control_name, profile_question.question_text, :for => "#{input_id}", :class => "sr-only")
    string += content_tag('div', :id => "profile_answers_#{q_id}", :class => "multi_line") do
      if user_profile_answers.empty?
        sub_string = content_tag(:div, text_field_tag(control_name, '', :class => 'textinput form-control', :id => "#{input_id}"), :class => "m-b")
      else
        sub_string = content_tag(:div, text_field_tag(control_name, user_profile_answers[0], :class => 'textinput form-control', :id => "#{input_id}"), :class => "m-b")
        user_profile_answers[1..-1].each do |ans|
          sub_string += javascript_tag("jQuery(function(){MultiLineAnswer.addAnswer(jQuery('#add_new_#{q_id}'), '#{control_name}', '#{ans}', '#{j "feature.common_questions.content.provide_another_answer".translate}', '#{input_id}');})")
        end
      end
      if profile_question.help_text.blank?
        sub_string += link_to_function(embed_icon('fa fa-plus-circle', "display_string.Add_more".translate), "MultiLineAnswer.addAnswer(this, '#{control_name}', null, '#{"feature.common_questions.content.provide_another_answer".translate}', '#{input_id}')", :class => "block", :id => "add_new_#{q_id}")
      else
        sub_string += help_text_content(profile_question.help_text.html_safe, q_id)
        sub_string += link_to_function(embed_icon('fa fa-plus-circle', "display_string.Add_more".translate), "MultiLineAnswer.addAnswer(jQuery('#question_help_text_#{q_id}'), '#{control_name}', null, '#{"feature.common_questions.content.provide_another_answer".translate}', '#{input_id}')", :class => "block", :id => "add_new_#{q_id}")
      end
      sub_string
    end

  end

  def edit_text_field_profile_answer(profile_answer)
    text_area_tag("profile_answers[#{profile_answer.profile_question_id}]", profile_answer.answer_text, :id => "profile_answers_#{profile_answer.profile_question_id}",
    :class => "form-control", :rows => 4)
  end

  def edit_single_choice_profile_answer(profile_answer, profile_question, onchange_content = "")
    answer_choices = profile_question.default_choices
    default_answer = profile_answer.selected_choices(profile_question, default_choices: true)[0]
    other_text = profile_answer.selected_choices(profile_question, other_choices: true)[0]
    other_value = other_text.blank? ? "other" : other_text
    selected_or_not = other_text.blank? ? false : "display_string.selected".translate
    control_name = "profile_answers[#{profile_answer.profile_question_id}]"
    options = content_tag(:option, "common_text.prompt_text.Select".translate, value: "")
    options += options_from_collection_for_select(answer_choices, "to_s", "to_s", default_answer)
    options += content_tag(:option, "common_text.prompt_text.Other_prompt".translate, value: "#{other_value}", selected: selected_or_not, class: "other") if profile_question.allow_other_option?
    above_class = "form-control m-b cjs_expand_contract"
    onchange_content = "CustomizeQuestions.editOtherOptionSingleChoice(#{profile_answer.profile_question_id});" + onchange_content
    str = select_tag(control_name, options, id: "profile_answers_#{profile_answer.profile_question_id}", class: above_class,
      onchange: onchange_content)
    str << edit_other_option_type(profile_answer, false, other_text, true) if profile_question.allow_other_option?
    content_tag(:div, str, class: "clearfix")
  end

  def edit_multi_choice_profile_answer(profile_answer, profile_question, onclick_content)
    find_select_str = dynamic_text_filter_box(
                          "find_and_select_#{profile_answer.profile_question_id}",
                          "find_profile_answer_#{profile_answer.profile_question_id}",
                          "MultiSelectAnswerSelector",
                          {handler_argument: "profile_answers_#{profile_answer.profile_question_id}",
                          filter_box_additional_class: "no-padding m-t-0"
                          })

    # Values for this field should be parsed as an array
    control_name = "profile_answers[#{profile_answer.profile_question_id}][]"
    default_question_choices = profile_question.default_choice_records
    answered_qc_ids = profile_answer.answer_choices.collect(&:question_choice_id)
    default_answer_qc_ids = default_question_choices.collect(&:id) & answered_qc_ids
    str = get_safe_string
    default_question_choices.collect{|qc| [qc.id, qc.text]}.each do |qc_id, choice|
      r_id = escape_javascript("profile_answers_#{profile_answer.profile_question_id}_#{choice}_container".to_html_id)
      str << content_tag(:label, class: 'checkbox cjs_quicksearch_item', id: r_id) do
        # JS observer to select a check box on clicking on a corresponding label is handled at *MultiSelectAnswerSelector()*
        check_box_tag(control_name, choice, default_answer_qc_ids.include?(qc_id),
          id: "profile_answers_#{profile_answer.profile_question_id}_#{choice}".to_html_id,
          onclick: onclick_content,
          class: "multi_select_check_box") +
            content_tag(:span, choice, class: "multi_select_label", id: escape_javascript("profile_answers_label_#{profile_answer.profile_question_id}_#{choice}".to_html_id))
      end
    end

    if profile_question.allow_other_option?
      other_text = profile_answer.selected_choices(profile_question, other_choices: true).join(", ")
      other_value = other_text.blank? ? "other" : other_text
      is_prof_comp = @is_profile_completion || false
      str << content_tag('div', class: "clearfix cjs_quicksearch_item m-b-sm") do
          label = content_tag(:label, class: "checkbox pull-left m-r-xs", id: "profile_answers_#{profile_answer.profile_question_id}_other_container") do
            content_tag("input", type: 'checkbox', class: 'multi_select_check_box', id: "profile_answers_#{profile_answer.profile_question_id}_other",
            value: other_value, checked: other_text.present?, name: control_name, onclick: "CustomizeQuestions.editOtherOptionMultiChoice(#{profile_answer.profile_question_id});
             CustomizeProfileQuestions.toggleDependentQuestionsInputField('.cjs_dependent_#{profile_question.id}', '.cjs_question_#{profile_question.id}', #{is_prof_comp});") do
            "common_text.prompt_text.Other_prompt".translate
          end
        end
        hidden_mirror = content_tag(:span, other_text, class: "hide", id: "quicksearch_other_mirror_#{profile_answer.profile_question_id}")
        other_input = edit_other_option_type(profile_answer, true, other_text,true, false, -1, {div_class: "m-l-xs"})
        label + hidden_mirror + other_input
      end
    end

    str << hidden_field_tag(control_name) # This is required in the case the user de-selects all the choices, so that an empty array is returned

    find_select_script = javascript_tag( %Q[
        QuicksearchBox.initializeWithOther(
                  '#quick_find_profile_answer_#{profile_answer.profile_question_id}',
                  '#profile_answers_#{profile_answer.profile_question_id}',
                  '#profile_answers_#{profile_answer.profile_question_id}_other',
                  '#other_option_#{profile_answer.profile_question_id} input',
                  '#quicksearch_other_mirror_#{profile_answer.profile_question_id}');
      ])
    scroll_required = default_question_choices.size > MUTLI_CHOICE_TYPE_OPTIONS_LIMIT
    well_class = "well white-bg clearfix m-b-0"
    content = choices_wrapper("display_string.Choices".translate, class: "col-xs-12 no-padding") do
      content_tag(:div, str, id: "profile_answers_#{profile_answer.profile_question_id}", data: {slim_scroll: scroll_required})
    end
    scroll_required ? (content_tag(:div, (find_select_str + content + find_select_script), class: well_class) + javascript_tag("initialize.setSlimScroll()")) : content_tag(:div, content, class: well_class)
  end

  def edit_location_profile_answer(profile_answer)
    control_name = "profile_answers[#{profile_answer.profile_question_id}]"
    location_autocomplete(profile_answer, :answer_text, profile_answer.location.nil?, {:name => control_name, :value => profile_answer.answer_text, :id => "profile_answers_#{profile_answer.profile_question_id}", :class => "form-control"}, {})
  end

  def edit_rating_scale_profile_answer(profile_answer, profile_question, onclick_content="")
    str = get_safe_string

    # Values for this field should be parsed as an array
    control_name = "profile_answers[#{profile_answer.profile_question_id}]"
    user_profile_answers = profile_answer.answer_value(profile_question) || []

    profile_question.default_choices.each do |choice|
      # Another dummy wrapper to make the HTML markup similar to that of other
      # choice type questions. This is done in order to reuse the JS validation.
      str << content_tag(:div, :class => 'choice_wrapper') do
        radio_button_tag(control_name, choice, user_profile_answers.include?(choice),
          :id => "profile_answers_#{profile_answer.profile_question_id}_#{choice}".to_html_id, :onclick => onclick_content) +
            content_tag(:span) { choice }
      end
    end

    content_tag(:div, str, :class => 'ratings_wrapper clearfix', :id => "profile_answers_#{profile_answer.profile_question_id}")
  end

  # Customization fields for question of type <i>ProfileQuestion::Type::FILE</i>
  def edit_file_profile_answer(profile_answer, options = {})
    profile_question = profile_answer.profile_question
    file_field_wrapper_id = "file-field-wrapper-#{profile_answer.profile_question_id}".to_html_id
    form_path = upload_answer_file_member_path((profile_answer.ref_obj.nil? || profile_answer.ref_obj.new_record?) ? :new : profile_answer.ref_obj, format: :js)
    init_js = javascript_tag("jQuery(function () { jQuery('##{file_field_wrapper_id}').initFileUploader('#{form_path}'); });")
    file_field_params = {
      id: "profile_answers_#{profile_answer.profile_question_id}",
      class: "ajax-file-uploader",
      data: {
        question_id: profile_answer.profile_question_id,
        section_id: options[:section_id] || profile_question.section_id
      }
    }
    upload_tag = file_field_tag("profile_answers[#{profile_answer.profile_question_id}]", file_field_params)
    content_tag(:div, id: file_field_wrapper_id, class: "cjs_file_field_wrapper") do
      if profile_answer.present? && profile_answer.persisted? && !profile_answer.unanswered? && profile_answer.valid?
        program = options[:program].presence || @current_program
        role_names = options[:user].try(:role_names) || @roles
        delete_allowed = options[:delete_allowed] || !profile_question.required_for(program, role_names)
        label_text = profile_answer.attachment_file_name
        delete_box = content_tag(:small, delete_check_box(profile_answer, delete_allowed), :class => 'ans_file')
        current_file_label = content_tag(:label,
          get_safe_string + label_text + delete_box,
          :class => 'checkbox',
          :for => "delete_check_box_#{profile_answer.profile_question_id}".to_html_id,
          :id => "file_container_#{profile_answer.profile_question_id}")
        current_file_div = content_tag(:div, upload_tag,
          :id => "edit_profile_upload_toggle_profile_answers_#{profile_answer.profile_question_id}",
          :class => "cjs_edit_file_upload_toggle",
          :style => "display:none")
        (get_safe_string + current_file_label + current_file_div)
      else
        upload_tag
      end
    end + init_js
  end

  def edit_ordered_options_profile_answer(profile_answer, profile_question, onchange_content="")
    pq = profile_question || profile_answer.profile_question
    all_answered_qc_ids = profile_answer.answer_choices.collect(&:question_choice_id)
    default_choices = pq.default_choice_records
    default_answered_qc_ids = default_choices.collect(&:id) & all_answered_qc_ids
    other_answered_qc_ids = all_answered_qc_ids - default_choices.collect(&:id)
    qc_choices_hash = pq.question_choices.index_by(&:id)
    answer_choices = default_choices.collect(&:text)
    str = "<ol class = 'p-l-xs'>".html_safe
    pq.options_count.times do |option|
      onchange_content_full = onchange_content + "CustomizeQuestions.handleOrderedSelectChange(this, #{pq.id}, #{option}, #{pq.section.id.to_s} );"
      ans_qc_id = all_answered_qc_ids[option] if default_answered_qc_ids.include?(all_answered_qc_ids[option])
      ans = (qc_choices_hash[ans_qc_id] && qc_choices_hash[ans_qc_id].text) || ""
      other_qc_id = all_answered_qc_ids[option] if other_answered_qc_ids.include?(all_answered_qc_ids[option])
      other_text = qc_choices_hash[other_qc_id].text if other_qc_id && qc_choices_hash[other_qc_id]
      other_value = other_text.blank? ? "other" : other_text
      selected_or_not = other_text.blank? ? false : "selected"
      options = content_tag(:option, "common_text.prompt_text.Select".translate, value: "")
      options += options_from_collection_for_select(answer_choices, "to_s", "to_s", {selected: ans })
      options += content_tag(:option, "common_text.prompt_text.Other_prompt".translate, value: other_value, selected: selected_or_not, class: "other") if pq.allow_other_option?
      above_class = (option == 0) ? "" : "m-t-sm"
      select_class = selected_or_not ? " m-r-xs" : ""
      control_name = "profile_answers[#{pq.id}][#{option}]"
      str << content_tag(:li, class: above_class) do
        substr = label_tag(control_name, "feature.common_questions.content.ordered_choice_label".translate(preference: option+1), for: "profile_answers_#{pq.id}_#{option}", class: "sr-only") +
                 select_tag(control_name, options, id: "profile_answers_#{pq.id}_#{option}", class: "cjs_ordered_option cjs_expand_contract form-control inline #{select_class}", onchange: onchange_content_full)
        substr << edit_other_option_type(profile_answer, false, other_text, true, true, option) if pq.allow_other_option?
        content_tag(:div, substr, class: "inline")
      end
    end
    str << "</ol>".html_safe
    str
  end

  def handle_file_type_answer(profile_answer, is_listing)
    return content_tag(:i, 'display_string.not_applicable'.translate, :class => "dim") if profile_answer.present? && profile_answer.not_applicable?
    return content_tag(:i, 'common_text.Not_Specified'.translate, :class => "dim") if profile_answer.nil? || profile_answer.unanswered?
    attachment = profile_answer.attachment
    file_text = get_safe_string
    ans_text = content_tag(:i, nil, class: "fa fa-paperclip m-r-xs") + profile_answer.attachment_file_name +
      content_tag(:span, ' ('.html_safe + link_to('display_string.download'.translate, attachment.url, :target => "_blank", :class => 'cjs_android_download_files', :data => {:filename => profile_answer.attachment_file_name, :targeturl => attachment.url}) + ')'.html_safe, {:class => 'dim small'}, false)
    file_text << auto_link(ans_text.html_safe)
    file_text
  end

  def delete_check_box(profile_answer, delete_allowed)
    check_box("persisted_files", profile_answer.profile_question_id, {
      id: "delete_check_box_#{profile_answer.profile_question_id}".to_html_id,
      class: 'cjs_delete_file_link',
      checked: true,
      data: {
        section_id: profile_answer.profile_question.section_id,
        question_id: profile_answer.profile_question_id,
        delete_allowed: delete_allowed
      }
    })
  end

  def fetch_help_text(profile_question)
    return unless profile_question.present?

    if profile_question.help_text.present?
      help_text = help_text_content(chronus_sanitize_while_render(profile_question.help_text), profile_question.id)
    else
      help_text = get_safe_string
    end
  end
end
