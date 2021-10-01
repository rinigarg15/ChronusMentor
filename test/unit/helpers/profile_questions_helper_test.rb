require_relative './../../test_helper.rb'

class ProfileQuestionsHelperTest < ActionView::TestCase

  include AppConstantsHelper

  def test_get_role_listing_program_view
    prof_ques = profile_questions(:string_q)
    assert_equal "Mentor", get_role_listing_program_view(programs(:albers).id, prof_ques)

    create_role_question(:profile_question => prof_ques, :role_names => RoleConstants::STUDENT_NAME)
    prof_ques.role_questions.reload
    programs(:albers).role_questions.reload
    assert_equal "Mentor and Student", get_role_listing_program_view(programs(:albers).id, prof_ques)

    prof_ques.role_questions.destroy_all
    assert_equal "-", get_role_listing_program_view(programs(:albers).id, prof_ques.reload)
  end

  def test_question_is_checked
    prof_ques = profile_questions(:string_q)
    role_question = create_role_question(:profile_question => prof_ques, :role_names => RoleConstants::STUDENT_NAME, :available_for => RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)

    assert question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)
    assert_false question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)

    role_question.update_attributes(:available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert_false question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)

    role_question.update_attributes(:available_for => RoleQuestion::AVAILABLE_FOR::BOTH)
    assert question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
    assert question_is_checked?(role_question, RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS)
  end

  def test_get_confirm_mesage_if_dependent_questions
    all_questions = programs(:org_primary).profile_questions
    q1 = all_questions.first
    q2 = all_questions.last
    assert_false q1.has_dependent_questions?
    assert_equal "", get_confirm_mesage_if_dependent_questions(all_questions, q1)

    q2.update_attributes!(:conditional_question_id => q1.id)
    all_questions = all_questions.reload
    confirm_content = get_confirm_mesage_if_dependent_questions(all_questions, q1)

    assert_match /&#39;Show only if&#39; setting of the following field\(s\):/, confirm_content
    assert_match /#{q2.question_text}/, confirm_content

    questions = all_questions.last(6)
    questions.map!{ |question| question.update_attributes!(:conditional_question_id => q1.id)}
    all_questions = all_questions.reload
    confirm_content = get_confirm_mesage_if_dependent_questions(all_questions, q1)

    set_response_text(confirm_content)
    assert_match /&#39;Show only if&#39; setting of the following field\(s\):/, confirm_content
    assert_select "ul" do
      assert_select "li", 6
      assert_select "li", {text: "and 1 more"}
    end
  end

  def test_preview_description_box
    assert_nil preview_description_box
    assert_nil preview_description_box(filter_role: [])
    assert_not_nil preview_description_box(filter_role: ['something'])
  end

  def test_preview_description_text
    program = programs(:albers)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    mentee_role = program.find_role(RoleConstants::STUDENT_NAME)
    assert_equal '', preview_description_text
    type = :profile_question_preview
    assert_equal "Below is preview of how a profile looks to a user with administrator role when they view a user with mentor role. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id])
    assert_equal "Below is preview of how a profile looks to a user with administrator role when they view a user with mentor role. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id], should_be_connected: true)
    assert_equal "Below is preview of how a profile looks to a user with mentor and student roles when they view a user with mentor role. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id], viewer_role_ids: [mentor_role.id, mentee_role.id])
    assert_equal "Below is preview of how a profile looks to a user with student role when they view a user with mentor role with whom they are connected. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id], viewer_role_ids: [mentee_role.id], should_be_connected: true)
    type = :membership_question_preview
    assert_equal "Below is preview of how a membership form looks to a user with mentor role. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id])
    assert_equal "Below is preview of how a membership form looks to a user with mentor role. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id], should_be_connected: true)
    assert_equal "Below is preview of how a membership form looks to a user with mentor and student roles. Preview is generated as if the users are yet to fill any of their profile fields.", preview_description_text(type: type, filter_role_ids: [mentor_role.id, mentee_role.id])
  end

  def test_join_as_role_options_for_select
    program = programs(:albers)
    organization = programs(:org_primary)
    assert_false program.show_multiple_role_option?
    options_for_select = join_as_role_options_for_select({:program => program, :organization => organization})
    assert_match /<option value=\"\">Select Role...<\/option>\n<option value=\"mentor\">Mentor<\/option>\n<option value=\"student\">Student<\/option>/, options_for_select
    program.show_multiple_role_option = true
    program.save
    options_for_select = join_as_role_options_for_select({:program => program.reload, :organization => organization})
    assert_match /<option value=\"\">Select Role...<\/option>\n<option value=\"mentor\">Mentor<\/option>\n<option value=\"student\">Student<\/option>/, options_for_select
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    mentor_role.membership_request = false
    mentor_role.join_directly = true
    mentor_role.save
    options_for_select = join_as_role_options_for_select({:program => program, :organization => organization})
    assert_match /<option value=\"\">Select Role...<\/option>\n<option value=\"mentor\">Mentor<\/option>\n<option value=\"student\">Student<\/option>/, options_for_select
    mentor_role.join_directly = false
    mentor_role.save
    options_for_select = join_as_role_options_for_select({:program => program, :organization => organization})
    assert_match /<option value=\"\">Select Role...<\/option>\n<option value=\"student\">Student<\/option>/, options_for_select
  end

  def test_needs_false_label_profile_question
    q1 = profile_questions(:profile_questions_1)
    assert_equal ProfileQuestion::Type::NAME, q1.question_type
    q2 = profile_questions(:profile_questions_2)
    assert_equal ProfileQuestion::Type::EMAIL, q2.question_type
    q3 = profile_questions(:profile_questions_3)
    assert_equal ProfileQuestion::Type::LOCATION, q3.question_type
    q4 = profile_questions(:profile_questions_4)
    assert_equal ProfileQuestion::Type::STRING, q4.question_type
    q5 = profile_questions(:profile_questions_5)
    assert_equal ProfileQuestion::Type::SKYPE_ID, q5.question_type
    q6 = profile_questions(:profile_questions_6)
    assert_equal ProfileQuestion::Type::MULTI_EDUCATION, q6.question_type
    q7 = profile_questions(:profile_questions_7)
    assert_equal ProfileQuestion::Type::MULTI_EXPERIENCE, q7.question_type
    q8 = profile_questions(:profile_questions_8)
    assert_equal ProfileQuestion::Type::TEXT, q8.question_type
    q9 = profile_questions(:profile_questions_9)
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q9.question_type
    q10 = profile_questions(:profile_questions_11)
    assert_equal ProfileQuestion::Type::MULTI_CHOICE, q10.question_type
    q11 = profile_questions(:mentor_file_upload_q)
    assert_equal ProfileQuestion::Type::FILE, q11.question_type
    q12 = profile_questions(:experience_q)
    assert_equal ProfileQuestion::Type::EXPERIENCE, q12.question_type
    q13 = profile_questions(:education_q)
    assert_equal ProfileQuestion::Type::EDUCATION, q13.question_type
    q14 = profile_questions(:publication_q)
    assert_equal ProfileQuestion::Type::PUBLICATION, q14.question_type
    q15 = profile_questions(:multi_publication_q)
    assert_equal ProfileQuestion::Type::MULTI_PUBLICATION, q15.question_type
    q16 = create_question(:question_type => ProfileQuestion::Type::RATING_SCALE, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert_equal ProfileQuestion::Type::RATING_SCALE, q16.question_type
    q17 = create_question(:question_type => ProfileQuestion::Type::MULTI_STRING, :question_text => "Phone")
    assert_equal ProfileQuestion::Type::MULTI_STRING, q17.question_type
    q18 = create_question(:question_choices => "A,B,C", :question_type => ProfileQuestion::Type::SINGLE_CHOICE)
    assert_equal ProfileQuestion::Type::SINGLE_CHOICE, q18.question_type
    q19 = create_question(:question_type => ProfileQuestion::Type::ORDERED_OPTIONS, :question_text => "Select Preference", :question_choices => "alpha, beta, gamma", :options_count => 2)
    assert_equal ProfileQuestion::Type::ORDERED_OPTIONS, q19.question_type
    q20 = profile_questions(:manager_q)
    assert_equal ProfileQuestion::Type::MANAGER, q20.question_type

    assert needs_false_label_profile_question?(q1)
    assert needs_false_label_profile_question?(q2)
    assert_false needs_false_label_profile_question?(q3)
    assert_false needs_false_label_profile_question?(q4)
    assert_false needs_false_label_profile_question?(q5)
    assert needs_false_label_profile_question?(q6)
    assert needs_false_label_profile_question?(q7)
    assert_false needs_false_label_profile_question?(q8)
    assert_false needs_false_label_profile_question?(q9)
    assert needs_false_label_profile_question?(q10)
    assert_false needs_false_label_profile_question?(q11)
    assert needs_false_label_profile_question?(q12)
    assert needs_false_label_profile_question?(q13)
    assert needs_false_label_profile_question?(q14)
    assert needs_false_label_profile_question?(q15)
    assert needs_false_label_profile_question?(q16)
    assert needs_false_label_profile_question?(q17)
    assert_false needs_false_label_profile_question?(q18)
    assert needs_false_label_profile_question?(q19)
    assert needs_false_label_profile_question?(q20)
  end

  def test_preview_profile_question
    q1 = profile_questions(:profile_questions_1)
    assert_equal "<div class=\"help-block small text-muted\" id=\"question_help_text_1\"></div>", preview_profile_question(q1)
    q1.update_attributes(:help_text => "help_text");
    assert_equal "<div class=\"help-block small text-muted\" id=\"question_help_text_1\">help_text</div>", preview_profile_question(q1);
    q1.update_attributes(:help_text => "<b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a>")
    assert_equal "<div class=\"help-block small text-muted\" id=\"question_help_text_1\"><b>help text</b> <a href=\"https://www.chronus.com\"> chronus </a></div>", preview_profile_question(q1);
  end

  def test_get_info_icon_for_matching_fields
    content = get_info_alert_for_matching_fields
    assert_match '<div class="alert alert-warning"><button name="button" type="button" aria-hidden="true" data-dismiss="alert" class="close ">&times;</button>Please note only parts of the field can be edited as this field is used for matching users. Please contact Chronus support for assistance</div>', content
  end

  def test_update_delete_confirmation_template
    content = update_delete_confirmation_template(block_class: "hide", block_id: "cjs_block_id", base_text: "Look into the following") { content_tag(:span, "Hi!") }
    set_response_text(content)
    assert_select "div.hide#cjs_block_id", text: "Look into the followingHi!It is suggested that you check the above item(s) before you proceed. Do you still want to proceed?"
    assert_select "div.hide#cjs_block_id" do
      assert_select "ol" do
        assert_select "span", text: "Hi!"
      end
    end
  end

  def test_delete_profile_question_confirm_message_no_dependent_qns_and_match_config_associated
    @current_program = programs(:albers)
    @current_organization = @current_program.organization
    all_questions = @current_organization.profile_questions
    q1 = all_questions.first
    q2 = all_questions.last
    ProfileQuestion.any_instance.stubs(:has_match_configs?).returns(false)

    # Organization level - not tied to match configs; no dependent questions
    self.expects(:program_view?).at_least(0).returns(false)
    self.expects(:current_program).at_least(0).returns(nil)
    content = delete_profile_question_confirm_message(all_questions, q1)
    assert_equal "Are you sure you want to delete this field? <br/> The field will be removed from all programs and all user responses for this field, if any, will be lost.", content
    assert_no_match(/Show only if/, content)
    assert_no_match(/User responses for this field will be lost/, content)
    assert_no_match(/Match score as this is associated to matching/, content)

    # Program level - not tied to match configs; no dependent questions
    self.expects(:program_view?).at_least(0).returns(true)
    self.expects(:current_program).at_least(0).returns(@current_program)
    content = delete_profile_question_confirm_message(all_questions, q1)
    assert_equal "Are you sure you want to remove this question for this program? <br/> All user responses for this question, if any, will be lost.", content
    assert_no_match(/Show only if/, content)
    assert_no_match(/User responses for this field will be lost/, content)
    assert_no_match(/Match score as this is associated to matching/, content)
  end

  def test_delete_profile_question_confirm_message
    @current_program = programs(:albers)
    @current_organization = @current_program.organization
    all_questions = @current_organization.profile_questions
    q1 = all_questions.first
    q2 = all_questions.last
    q2.update_attributes(conditional_question_id: q1.id)
    all_questions = all_questions.reload
    ProfileQuestion.any_instance.stubs(:has_match_configs?).returns(true)

    # Organization level - tied to match configs, has dependent questions
    self.expects(:program_view?).at_least(0).returns(false)
    self.expects(:current_program).at_least(0).returns(nil)
    content = delete_profile_question_confirm_message([], q1)
    assert_match /&#39;Show only if&#39; setting of the following field\(s\):/, content
    assert_match /#{q2.question_text}/, content
    assert_match /User responses for this field will be lost/, content
    assert_match /Match score as this is associated to matching/, content
  end
  def test_cannot_reposition_default_section
    program = programs(:albers)
    organization = program.organization
    default_section = organization.default_section
    result = get_section_content(default_section)
    set_response_text(result)
    assert_select 'div.disabled_no_drop'
    non_default_section = organization.sections.find_by(default_field: false)
    result = get_section_content(non_default_section)
    set_response_text(result)
    assert_select 'div.cursor-move'
    assert_select 'div.disabled_no_drop', 0
  end

  def test_get_profile_question_tabs
    profile_question = profile_questions(:profile_questions_1)
    tabs_title = get_profile_question_tabs_title(profile_question, "new_label", class: "new_class")
    assert_match "new_class", tabs_title
    assert_match %Q[href="#tab_new_label"], tabs_title
    tabs_title = get_profile_question_tabs_title(profile_question, "new_label", class: "new_class", active: true)
    assert_match "active new_class", tabs_title
  end

  def test_get_profile_question_tabs_content
    contents = []
    contents << {title: "title 1", description: ["description 1"]}
    tabs_content = get_profile_question_tabs_content("new_label", contents)
    assert_match %Q[id="tab_new_label"], tabs_content
    assert_match "title 1", tabs_content
    assert_match "description 1", tabs_content
  end

  def test_view_profile_question_definition_details
    profile_question = profile_questions(:multi_choice_q)
    conditional_question = profile_questions(:profile_questions_9)
    profile_question.conditional_question_id = conditional_question.id

    conditional_question_choices = conditional_question.question_choices
    conditional_question_choices[0].conditional_match_choices.create(profile_question: profile_question)
    conditional_question_choices[1].conditional_match_choices.create(profile_question: profile_question)
    profile_question.help_text = "Help Text"
    @current_organization = profile_question.organization
    response = view_profile_question_definition_details(profile_question)

    assert_equal "display_string.Name".translate, response.first[:title]
    assert_equal profile_question.question_text, response.first[:description].first

    assert_equal "display_string.Type".translate, response.second[:title]
    assert_equal compressed_question_type(profile_question, text_only: true), response.second[:description].first

    assert_equal "feature.profile_customization.label.field_description".translate, response.third[:title]
    assert_equal profile_question.help_text, response.third[:description].first

    assert_equal "feature.profile_question.label.choices".translate, response.fourth[:title]
    profile_question.default_choices.collect { |choice| assert_match "<li>#{choice}</li>", response.fourth[:description].first }

    assert_equal "feature.profile_question.content.will_be_shown_only_if".translate, response.fifth[:title]
    assert_match conditional_question.question_text, response.fifth[:description].first

    assert_equal "feature.profile_customization.content.response_contains_one_of".translate, response[5][:title]
    assert_match "Male\nFemale", response[5][:description].first
  end

  def test_get_multi_tool_tip_with_linkedin_enabled
    @current_organization = programs(:org_primary)
    assert @current_organization.linkedin_imports_feature_enabled?
    expected_response = "Users will have option to add multiple education as sub-fields within this field."
    assert_select_helper_function "span.help-text", get_multi_tool_tip(type: ProfileQuestion::Type::MULTI_EDUCATION), text:  expected_response

    expected_response = "Users will have option to add multiple experiences as sub-fields within this field. They can also import from LinkedIn and then add or delete experiences as desired."
    assert_select_helper_function "span.help-text", get_multi_tool_tip(type: ProfileQuestion::Type::MULTI_EXPERIENCE), text:  expected_response

    expected_response = "Users will have an option to add multiple publications in this field."
    assert_select_helper_function "span.help-text", get_multi_tool_tip(type: ProfileQuestion::Type::MULTI_PUBLICATION), text:  expected_response
  end

  def test_get_multi_tool_tip_with_linkedin_disabled
    @current_organization = programs(:org_primary)
    security_setting = @current_organization.security_setting
    security_setting.linkedin_token = ""
    security_setting.save!
    assert_false @current_organization.linkedin_imports_allowed?

    assert_select_helper_function "span.help-text", get_multi_tool_tip(type: ProfileQuestion::Type::MULTI_EDUCATION), text: "Users will have option to add multiple education as sub-fields within this field."
    assert_select_helper_function "span.help-text", get_multi_tool_tip(type: ProfileQuestion::Type::MULTI_EXPERIENCE), text: "Users will have option to add multiple experiences as sub-fields within this field."
    assert_select_helper_function "span.help-text", get_multi_tool_tip(type: ProfileQuestion::Type::MULTI_PUBLICATION), text: "Users will have an option to add multiple publications in this field."
  end

  def test_profile_question_actions_org_level
   profile_question = profile_questions(:profile_questions_1)
   @current_organization = profile_question.organization
   @current_program = @current_organization.programs.first

   # checking conditional and part of sftp at org level page
   assert profile_question.respond_to?(:part_of_sftp_feed?)
   profile_question.expects(:part_of_sftp_feed?).returns(true)
   profile_question.conditional_question_id = 1
   response = profile_question_actions(profile_question)
   assert_match "feature.profile_customization.label.conditional".translate, response
   assert_match "feature.profile_question.label.part_of_sftp_feed".translate, response
   assert_no_match "feature.profile_question.label.part_of_match_config".translate, response
   assert_no_match "Part of Mentor, Student membership form", response
   assert_no_match "Mentor, Student can edit", response
   assert_no_match "Mandatory for Mentor, Student", response

   profile_question.expects(:part_of_sftp_feed?).returns(false)
   profile_question.conditional_question_id = nil
   response = profile_question_actions(profile_question)
   assert_no_match "feature.profile_customization.label.conditional".translate, response
   assert_no_match "feature.profile_question.label.part_of_sftp_feed".translate, response
  end

  def test_profile_question_actions_program_level
    profile_question = profile_questions(:profile_questions_1)
    @current_organization = profile_question.organization
    @current_program = @current_organization.programs.first

    enable_membership_request!(@current_program)
    assert profile_question.respond_to?(:has_match_configs?)
   	profile_question.expects(:has_match_configs?).returns(true)
   	response = profile_question_actions(profile_question, program_level: true)
   	assert_match "feature.profile_question.label.part_of_match_config".translate, response
   	assert_match "Part of Mentor, Student membership form", response
   	assert_match "Mentor, Student can edit", response
   	assert_match "Mandatory for Mentor, Student", response
  end

  def test_compressed_question_type_with_text_only_option
    profile_question = profile_questions(:profile_questions_1)
    @current_organization = profile_question.organization
    profile_question.question_type = ProfileQuestion::Type::STRING
    assert_equal "Text Entry", compressed_question_type(profile_question, text_only: true)
  end

  def test_list_of_programs_tooltip
    profile_question = profile_questions(:profile_questions_1)
    assert profile_question.programs.present?
    response = list_of_programs_tooltip("cjs-programs-count-for-profile-question-#{profile_question.id}", profile_question.programs)
    assert_match "cjs-programs-count-for-profile-question-#{profile_question.id}", response
    response = list_of_programs_tooltip("cjs-programs-count-for-profile-question-#{profile_question.id}", [])
    assert_nil response
  end

  def test_editable_by_roles
    profile_question = profile_questions(:profile_questions_1)
    program = profile_question.programs.first
    profile_question.role_questions.update_all(admin_only_editable: true)
    response = editable_by_roles(program, profile_question)
    assert_equal "Administrator", response
    profile_question.role_questions.update_all(admin_only_editable: false)
    response = editable_by_roles(program, profile_question)
    assert_equal "Mentor, Student", response
    profile_question.role_questions.destroy_all
    response = editable_by_roles(program, profile_question)
    assert_nil response
  end

  def test_mandatory_info_for_roles
    profile_question = profile_questions(:profile_questions_1)
    program = profile_question.programs.first
    profile_question.role_questions.update_all(required: true)
    response = mandatory_info_for_roles(program, profile_question)
    assert_equal 2, response[:mandatory].size
    profile_question.role_questions.update_all(required: false)
    response = mandatory_info_for_roles(program, profile_question)
    assert_equal 2, response[:not_mandatory].size
    program.role_questions.where(profile_question_id: profile_question.id).first.update_attributes(required: true)
    program.role_questions.where(profile_question_id: profile_question.id).second.update_attributes(required: false)
    response = mandatory_info_for_roles(program, profile_question)
    assert_equal 2, response.keys.size
    assert_equal [:mandatory, :not_mandatory], response.keys
    assert_equal ["Mentor"], response[:mandatory]
    assert_equal ["Student"], response[:not_mandatory]
  end

  def test_program_tooltip
    profile_question = profile_questions(:profile_questions_1)
    @current_organization = profile_question.organization
    @current_program = @current_organization.programs.first

    enable_membership_request!(@current_program)
    assert profile_question.respond_to?(:has_match_configs?)
    profile_question.expects(:has_match_configs?).twice.returns(true)
    response = program_tooltip(@current_program, profile_question)
    assert_match "feature.profile_question.label.part_of_match_config".translate, response
    assert_match "Part of Mentor, Student membership form", response
    assert_match "Mentor, Student can edit", response
    assert_match "Mandatory for Mentor, Student", response
  end

  def test_get_section_class
    assert_equal "", get_section_class(false, false)
    assert_equal "cjs-no-drag", get_section_class(false, true)
    assert_equal "cjs-no-edit-destroy cjs-no-drag", get_section_class(true, false)
  end

  def test_get_section_description
    section = Section.first
    section.update_attributes!(description: "Welcome to https://www.chronus.com")
    content = get_section_description(section, class: "m-b-sm", id: "section_id")
    assert_select_helper_function_block "p.m-b-sm.text-muted#section_id", content do
      assert_select_helper_function "a", content, text: "https://www.chronus.com"
    end

    content = get_section_description(section, class: "m-b", id: "section_id", tag: :div)
    assert_select_helper_function_block "div.m-b.text-muted#section_id", content do
      assert_select_helper_function "a", content, text: "https://www.chronus.com"
    end
    section.update_attributes!(description: "")
    assert_equal get_safe_string, get_section_description(section, class: "m-b-sm", id: "section_id", tag: :div)
  end

  def test_get_profile_question_type_options_array
    assert_equal [["Date", 20], ["Education", 12], ["Email", 13], ["Experience", 10], ["Location", 8], ["Manager", 19], ["Multi line", 1], ["Multiple Text Entry", 6], ["Name", 16], ["Ordered Options", 15], ["Pick multiple answers", 3], ["Pick one answer", 2], ["Publication", 18], ["Skype ID", 14], ["Text Entry", 0], ["Upload File", 5]], get_profile_question_type_options_array(true, true, true, true)
  end

  private

  def _Mentor
    "Mentor"
  end

  def _Mentee
    "Student"
  end

  def _programs
    "programs"
  end

  def _program
    "program"
  end

  def _Programs
    "Programs"
  end
end