module ProfileQuestionsHelper

  DATE_RANGE_PICKER_FOR_PROFILE_QUESTION = "cjs_date_picker_for_profile_question"
  DATE_VALUE = "date_value"
  NUMBER_OF_DAYS = "number_of_days"

  def common_question_string_type_tooltip_text
    "feature.profile_customization.content.common_question_string_type_tooltip_text".translate
  end

  def common_question_single_choice_type_tooltip_text
    "feature.profile_customization.content.common_question_single_choice_type_tooltip_text".translate
  end

  def profile_question_education_type_tooltip_text
    "feature.profile_customization.content.profile_question_education_type_tooltip_text".translate
  end

  def profile_question_experience_type_tooltip_text
    "feature.profile_customization.content.profile_question_experience_type_tooltip_text".translate
  end

  def profile_question_publication_type_tooltip_text
    "feature.profile_customization.content.profile_question_publication_type_tooltip_text".translate
  end

  def profile_questions_helper_tooltip_text
    {
      CommonQuestion::Type::STRING => common_question_string_type_tooltip_text,
      CommonQuestion::Type::SINGLE_CHOICE => common_question_single_choice_type_tooltip_text,
      ProfileQuestion::Type::EDUCATION => profile_question_education_type_tooltip_text,
      ProfileQuestion::Type::EXPERIENCE => profile_question_experience_type_tooltip_text,
      ProfileQuestion::Type::PUBLICATION => profile_question_publication_type_tooltip_text
    }
  end

  def show_profile_question_multi_choice(question, disabled_for_editing = false)
    id_used = get_default_question_id(question)
    question_type = question.is_a?(ProfileQuestion) ? "profile" : "common"
    return get_profile_question_choices_list(question) if disabled_for_editing
    selects = get_question_choices_well(question, disabled_for_editing, id_used)
    modal_box_code = render(partial: "profile_questions/question_choice_bulk_add", locals: {id_used: id_used, disabled_for_editing: disabled_for_editing, question_type: question_type})

    content_tag(:div, (selects + modal_box_code).html_safe, id: "#{question_type}_question_multi_choice_#{question.id}")
  end

  def preview_description_box(options = {})
    ibox { preview_description_text(options) } if options[:filter_role].present?
  end

  def preview_description_text(options = {})
    return "" if options[:filter_role_ids].blank?
    roles_by_id, viewer_role_ids = preview_description_text_base_data(options)
    viewer_roles_str = preview_description_text_ary_of_roles(viewer_role_ids, roles_by_id)
    roles_str = preview_description_text_ary_of_roles(options[:filter_role_ids], roles_by_id)
    [preview_description_text_key(options).translate(viewer_roles: viewer_roles_str, roles: roles_str), "feature.profile_customization.content.user_profile_preview_description".translate].join(" ")
  end

  def preview_and_edit_profile_question(profile_question, all_questions=[])
    if(profile_question.default_type?)
      add_class = ' disabled_no_drop '
      bar_class = 'cursor-no-drop text-muted'
    else
      add_class = ' draggable'
      bar_class = 'cursor-move'
    end
    q_id = profile_question.id
    content = embed_icon(bar_class)

    content_tag(:li, :id => "profile_question_#{q_id}",
      :class => ('question_answer animated fadeInDown z-index-not-important list-group-item' + add_class)) do
      render('profile_questions/preview_question', :profile_question => profile_question, :section => profile_question.section, :profile_ques => true, :all_questions =>all_questions, :draggable_icon => content)
    end
  end

  def condition_profile_questions_container_box(question, profile_questions)
    q_id = question.id || 0
    content_tag(:div) do
      label_tag("profile_question[conditional_question_id]", "feature.profile_question.label.select_question".translate, :for => "profile_question_#{q_id}_conditional_question_id", :class => 'sr-only') +
      label_tag("profile_question[conditional_match_text]", "feature.profile_question.label.matching_response".translate, :for => "profile_question_#{q_id}_conditional_match_text", :class => 'sr-only') +
      get_conditional_select_list(question, profile_questions) +
      content_tag(:div, "#{'feature.profile_customization.content.conditional_list_contains_reponse_html_v1'.translate} ", class: "pull-left m-t-sm p-xxs col-xs-12 cjs_conditional_response_text m-b-xs p-l-0") + 
      content_tag(:div, "", class: "cjs_conditional_question_select_container")
    end
  end

  def get_conditional_select_list(question, profile_questions)
    q_id = question.id || 0
    profile_questions -= [question]
    content_tag(:div, class: "col-xs-12 no-padding m-t-xs m-r-xs") do
      select_tag("profile_question[conditional_question_id]",
        options_for_select([["common_text.prompt_text.Select".translate, ""]] + profile_questions.collect{|pq| [pq.question_text, pq.id]}, question.conditional_question_id), :id => "profile_question_#{q_id}_conditional_question_id", :class => "cjs_expand_contract form-control cjs_select_conditional_question", title: "feature.profile_customization.label.conditional".translate)
    end
  end

  def header_for_profile_questions(section)
    content_tag(:div, id: "profile_section_header_#{section.id}",
      class: 'profile_section_header p-b-xs b-b clearfix') do
      render(partial: 'profile_questions/profile_questions_header')
    end
  end

  def get_role_listing(organization, profile_question)
    string = content_tag('div', :class => "roles_wrapper") do
      substring = get_safe_string
      roles = profile_question.role_questions.collect(&:role)
      organization.programs.ordered.each do |program|
        prog_roles = ((roles & program.roles) || []).group_by(&:name)
        if prog_roles.keys.size != 0
          substring << content_tag(:div, class: "p-t-xxs") do
            content_tag(:b , h(program.name)) +
            content_tag(:ul, prog_roles.values.flatten.collect{|role| content_tag('li', role.customized_term.term, class: '')}.inject(:+), :class => "list-group")
          end
        end
      end
      substring
    end
  end

  def get_role_listing_program_view(program_id, profile_question)
    # Program object is re-fetched here (instead of using @current_program) to account for newly created/destroyed role questions of the program.
    program = Program.find_by(id: program_id)
    role_string = "-"
    role_questions = (profile_question.role_questions & program.role_questions)
    role_string = RoleConstants.human_role_string(role_questions.collect(&:role).collect(&:name), program: program)
    role_string = "-" if role_string.blank?
    return role_string
  end

  # Renders a preview of how the question will be presented to users.
  def preview_profile_question(profile_question, options = {})
    required = options[:required]
    string = get_safe_string
    unless profile_question.help_text.blank?
      help_text = help_text_content(profile_question.help_text.html_safe, profile_question.id)
    else
      help_text = help_text_content(nil,profile_question.id)
    end
    onchange_content = profile_question.has_dependent_questions? ? "CustomizeProfileQuestions.toggleDependentQuestionsInputField('.cjs_dependent_#{profile_question.id}', '.cjs_question_#{profile_question.id}', false);" : ""
    case profile_question.question_type
    when ProfileQuestion::Type::STRING
      string += text_field_tag "preview_#{profile_question.id}", '', :class => 'textinput form-control', :id => "preview_#{profile_question.id}"
    when ProfileQuestion::Type::DATE
      string += edit_date_field_profile_answer("", {id: "preview_#{profile_question.id}", name: "preview_#{profile_question.id}"})
    when ProfileQuestion::Type::EMAIL
      string += text_field_tag "preview_#{profile_question.id}", '', :class => 'textinput form-control', :id => "preview_#{profile_question.id}"
    when ProfileQuestion::Type::LOCATION
      string += text_field_tag "preview_#{profile_question.id}", '', :class => 'textinput form-control', :id => "preview_#{profile_question.id}"
    when ProfileQuestion::Type::SKYPE_ID
      string += text_field_tag "preview_#{profile_question.id}", '', :class => 'textinput form-control', :id => "preview_#{profile_question.id}"
    when ProfileQuestion::Type::TEXT
      string += text_area_tag "preview_#{profile_question.id}", '', :class => 'form-control', :rows => 4, :id => "preview_#{profile_question.id}"
    when ProfileQuestion::Type::SINGLE_CHOICE
      string += preview_of_single_choice(profile_question, onchange_content)
      string += preview_other_option(profile_question) if profile_question.allow_other_option?
    when ProfileQuestion::Type::MULTI_CHOICE
      profile_choices = profile_question.default_choices
      find_select_str = dynamic_text_filter_box("find_and_select_#{profile_question.id}",
        "find_profile_answer_#{profile_question.id}",
        "MultiSelectAnswerSelector",
        {:handler_argument => "preview_#{profile_question.id}",
          :filter_box_additional_class => "no-padding"})

      substring = "".html_safe
      profile_choices.each do |value|
        substring << content_tag('div', :class => "clearfix cjs_quicksearch_item") do
          content_tag(:label, :class => 'checkbox')  do
            check_box_tag(nil, value, false, onclick: onchange_content, class: 'multi_select_check_box', id: "preview_#{profile_question.id}_#{value}".to_html_id) + value
          end
        end
      end
      if profile_question.allow_other_option?
        substring << content_tag('div', :class => "clearfix cjs_quicksearch_item") do
          label = content_tag(:label, :class => 'checkbox')  do
            check_box_tag(nil, 'other', false, :class => 'multi_select_check_box', :id => "select_#{profile_question.id}_other",
              :onclick => "CustomizeQuestions.editMultiChoice('select_', #{profile_question.id});
              CustomizeProfileQuestions.toggleDependentQuestionsInputField('.cjs_dependent_#{profile_question.id}', '.cjs_question_#{profile_question.id}', false)") +
            "common_text.prompt_text.Other_prompt".translate
          end
          hidden_mirror = content_tag(:span, "", :class => "hide", :id => "quicksearch_other_mirror_#{profile_question.id}")
          other_input = preview_other_option(profile_question, true)
          label + hidden_mirror + other_input
        end
      end

      find_select_script = javascript_tag( %Q[
         QuicksearchBox.initializeWithOther(
                    '#quick_find_profile_answer_#{profile_question.id}',
                    '#preview_#{profile_question.id}',
                    '#select_#{profile_question.id}_other',
                    '#other_option_#{profile_question.id} input',
                    '#quicksearch_other_mirror_#{profile_question.id}');
        ])
      scroll_required = profile_choices.size > MUTLI_CHOICE_TYPE_OPTIONS_LIMIT
      scroll_script = scroll_required ? javascript_tag("initialize.setSlimScroll()") : ""
      content = choices_wrapper("display_string.Choices".translate, class: "col-xs-12 no-padding") do
        content_tag(:div, substring, :data => {:slim_scroll => scroll_required}, :id => "")
      end
      well_class = "p-t-xxs choices_wrapper well white-bg clearfix"
      content_string = scroll_required ? content_tag(:div, (find_select_str + content + find_select_script), :class => well_class, :id => "preview_#{profile_question.id}") + scroll_script : content_tag(:div, content, :class => well_class, :id => "preview_#{profile_question.id}") + scroll_script

      string += content_tag('div', content_string, :class => 'multi_select_preview')

    when ProfileQuestion::Type::RATING_SCALE
      string += content_tag('div', :class => "ratings_wrapper") do
        substring = ""
        profile_question.default_choices.each do |value|
          substring << radio_button_tag("rating_#{value}", "", :onclick => onchange_content) +
            content_tag(:span, value)
        end
        substring
      end

    when ProfileQuestion::Type::FILE
      string += file_field_tag "preview_#{profile_question.id}"
    when ProfileQuestion::Type::MULTI_STRING
      string += label_tag("multi_line[]", profile_question.question_text, :for => "preview_#{profile_question.id}", :class => "sr-only")
      string += content_tag('div', :id => "preview_container_#{profile_question.id}", :class => "multi_line") do
        sub_string = text_field_tag "multi_line[]", '', :class => 'textinput form-control', :onchange => onchange_content, :id => "preview_#{profile_question.id}"
        sub_string += help_text
        sub_string += link_to_function(embed_icon('fa fa-plus-circle',"display_string.Add_more".translate), "MultiLineAnswer.addAnswer(jQuery('#question_help_text_#{profile_question.id}'), 'multi_line[]', null, '#{"feature.common_questions.content.provide_another_answer".translate}', '#question_help_text_#{profile_question.id}_')", :class => "help-block")
        sub_string
      end
    when ProfileQuestion::Type::EDUCATION
      string += content_tag('div', render(:partial => "educations/new_education", :object => Education.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section panel-body", :id => "edu_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
    when ProfileQuestion::Type::MULTI_EDUCATION
      string += content_tag(:div, "feature.education_and_experience.label.no_education_specified".translate, class: "text-center hide cjs_empty_message p-sm") + content_tag('div', render(:partial => "educations/new_education", :object => Education.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section  panel-body list-group p-l-xs p-r-xs", :id => "edu_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
      string += content_tag('div', add_education_link(profile_question, embed_icon('fa fa-plus-circle m-r-xs', "feature.education_and_experience.action.add_degree_v1".translate), {:required => required, :link_class => "pull-right"}), :class => "panel-footer clearfix m-t-sm")
    when ProfileQuestion::Type::EXPERIENCE
      string += content_tag('div', render(:partial => "experiences/new_experience", :object => Experience.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section  panel-body", :id => "exp_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
    when ProfileQuestion::Type::MULTI_EXPERIENCE
      string += content_tag(:div, "feature.education_and_experience.label.no_experience_specified".translate, class: "text-center hide cjs_empty_message p-sm") + content_tag('div', render(:partial => "experiences/new_experience", :object => Experience.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section  panel-body list-group p-l-xs p-r-xs", :id => "exp_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
      string += content_tag('div', add_experience_link(profile_question, embed_icon('fa fa-plus-circle m-r-xs',"feature.education_and_experience.action.add_position_v1".translate), {:required => required, :link_class => "pull-right"}), :class => "panel-footer clearfix m-t-sm")
    when ProfileQuestion::Type::PUBLICATION
      string += content_tag('div', render(:partial => "publications/new_publication", :object => Publication.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section  panel-body", :id => "publication_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
    when ProfileQuestion::Type::MULTI_PUBLICATION
      string += content_tag(:div, "feature.education_and_experience.label.no_publication_specified".translate, class: "text-center hide cjs_empty_message p-sm") + content_tag('div', render(:partial => "publications/new_publication", :object => Publication.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section panel-body list-group p-l-xs p-r-xs", :id => "publication_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
      string += content_tag('div', add_publication_link(profile_question, embed_icon('fa fa-plus-circle m-r-xs',"feature.education_and_experience.action.add_publication_v1".translate), {:required => required, :link_class => "pull-right"}), :class => "panel-footer clearfix m-t-sm")
    when ProfileQuestion::Type::MANAGER
      string += content_tag('div', render(:partial => "managers/new_manager", :object => Manager.new, :locals => {:question => profile_question, :required => required}), :class => "preview_inner_rounded_section edit_manager  panel-body", :id => "manager_cur_list_#{profile_question.id}")
      unless profile_question.help_text.blank?
        string += content_tag(:div, help_text, class: "m-t-xs b-t p-l-sm")
      else
        string += help_text
      end
    when ProfileQuestion::Type::ORDERED_OPTIONS
        string += "<ol>".html_safe
        options_count = profile_question.options_count
        options_count.times do |option|
          above_class = (option == 0) ? "" : "m-t-xs"
          string += content_tag(:li) do
            options = content_tag(:option, "common_text.prompt_text.Select".translate, :value => "")
            options += options_from_collection_for_select(profile_question.default_choices, "to_s", "to_s")
            options += content_tag(:option, "common_text.prompt_text.Other_prompt".translate, :value => "other") if profile_question.allow_other_option?
            content_tag(:div, :class => "#{above_class} inline") do
              onchange_content_full = onchange_content + "CustomizeProfileQuestions.disableSelectedOptions(this, 'select');CustomizeQuestions.editOrderedOptionsChoice(#{profile_question.id}, #{option})"
              substring = label_tag(profile_question.question_text, "feature.common_questions.content.ordered_choice_label".translate(preference: option+1), :for => "profile_answers_#{profile_question.id}_#{option}", :class => "sr-only") +
              select_tag(profile_question.question_text, options , :class => "form-control cjs_expand_contract inline",
                :id => "profile_answers_#{profile_question.id}_#{option}", :onchange => onchange_content_full)
              if profile_question.allow_other_option?
                substring += content_tag(:span, :id => "other_option_#{profile_question.id}_#{option}", :class => "hide #{above_class}") do
                  label_tag("preview_#{profile_question.id}_#{option}", "feature.profile_question.label.other_option".translate, :class => "sr-only") +
                  text_field_tag("preview_#{profile_question.id}_#{option}", '', :class => 'textinput form-control', :placeholder => 'common_text.placeholder.please_specify_reason'.translate, :onchange => onchange_content)
                end
              end
              substring
            end
          end
        end
        string += "</ol>".html_safe
      string
    end

    unless (profile_question.education? || profile_question.experience? || profile_question.publication? || profile_question.manager? || profile_question.question_type == ProfileQuestion::Type::MULTI_STRING)
      string += help_text
    end
    return string
  end

  def compressed_question_type(profile_question, options = {})
    string = get_safe_string
    profile_question = profile_question.is_a?(RoleQuestion) ? profile_question.profile_question : profile_question
    class_type = get_question_type(profile_question.question_type)
    ques_type_array = get_profile_question_type_options_array(true, profile_question.email_type?, profile_question.name_type?, @current_organization.manager_enabled?).select do |q|
      q[1] == class_type
    end

    ques_type_text = ques_type_array.first[0]
    return chronus_auto_link(ques_type_text) if options[:text_only]
    string += content_tag(:div, :class => "col-sm-6 no-padding profile_question_span") do
      ques_type_text
    end

    return chronus_auto_link(string)
  end

  def get_preview_section_content(section, profile_questions = [], options = {})
    is_membership_preview = options[:is_membership_preview] || false
    profile_filter_xhr = options[:profile_filter_xhr].nil? ? true : options[:profile_filter_xhr]
    profile_section_wrapper = content_tag(:div, {:id => "profile_section_#{section.id}"}) do
      section_description = get_section_description(section, class: "m-b", id: "section_description_#{section.id}")
      preview_partial = section_description + (render :partial => "profile_questions/preview_profile_questions", :locals => {:profile_questions => profile_questions[section.id] , :section => section, :membership_preview => is_membership_preview})
      collapsible_content(section.title, [], profile_filter_xhr) do
        preview_partial
      end
    end
    profile_section_wrapper
  end

  def get_section_content(section, profile_questions = [], profile_filter_xhr=true)
    div_id = "profile_section_title_content_#{section.id}"
    ibox_options = {ibox_class: "collapsed", :show_collapse_link => true}
    if section.default_field?
      add_class = 'disabled_no_drop'
      section_title = content_tag(:span, section.title, class: "p-l-md")
    else
      add_class = 'cursor-move'
      section_title = append_text_to_icon( "fa fa-arrows", section.title)
      confirmation_text = "feature.profile_customization.content.delete_section_confirmation_v1".translate
      ibox_options.merge!(:additional_right_links => link_to_function((get_icon_content("fa fa-pencil section_edit_image") + set_screen_reader_only_content("display_string.Edit".translate)), "jQuery('#edit_section_#{section.id}').modal('show')"))
      ibox_options.merge!(:show_delete_link => true, delete_url: section_url(section), delete_html_options: {:method => :delete, :remote => true, :class => "pull-right", data: {:confirm => confirmation_text } })
    end
    title = content_tag(:span, section_title, id: div_id)
    profile_section_wrapper = content_tag(:div, id: "profile_section_#{section.id}", class: add_class) do
      ibox(title, ibox_options) do
        section_description = get_section_description(section, class: "no-margin", id: "section_description_#{section.id}")
        content_tag(:div, section_description + (render :partial => "profile_questions/profile_questions", :locals => {:profile_questions => (section.profile_questions & profile_questions), :section => section, :all_questions => profile_questions}))
      end
    end
    profile_section_wrapper + content_tag(:div, (render :partial => 'sections/edit', :locals => {:section => section}))
  end

  def get_section_title(section, include_edit_option)
    div_id = "profile_section_title_#{section.id}"
    load_image = "add_edit_section_loading_#{section.id}"
    content_div_id = "div.common_questions #profile_section_#{section.id} ##{id_prefix_from_label(section.title)}content"
    confirmation_text = "feature.profile_customization.content.delete_section_confirmation_v1".translate
    on_click_str = "CommonQuestions.toggleArrowAndBlind('#{content_div_id}','#profile_section_#{section.id} .collapsible_header .collapsible_arrow');jQuery('#profile_section_title_wrapper_#{section.id}').closest('.exp_collapse_header').toggleClass('unstacked');"
    pane_title = content_tag :div, :id => "profile_section_title_wrapper_#{section.id}" do
      content_tag :div, :id => div_id do
        content = get_safe_string
        content += image_tag("v3/icons/down_arrow.gif", :class => 'collapsible_arrow pull-right icon-all',
          :onclick => on_click_str) +
          image_tag("v3/icons/up_arrow.gif", :class => 'collapsible_arrow pull-right icon-all',
          :onclick => on_click_str, :style => "display: none")
        content += content_tag(:span, section.title, :onclick => on_click_str,
          :id => "profile_section_title_content_#{section.id}", :class => "has-next" )
        if !section.default_field? && include_edit_option
          content += link_to(embed_icon("icon-pencil section_edit_image"), "javascript_void(0);", :id => "edit_section_#{section.id}") +
            link_to(embed_icon("icon-trash section_delete_image"), section_url(section), :method => :delete,
            :remote => true, data: { :confirm => confirmation_text }) +
            image_tag('ajax-loader.gif', :id => load_image, :style => 'display: none', :class => 'icon-all')
        end
        content
      end
    end
    pane_title
  end

  def get_confirm_mesage_if_dependent_questions(all_questions, profile_question)
    confirm_message = get_safe_string
    dependent_questions = if all_questions.present?
      all_questions.select { |q| q.conditional_question_id && (q.conditional_question_id == profile_question.id) }
    else
      profile_question.dependent_questions
    end
    if dependent_questions.size > 0
      confirm_message += "feature.profile_customization.content.update_delete_confirmation.show_only_if".translate
      confirm_message += content_tag(:ul) do
        content = get_safe_string
        dependent_questions.first(5).each do |question|
          content += content_tag(:li, question.question_text)
        end
        if dependent_questions.size > 5
          content += content_tag(:li, "#{"display_string.and".translate} #{"display_string.more_with_count".translate(count: dependent_questions.size - 5)}")
        end
        content
      end
    end
    confirm_message
  end

  def update_delete_confirmation_template(options = {}, &block)
    content_tag(:div, class: options[:block_class], id: options[:block_id]) do
      content = get_safe_string
      content += options[:base_text]
      content += content_tag(:ol, class: "cjs-update-delete-confirmation-list text-left m-t") do
        capture(&block)
      end
      content += "feature.profile_customization.content.update_delete_confirmation.confirm_text".translate
      content
    end
  end

  def delete_profile_question_confirm_message(all_questions, profile_question)
    dependency_confirmation = get_confirm_mesage_if_dependent_questions(all_questions, profile_question)
    tied_to_matching = profile_question.has_match_configs?(program_view? ? current_program : nil)

    if !(dependency_confirmation.present? || tied_to_matching)
      if program_view? && !@current_organization.standalone?
        return ("feature.profile_customization.content.remove_question_confirmation_line1_v2".translate(program: _program) + " <br/> " + "feature.profile_customization.content.remove_question_confirmation_line2".translate).html_safe
      else
        return ("feature.profile_customization.content.delete_field_confirm_line1".translate + " <br/> " + "feature.profile_customization.content.delete_field_confirm_line2_v2".translate(programs: _programs)).html_safe
      end
    end

    delete_confirmations = get_safe_string
    delete_confirmations += content_tag(:li, dependency_confirmation) if dependency_confirmation.present?
    delete_confirmations += content_tag(:li, "feature.profile_customization.content.update_delete_confirmation.match_score".translate) if tied_to_matching
    delete_confirmations += content_tag(:li, "feature.profile_customization.content.update_delete_confirmation.user_responses_lost".translate)
    delete_confirmations.present? ? update_delete_confirmation_template(base_text: "feature.profile_customization.content.update_delete_confirmation.base_delete_text".translate) { delete_confirmations } : ""
  end

  def get_profile_question_tabs_title(_profile_question, label_string, options = {})
    active_class = options[:active] ? 'ct_active active' : ''
    content_tag(:li, class: "#{active_class} #{options[:class]}") do
      link_to (options[:display_string] || label_string), "#tab_#{label_string}", data: {toggle: 'tab'}
    end
  end

  def get_profile_question_tabs_content(label_string, contents = [], options = {})
    active_class = options[:active] ? 'active' : ''
    content_tag(:div, class: "tab-pane #{active_class} #{options[:class]}", id: "tab_#{label_string}") do
      contents.each do |content|
        concat(construct_tab_pane_content(content[:title], content[:description], options.merge(content[:options].to_h)))
      end
    end
  end

  def view_profile_question_definition_details(profile_question, _options = {})
    definition_contents = []
    definition_contents << {title: "display_string.Name".translate, description: [profile_question.question_text]}
    definition_contents << {title: "display_string.Type".translate, description: [compressed_question_type(profile_question, text_only: true)]}
    definition_contents << {title: "feature.profile_customization.label.field_description".translate, description: [profile_question.help_text.html_safe]} if !profile_question.help_text.blank?
    definition_contents << {title: "feature.profile_question.label.choices".translate, description: [get_profile_question_choices_list(profile_question, {additional_classes: "m-l"})]} if profile_question.select_type?
    update_definition_details_for_conditional_questions!(definition_contents, profile_question)
    definition_contents
  end

  def profile_question_actions(profile_question, options = {})
    content_tag(:div, class: "p-l-xs icons-#{profile_question.id} hide cjs-profile-question-actions pull-right") do
      contents = get_safe_string
      tool_tip_text = profile_question_actions_tooltip_related(profile_question, options) if profile_question.conditional_question_id.present? || profile_question.part_of_sftp_feed?(@current_organization) || options[:program_level].present? || @current_organization.standalone?
      contents += get_profile_question_onclick_actions(profile_question, tool_tip_text, options)
      contents
    end
  end

  def list_of_programs_tooltip(node_id, programs)
    return if programs.blank?
    programs_list = get_safe_string
    programs.each do |program|
      programs_list << content_tag(:li, program.name)
    end
    tooltip(node_id, content_tag(:ul, programs_list, class: "text-left m-l-n-md m-t-sm cjs_no_of_programs_tooltip"), true, placement: "left", container: ".cjs-profile-questions-containing-column")
  end

  def get_multi_tool_tip(options = {})
    tool_tip_text = get_safe_string
    case options[:type]
    when ProfileQuestion::Type::MULTI_EDUCATION
      tool_tip_text += "feature.profile_question.help_text.multi_education_tooltip".translate
    when ProfileQuestion::Type::MULTI_EXPERIENCE
      tool_tip_text += "feature.profile_question.help_text.multi_experience_tooltip".translate
      if @current_organization.linkedin_imports_feature_enabled?
        tool_tip_text += " " + "feature.profile_question.help_text.linkedin_tooltip".translate
      end
    when ProfileQuestion::Type::MULTI_PUBLICATION
      tool_tip_text += "feature.profile_question.help_text.multi_publication_tooltip".translate
    end

    content_tag(:span, class: "m-t-xs text-muted help-text pull-left") do
      tool_tip_text
    end
  end

  def program_tooltip(program, profile_question)
    roles_for_membership_form =  part_of_roles_for_membership_form(program, profile_question)
    editable_by = editable_by_roles(program, profile_question)
    mandatory_for = mandatory_info_for_roles(program, profile_question)
    if (profile_question.has_match_configs?(program) || roles_for_membership_form.present? || editable_by.present? || mandatory_for.present?) 
      show_tooltip = true
    else
      show_tooltip = false
    end

    tool_tip_text = content_tag(:ul, class: "text-left m-l-n-md m-t-sm") do
      get_program_tooltip_content(profile_question, program, roles_for_membership_form, editable_by, mandatory_for)
    end
    tool_tip_visibility = show_tooltip ? "" : "hide"
    content_tag(:div, class: "p-r-xs cjs_tooltip_for_#{profile_question.id}_#{program.id} #{tool_tip_visibility} pull-right cursor-default") do
      concat(embed_icon(TOOLTIP_IMAGE_CLASS, '', :id => "program_tooltip_#{program.id}"))
      concat(tooltip("program_tooltip_#{program.id}", tool_tip_text, true, {placement: "left"}))
    end
  end

  def get_section_class(program_level, default_field)
    return "cjs-no-edit-destroy cjs-no-drag" if program_level
    default_field ? "cjs-no-drag" : ""
  end

  def get_section_description(section, options = {})
    return get_safe_string unless section.description.present?

    options[:class] += " text-muted"
    tag = options.delete(:tag) || :p
    content_tag(tag, chronus_auto_link(section.description), options).html_safe
  end

  private

  def id_prefix_from_label(label)
    label.to_s.strip_html.gsub(/(\&gt\;)|(\&lt\;)|[^0-9a-z ]/i, '_').to_html_id + '_'
  end

  def part_of_roles_for_membership_form(program, profile_question)
    program.role_questions.membership_questions.where(profile_question_id: profile_question.id).includes(role: [customized_term: [:translations]]).collect { |rq| rq.role.customized_term.term }
  end

  def editable_by_roles(program, profile_question)
    role_questions = program.role_questions.where(profile_question_id: profile_question.id).includes(role: [customized_term: [:translations]]).group_by{ |rq| rq.admin_only_editable ? :admin_only_editable : :editable_by_members }
    return if role_questions.blank?
    return program.roles.administrative.first.customized_term.term if role_questions[:editable_by_members].blank?
    roles_that_can_edit = role_questions[:editable_by_members].collect { |rq| rq.role.customized_term.term }
    (roles_that_can_edit.size == program.roles_without_admin_role.size) ? "display_string.Anyone".translate : roles_that_can_edit.join(", ")
  end

  def mandatory_info_for_roles(program, profile_question)
    role_questions = program.role_questions.where(profile_question_id: profile_question.id).includes(role: [customized_term: [:translations]]).group_by{ |rq| rq.required ? :mandatory : :not_mandatory }
    role_questions[:mandatory] = role_questions[:mandatory].collect { |rq| rq.role.customized_term.term } if role_questions[:mandatory].present?
    role_questions[:not_mandatory] = role_questions[:not_mandatory].collect { |rq| rq.role.customized_term.term } if role_questions[:not_mandatory].present?
    role_questions
  end

  def question_is_checked?(role_question, available_for_value)
    [available_for_value, RoleQuestion::AVAILABLE_FOR::BOTH].include?(role_question.available_for)
  end

  def preview_description_text_base_data(options = {})
    program = Role.find_by(id: options[:filter_role_ids][0]).program
    roles_by_id = program.roles.includes({customized_term: :translations}).index_by(&:id)
    viewer_role_ids = options[:viewer_role_ids] || roles_by_id.values.select(&:admin?).map(&:id)
    [roles_by_id, viewer_role_ids]
  end

  def preview_description_text_key(options = {})
    key = "feature.profile_customization.content.description_preview"
    key << "_profile" if options[:type] == :profile_question_preview
    key << "_membership" if options[:type] == :membership_question_preview
    key << "_with_connection" if options[:should_be_connected] && options[:viewer_role_ids].present?
    key
  end

  def preview_description_text_ary_of_roles(role_ids, roles_by_id)
    "display_string.ary_of_roles".translate(count: role_ids.size, roles_list: role_ids.map{|role_id| roles_by_id[role_id.to_i].customized_term.term_downcase }.to_sentence)
  end

  def profile_question_actions_tooltip_program_info(profile_question, options = {})
    if (options[:program_level].present? || @current_organization.standalone?)
      roles_for_membership_form =  part_of_roles_for_membership_form(@current_program, profile_question)
      editable_by = editable_by_roles(@current_program, profile_question)
      mandatory_for = mandatory_info_for_roles(@current_program, profile_question)
      get_program_tooltip_content(profile_question, @current_program, roles_for_membership_form, editable_by, mandatory_for)
    end
  end

  def profile_question_actions_tooltip_related(profile_question, options = {})
    ret = get_safe_string
    ret << content_tag(:li, "feature.profile_customization.label.conditional".translate) if profile_question.conditional_question_id.present?
    ret << content_tag(:li, "feature.profile_question.label.part_of_sftp_feed".translate) if profile_question.part_of_sftp_feed?(@current_organization)
    ret << profile_question_actions_tooltip_program_info(profile_question, options)
    ret = content_tag(:ul, ret, class: "text-left m-l-n-md m-t-sm") if ret.present?
    ret
  end

  def update_definition_details_for_conditional_questions!(definition_contents, profile_question)
    if profile_question.conditional_question_id.present?
      definition_contents << {title: "feature.profile_question.content.will_be_shown_only_if".translate, description: [content_tag(:u, @current_organization.profile_questions.find_by(id: profile_question.conditional_question_id).question_text)]}
      definition_contents << {title: "feature.profile_customization.content.response_contains_one_of".translate, description: [content_tag(:u, profile_question.conditional_text_choices.join("\n"))]}
    end
  end

  def get_question_type(question_type)
    PROFILE_MERGED_QUESTIONS[question_type].presence || question_type
  end

  def check_allow_multiple?(question_type)
    PROFILE_MERGED_QUESTIONS[question_type].present?
  end

  def show_allow_multiple_field?(question_type)
    check_allow_multiple?(question_type) || PROFILE_MERGED_QUESTIONS.invert[question_type].present?
  end

  def get_tooltip_images(profile_question, question_type)
    content = []
    tooltip_id = (profile_question.new_record? ? "allow_multiple_text_#{profile_question.section.id}" : "allow_multiple_text_#{profile_question.id}_#{question_type}")
    new_question_type = get_question_type(question_type)
    profile_questions_helper_tooltip_text.each do |key, tooltip_text|
      content << content_tag(:i, '', :id => "#{tooltip_id}_#{key}", :class => "#{TOOLTIP_IMAGE_CLASS} allow_tooltip allow_tooltip_#{key} #{"hide" unless new_question_type == key}")
      content << tooltip("#{tooltip_id}_#{key}", tooltip_text)
    end
    safe_join(content, "")
  end

  def get_program_tooltip_content(profile_question, program, roles_for_membership_form, editable_by, mandatory_for)
    ret = get_safe_string
    ret << content_tag(:li, "feature.profile_question.label.part_of_match_config".translate) if profile_question.has_match_configs?(program)
    ret << content_tag(:li, "feature.profile_question.content.part_of_roles_for_membership_form".translate(roles: roles_for_membership_form.join(", "))) if roles_for_membership_form.present?
    if editable_by.present?
      ret << ((editable_by == program.roles.administrative.first.customized_term.term) ? content_tag(:li, "feature.profile_customization.label.admin_only_edit_v1".translate) : content_tag(:li, "feature.profile_question.content.roles_can_edit".translate(roles: editable_by)))
    end
    mandatory_for_info = get_mandatory_for_info(mandatory_for)
    ret << content_tag(:li, mandatory_for_info.join(", ")) if mandatory_for_info.present?
    ret
  end

  def get_mandatory_for_info(mandatory_for)
    mandatory_for_info = []
    mandatory_for_info << "feature.profile_question.content.mandatory_for_roles".translate(roles: mandatory_for[:mandatory].join(", ")) if mandatory_for[:mandatory].present?
    mandatory_for_info << "feature.profile_question.content.not_mandatory_for_roles".translate(roles: mandatory_for[:not_mandatory].join(", ")) if mandatory_for[:not_mandatory].present?
    mandatory_for_info
  end

  def get_profile_question_onclick_actions(profile_question, tool_tip_text, options)
    content = get_safe_string
    content += get_profile_question_onclick_actions_tooltip(profile_question, tool_tip_text) if tool_tip_text.present?
    if options[:program_level].blank? && !profile_question.default_type?
      content += link_to((get_icon_content("fa fa-trash profile_question_delete_image fa-lg") + set_screen_reader_only_content("display_string.Remove".translate)), "javascript:void(0)", id: "cjs-delete-question-link-#{profile_question.id}", class: "cjs_profile_delete pull-left inherit-color", data: { url: profile_question_path(profile_question) })
      content += javascript_tag %Q[CustomizeProfileQuestions.deleteQuestion("#{profile_question.id}", "#{j delete_profile_question_confirm_message([], profile_question)}");]
    end
    content
  end

  def get_profile_question_onclick_actions_tooltip(profile_question, tool_tip_text)
    content_tag(:div, class: "p-r-xs cursor-default pull-left") do
      concat(embed_icon("#{TOOLTIP_IMAGE_CLASS} fa-lg", '', :id => "profile_question_help_icon_#{profile_question.id}"))
      concat(tooltip("profile_question_help_icon_#{profile_question.id}", tool_tip_text, true, {placement: "left", container: ".cjs-profile-questions-containing-column"}))
    end
  end

  def get_info_alert_for_matching_fields
    tooltip_text = "feature.profile_customization.content.blocked_for_matching_html_v1".translate
    dismissable_alert(tooltip_text)
  end

  def join_as_role_options_for_select(options = {})
    program = options[:program] || @current_program
    return unless program.present?
    organization = options[:organization] || @current_organization
    selected = options[:selected] || "common_text.prompt_text.select_role".translate
    allowed_roles = program.roles_without_admin_role.allowing_join_now
    allowed_roles = allowed_roles.where(name: @can_apply_role_names) if @can_apply_role_names.present?
    options = [["common_text.prompt_text.select_role".translate,""]] + allowed_roles.collect{|r| [r.customized_term.term, r.name]}
    options_for_select(options, :selected => selected)
  end

  def needs_false_label_profile_question?(profile_question, options = {})
    options[:non_editable] ||
    profile_question.name_type? ||
    profile_question.email_type? && !options[:preview_form] ||
    profile_question.education? ||
    profile_question.experience? ||
    profile_question.publication? ||
    profile_question.manager? ||
    [ProfileQuestion::Type::MULTI_CHOICE,
     ProfileQuestion::Type::RATING_SCALE,
     ProfileQuestion::Type::ORDERED_OPTIONS,
     ProfileQuestion::Type::MULTI_STRING].include?(profile_question.question_type)
  end

  def get_options_and_order(question, disabled_for_editing, id_used)
    question_choices = get_question_choices(question)
    question_type = question.is_a?(ProfileQuestion) ? "profile" : "common"
    question_choice_jst = File.open(Rails.root.join("app/assets/javascripts/templates/#{question_type}_questions/question_choice.jst.ejs")).read

    question_id = get_default_question_id(question)

    str = content_tag(:ul, id: "#{question_type}_question_choices_list_#{id_used}",class: "list-group disabled_for_editing_#{disabled_for_editing}", data: {"#{question_type}_question_id" => question_id}) do
      question_choices.map do |choice|
        EJS.evaluate(question_choice_jst, {"#{question_type}_question_id" => question_id, choice_id: choice.id, choice_text: choice.text, disabled_for_editing: disabled_for_editing, placeholder_text: 'feature.profile_question.choices.label.question_choice_placeholder'.translate})
      end.join(" ").html_safe
    end.html_safe

    str << hidden_field_tag("#{question_type}_question[question_choices][new_order]", question_choices.collect(&:id).join(","), id: "#{question_type}_question_#{id_used}_new_order")
  end

  def get_question_choices(question)
    question_choices = question.default_choice_records
    return question_choices unless question_choices.blank?
    return [Struct.new(:id, :text).new(1, "")] # To show empty choice on load
  end

  def get_bulk_add_choices_link(id_used, disabled_for_editing)
    return if disabled_for_editing
    buttons = link_to("feature.profile_question.choices.label.button_bulk_add_choices".translate, "javascript:void(0)", id: "cjs_bulk_add_choices_#{id_used}")
    content_tag(:label, buttons, class: "control-label m-r pull-right")
  end

  def get_question_choices_well(question, disabled_for_editing, id_used)
    question_type = question.is_a?(ProfileQuestion) ? "profile" : "common"
    find_select_str = dynamic_text_filter_box(
                          "find_and_select_#{id_used}",
                          "find_#{question_type}_question_choices_#{id_used}",
                          "MultiSelectAnswerSelector",
                          {handler_argument: "#{question_type}_question_choices_#{id_used}",
                          filter_box_additional_class: "no-padding m-t-0",
                          display_show_helper: false,
                          quick_find_additional_class: "no-border-left no-border-top no-border-right"})

    str = get_options_and_order(question, disabled_for_editing, id_used)

    find_select_script = javascript_tag(%Q[jQuery("#quick_find_#{question_type}_question_choices_#{id_used}").quicksearch("##{question_type}_question_choices_#{id_used} .cjs_quicksearch_item");])

    content = content_tag(:div, content_tag(:div, str, id: "#{question_type}_question_choices_#{id_used}", data: {slim_scroll: true}), class: "col-xs-12 no-padding")
    content_tag(:div, (find_select_str + content + find_select_script), class: "well white-bg clearfix m-b-0 no-padding") + javascript_tag("initialize.setSlimScroll()")
  end

  def construct_tab_pane_content(title, description = [], _options = {})
    content_tag(:div) do
      concat(content_tag(:h5, class: "col-xs-12 m-b-xxs") do
        title
      end) if title
      description.each do |line|
        concat(content_tag(:p, class: "text-muted col-xs-12 break-word") do
          line
        end)
      end
      concat(tag(:br))
    end
  end

  def get_profile_question_choices_list(profile_question, options = {})
    content_tag(:div, class: "p-xs b-l b-r b-t b-b #{options[:additional_classes]}", style: "max-height: 200px; overflow-y: scroll") do
      content_tag(:ul, class: "p-l-xxs", style: "list-style: none") do 
        profile_question.default_choices.each do |choice|
          concat content_tag(:li, choice)
        end
      end
    end
  end

  def get_default_question_id(question)
    return question.id if question.id
    return (question.is_a?(ProfileQuestion) ? 0 : "new")
  end

  # These class names are referred from /app/assets/stylesheets/v3/profile_question_icons.css
  def get_profile_question_icon_class(profile_question)
    profile_question_icons_hash = {ProfileQuestion::Type::STRING => "text-box", ProfileQuestion::Type::TEXT => "multi-line", ProfileQuestion::Type::SINGLE_CHOICE => "single-option", ProfileQuestion::Type::MULTI_CHOICE => "multiple-choice",
      ProfileQuestion::Type::FILE => "upload-file", ProfileQuestion::Type::MULTI_STRING => "text-box-multi", ProfileQuestion::Type::ORDERED_SINGLE_CHOICE => "ordered-options", ProfileQuestion::Type::LOCATION => "location", ProfileQuestion::Type::EXPERIENCE => "experience", ProfileQuestion::Type::MULTI_EXPERIENCE => "experience", ProfileQuestion::Type::EDUCATION => "education", ProfileQuestion::Type::MULTI_EDUCATION => "education", ProfileQuestion::Type::EMAIL => "text-box", ProfileQuestion::Type::SKYPE_ID => "skype-id", ProfileQuestion::Type::ORDERED_OPTIONS => "ordered-options", ProfileQuestion::Type::NAME => "text-box", ProfileQuestion::Type::PUBLICATION => "publication", ProfileQuestion::Type::MULTI_PUBLICATION => "publication", ProfileQuestion::Type::MANAGER => "manager", ProfileQuestion::Type::DATE => "date"}
    "profile-icon-" + profile_question_icons_hash[profile_question.question_type].to_s
  end
end