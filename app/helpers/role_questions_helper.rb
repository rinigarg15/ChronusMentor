module RoleQuestionsHelper

  def preview_and_edit_profile_question_settings(profile_question, all_questions=[])  
    qa_id = profile_question.id
    content_tag(:li, :id => "profile_question_#{qa_id}",
      :class => ('question_answer animated fadeInDown z-index-not-important disabled_no_drop list-group-item')) do
      render(:partial => 'profile_questions/preview_question', :locals => {:profile_question => profile_question, :section => profile_question.section, :all_questions => all_questions})
    end
  end

  def header_for_profile_question_settings(section)
    content_tag(:div, id: "profile_section_header_#{section.id}",
      class: 'profile_section_header p-b-xs b-b b-t p-t-xs clearfix') do
      render(partial: 'profile_questions/profile_questions_header')
    end
  end
  
  def get_role_question_section_content(section)
    profile_section_wrapper = content_tag(:div, {:id => "profile_section_#{section.id}"}) do
      collapsible_content(section.title, [], true, {:header_content => get_section_title(section, false), :no_onclick => true, :stacked_class => "unstacked", :additional_header_class => " no-arrow "}) do
        section_description = get_section_description(section, class: "m-b-sm", id: "section_description_#{section.id}")
        content_tag(:div, section_description + (render :partial => "role_questions/role_questions", :locals => {:profile_questions => (section.profile_questions & @profile_questions), :section => section, :all_questions => @profile_questions}))
      end
    end
    profile_section_wrapper
  end

  def private_question_help_text(profile_question, program, role_names)
    #TODO Get rid of the else part
    if @grouped_role_questions
      private_questions = @grouped_role_questions[profile_question.id]
    else
      #TODO #CareerDev - Multiple Role Hardcoding
      role_names = (role_names == 'mentor_student') ? ([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]) : role_names
      private_questions = program.role_questions_for(role_names, user: current_user_or_member).includes(:privacy_settings).where({:profile_question_id => profile_question.id})
    end
    return if private_questions.blank?

    private_values = private_questions.collect(&:private)
    unless private_values.include?(RoleQuestion::PRIVACY_SETTING::ALL) || RoleQuestionPrivacySetting.has_all_settings?(program, private_questions.collect(&:privacy_settings).flatten)

      program_custom_terms = @program_custom_term || Hash.new do |hash, key|
        if key.to_s =~ /role_term_(.+)_name/
          hash[key] = program.term_for(CustomizedTerm::TermType::ROLE_TERM, $1.to_s)
        else
          hash[key] = program.term_for("CustomizedTerm::TermType::#{key.to_s.upcase}".constantize)
        end
      end

      if private_values.uniq == [RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE]
        return "feature.profile_question.help_text.visible_to_admin".translate(:program => _program, :admins => program_custom_terms[:role_term_admin_name].pluralized_term_downcase).html_safe
      else
        help_text = []
        show_to_connected_members = private_questions.any?(&:show_connected_members?)
        if wob_member.try(&:is_admin?) && !@is_self_view
          help_text << "display_string.user.one".translate
          help_text << "feature.profile_question.help_text.connected_users_of_a_user".translate if show_to_connected_members
        else
          help_text << "display_string.you".translate
          help_text << "feature.profile_question.help_text.connected_users".translate if show_to_connected_members
        end
        program.roles.non_administrative.each do |role|
          help_text << program_custom_terms["role_term_#{role.name}_name".to_sym].pluralized_term_downcase if private_questions.any? {|q| q.show_for_roles?([role]) }
        end
        help_text << program_custom_terms[:role_term_admin_name].pluralized_term_downcase
        return "feature.profile_question.help_text.visible_to".translate(:all_roles => help_text.to_sentence(words_connector: ', ', last_word_connector: ", #{'display_string.and'.translate} "))
      end
    end
  end

  def get_section_membership_questions(section, membership_profile_questions = [])
    section_questions = []
    section_questions << membership_profile_questions.select{|m| m.section_id == section.id}    
    section_questions = section_questions.flatten
    render :partial => "membership_questions/display_membership_questions", :locals => {:section_questions => section_questions, :section => section} unless section_questions.empty?
  end

  def show_in_summary_check_box(role_question, options)
    check_box_tag(options[:name], options[:value], role_question.show_in_summary?, id: options[:id], class: options[:class], :disabled => role_question.disable_for_users_listing?)
  end

  def set_check_disabled(settings_option, role_question, question_type)
    checked = disabled = false

    if settings_option[:privacy_type] == RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE || (question_type != "undefined" && question_type == ProfileQuestion::Type::NAME)
      checked = disabled = true
    else
      if role_question.new_record?
        checked = true
        disabled = (settings_option[:privacy_type] == RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
      else
        role_ques_private = role_question.reload.private
        if settings_option[:privacy_type] == RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY
          disabled = role_question.show_all? || role_question.restricted?
          checked = role_question.show_user?
        else
          checked = role_question.show_for?(settings_option[:privacy_type], settings_option[:privacy_setting])
        end
      end
    end
    return checked, disabled
  end

# The following method computes the ID, name and classes for each Checkbox in the Visibility Settings for the given Role Question
# Example DOM structure of the Visibility Settings for Profile Question with ID 4 and for Role with ID 5
#
# <div class="role_questions_private no-margin controls" id="role_questions_private_4_5">
#   <label class="checkbox ">
#     <input checked="checked" class="form-control role_questions_private" disabled="disabled" id="role_questions_private_4_5_3" name="role_questions[5][privacy_settings][3]" onchange="CustomizeProfileQuestions.updateOptions('4','5', 0)" type="checkbox" value="1">
#     Administrators
#   </label>
#   <label class="checkbox ">
#     <input checked="checked" class="form-control role_questions_private" id="role_questions_private_4_5_4" name="role_questions[5][privacy_settings][4]" onchange="CustomizeProfileQuestions.updateOptions('4','5', 0)" type="checkbox" value="1">
#     User
#   </label>
#   <label class="checkbox ">
#     <input class="form-control role_questions_private role_questions_private_4_5_restricted" id="role_questions_private_4_5_2-2" name="role_questions[5][privacy_settings][2][2]" onchange="CustomizeProfileQuestions.updateOptions('4','5', 0)" type="checkbox" value="0">
#     User's mentoring connections
#   </label>
#   <label class="checkbox ">
#     <input class="form-control role_questions_private role_questions_private_4_5_restricted role_questions_private_4_5_restricted_role" id="role_questions_private_4_5_2-1-5" name="role_questions[5][privacy_settings][2][1][5]" onchange="CustomizeProfileQuestions.updateOptions('4','5', 0)" type="checkbox" value="0">
#     All mentors
#   </label>
#   <label class="checkbox ">
#     <input class="form-control role_questions_private role_questions_private_4_5_restricted role_questions_private_4_5_restricted_role" id="role_questions_private_4_5_2-1-6" name="role_questions[5][privacy_settings][2][1][6]" onchange="CustomizeProfileQuestions.updateOptions('4','5', 0)" type="checkbox" value="0">
#     All mentees
#   </label>
# </div>

  def get_privacy_settings_hash(program, q_id, role_id, question_type, role_question, profile_question)
    privacy_settings_hash = {}
    privacy_settings_array = RoleQuestion.privacy_setting_options_for(program)
    privacy_settings_array.each do |settings_option|
      checked, disabled = set_check_disabled(settings_option, role_question, question_type)
      class_names = ["role_questions_private"]
      privacy_id = settings_option[:privacy_type]
      privacy_name = "role_questions[#{role_id}][privacy_settings][#{settings_option[:privacy_type]}]"
      if settings_option[:privacy_type] == RoleQuestion::PRIVACY_SETTING::RESTRICTED
        privacy_id = "#{privacy_id}-#{settings_option[:privacy_setting][:setting_type]}"
        privacy_name += "[#{settings_option[:privacy_setting][:setting_type]}]"
        class_names << "role_questions_private_#{q_id}_#{role_id}_restricted"
        if settings_option[:privacy_setting][:setting_type] == RoleQuestionPrivacySetting::SettingType::ROLE
          privacy_id += "-#{settings_option[:privacy_setting][:role_id]}"
          privacy_name += "[#{settings_option[:privacy_setting][:role_id]}]"
          class_names << "role_questions_private_#{q_id}_#{role_id}_restricted_role"
        end
      end
      privacy_settings_hash.merge!({
        "#{settings_option[:label]}" => {
          :checked => checked,
          :name => privacy_name,
          :options => {
            :class => "#{class_names.join(" ")}",
            :id => "role_questions_private_#{q_id}_#{role_id}_#{privacy_id}",
            :value => checked ? 1 : 0,
            :onchange => "CustomizeProfileQuestions.updateOptions('#{q_id}','#{role_id}', #{question_type})",
            :disabled => disabled
          }
        }
      })
    end
    return privacy_settings_hash
  end

  def role_questions_visibility_settings(program, q_id, role_id, question_type, role_question, profile_question)
    privacy_settings_hash = get_privacy_settings_hash(program, q_id, role_id, question_type, role_question, profile_question)
    checkboxes_content = "".html_safe
    controls(id: "role_questions_private_#{q_id}_#{role_id}", class: "role_questions_private no-margin") do
      choices_wrapper("feature.profile_customization.label.visibility".translate) do
        privacy_settings_hash.each do |key, val|
          checkboxes_content += content_tag(:label, :class => "checkbox " + val[:label_class].to_s) do
            check_box_tag(val[:name], key, val[:checked], val[:options]) + key
          end
        end
        checkboxes_content
      end
    end
  end
end
