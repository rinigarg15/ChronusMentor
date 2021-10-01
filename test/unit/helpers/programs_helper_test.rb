require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/programs_helper"

class ProgramsHelperTest < ActionView::TestCase
  include TranslationsService

  def setup
    super
    helper_setup
  end

  def test_link_box
    str = link_box("icon.png", "Heading", 'google.com')
    set_response_text(str)
    assert_select "div", :class => /link_box_icon pic-col-md-4 text-center height-105/ do
      assert_select "a[href='google.com']" do
#        assert_select 'img[src=?]', /.*\/assets\/icons\/icon.png.*/
        assert_select "div", :text => "Heading"
      end
    end
  end

  def test_one_time_engagement_type_selection
    program = programs(:albers)
    str = one_time_engagement_type_selection(program)
    set_response_text str
    assert_equal "<div class=\"cjs_show_hide_sub_selector has-above-tiny\" id=\"cjs_carrer_based\"><label class=\"radio\"><input type=\"radio\" name=\"program[engagement_type]\" id=\"program_engagement_type_1\" value=\"1\" class=\"cjs_engagement_type\" checked=\"checked\" />Career Based</label><label class=\"m-l-md  cjs_career_mentoring_options\"><input type=\"checkbox\" name=\"program[engagement_type]\" id=\"program_engagement_type\" value=\"3\" class=\"attach-top cjs_select_ongoing_mentoring\" checked=\"checked\" /><div class=\"inline m-l-xs\">Ongoing Mentoring</div></label><label class=\"m-l-md  cjs_career_mentoring_options\"><input type=\"checkbox\" name=\"program[enabled_features][]\" id=\"program_enabled_features_\" value=\"calendar\" class=\"attach-top cjs_select_one_time_mentoring\" /><div class=\"inline m-l-xs\">One Time Mentoring</div></label><label class=\"radio\"><input type=\"radio\" name=\"program[engagement_type]\" id=\"program_engagement_type_2\" value=\"2\" class=\"cjs_engagement_type\" />Project Based Engagements</label></div>", str
  end

  def test_one_time_setting_button_for_an_unset_attribute
    program = programs(:org_primary).programs.create!(name: "Pgora name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, root: "Domain")
    assert_nil program.allow_one_to_many_mentoring

    form = mock("form object")
    form.expects(:radio_button).with(:allow_one_to_many_mentoring, true, :checked => false, :onchange => nil).returns("Value0")
    form.expects(:radio_button).with(:allow_one_to_many_mentoring, false, :checked => false, :onchange => nil).returns("Value1")
    one_time_setting_radio_button(form, program, :allow_one_to_many_mentoring, ["Yes", "No"])
  end

  def test_mailer_templates_links_to_correct_for_disabling_calendar
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    template = program.mailer_templates.last
    cm = template.campaign_message
    campaign = cm.campaign
    assert template.is_a_campaign_message_template?
    template.update_attribute(:source, template.source + " {{number_of_pending_meeting_requests}} {{meeting_request_acceptance_rate}} {{meeting_request_average_response_time}}")
    assert_equal "<a target=\"_blank\" href=\"/campaign_management/user_campaigns/#{campaign.id}/abstract_campaign_messages/#{cm.id}/edit\">Campaign Message - Subject6</a>", mailer_templates_links_to_correct_for_disabling_calendar(program)
  end

  def test_get_error_message_while_disabling_calendar
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR)
    assert_equal "Please close all the pending meeting requests to disable one-time mentoring", get_error_message_while_disabling_calendar(program)
    template = program.mailer_templates.last
    cm = template.campaign_message
    campaign = cm.campaign
    template.update_attribute(:source, template.source + " {{number_of_pending_meeting_requests}} {{meeting_request_acceptance_rate}} {{meeting_request_average_response_time}}")
    assert_equal "Please close all the pending meeting requests and remove meeting request tags from <a target=\"_blank\" href=\"/campaign_management/user_campaigns/#{campaign.id}/abstract_campaign_messages/#{cm.id}/edit\">Campaign Message - Subject6</a> to disable one-time mentoring", get_error_message_while_disabling_calendar(program)
    assert get_error_message_while_disabling_calendar(program).html_safe?
    program.meeting_requests.active.update_all(status: AbstractRequest::Status::CLOSED)
    assert_equal "Please remove meeting request tags from <a target=\"_blank\" href=\"/campaign_management/user_campaigns/#{campaign.id}/abstract_campaign_messages/#{cm.id}/edit\">Campaign Message - Subject6</a> to disable one-time mentoring", get_error_message_while_disabling_calendar(program)
    assert get_error_message_while_disabling_calendar(program).html_safe?
  end

  def test_one_time_setting_button_for_an_unset_attribute_with_onchange
    program = programs(:org_primary).programs.create!(name: "Pgora name", engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING, root: "Domain")
    assert_nil program.allow_one_to_many_mentoring

    form = mock("form object")
    form.expects(:radio_button).with(:allow_one_to_many_mentoring, true, :checked => false, :onchange => "action_1").returns("Value0")
    form.expects(:radio_button).with(:allow_one_to_many_mentoring, false, :checked => false, :onchange => "action_2").returns("Value1")
    one_time_setting_radio_button(form, program, :allow_one_to_many_mentoring, ["Yes", "No"], [true, false], onchange: ["action_1", "action_2"])
  end

  def test_one_time_setting_button_for_a_set_attribute
    form = mock("form object")
    str = one_time_setting_radio_button(form, programs(:moderated_program), :mentor_request_style, ["Blah", "Asdfgf mmm", "Lmnk yui"], [0, 1, 2])
    set_response_text str
    assert_select 'span#mentor_request_style', 'Asdfgf mmm'
  end

  def test_get_experience_for_welcome_widget
    user = users(:f_mentor)
    profile_question_ids = welcome_user_profile_question_ids(user, [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE])
    assert profile_question_ids.include?(profile_questions(:multi_experience_q).id)
    role_question = role_questions(:multi_experience_role_q)

    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).get_role(RoleConstants::MENTOR_NAME).id)
    role_question.save!
    profile_question_ids = welcome_user_profile_question_ids(user, [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE])
    assert profile_question_ids.include?(profile_questions(:multi_experience_q).id)

    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::ADMIN_ONLY_VIEWABLE)
    role_question.save!
    profile_question_ids = welcome_user_profile_question_ids(user, [ProfileQuestion::Type::EXPERIENCE, ProfileQuestion::Type::MULTI_EXPERIENCE])
    assert_false profile_question_ids.include?(profile_questions(:multi_experience_q).id)
  end

  def test_quick_connect_mentor_info
    assert_equal "", quick_connect_mentor_info(users(:f_student), users(:f_student), programs(:albers), { welcome_widget: true })
    @current_user = users(:f_mentor)
    assert_equal "Lead Developer, Microsoft", quick_connect_mentor_info(users(:f_mentor), users(:f_mentor), programs(:albers), { welcome_widget: true })
    @current_user = users(:mentor_3)
    assert_equal "Chief Software Architect And Programming Lead, Mannar", quick_connect_mentor_info(users(:mentor_3), users(:mentor_3), programs(:albers), { welcome_widget: true })
    assert_match "New Delhi, Delhi, India", quick_connect_mentor_info(users(:robert), users(:robert), programs(:albers), { welcome_widget: true })

    created_at = users(:ram).member.created_at.beginning_of_month - 2.days
    users(:ram).member.stubs(:created_at).returns(created_at)

    date = DateTime.localize(created_at, format: :full_month_year)
    content = quick_connect_mentor_info(users(:ram), users(:f_student), programs(:albers), { from_quick_connect: true })
    set_response_text content
    assert_select "div.whitespace-nowrap.truncate-with-ellipsis", text: "Member since #{date}" 
  end

  def test_quick_connect_profile_question_ids
    user = users(:f_student)
    program = programs(:albers)
    viewer = members(:f_student)
    user_1 = users(:f_mentor)

    assert_equal [], quick_connect_profile_question_ids(user, members(:f_student), program, [])
    assert_equal [profile_questions(:education_q).id], quick_connect_profile_question_ids(user, members(:f_student), program, [ProfileQuestion::Type::EDUCATION])
    assert_equal [profile_questions(:education_q).id], quick_connect_profile_question_ids(user, members(:f_mentor), program, [ProfileQuestion::Type::EDUCATION])

    role_question = role_questions(:education_role_q)
    role_question.private = RoleQuestion::PRIVACY_SETTING::RESTRICTED
    role_question.privacy_settings.build(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).get_role(RoleConstants::STUDENT_NAME).id)
    role_question.save!
    assert_equal [], quick_connect_profile_question_ids(user, members(:f_student), program, [ProfileQuestion::Type::EDUCATION])

    role_question.privacy_settings.destroy_all
    role_question.privacy_settings.create(setting_type: RoleQuestionPrivacySetting::SettingType::ROLE, role_id: programs(:albers).get_role(RoleConstants::MENTOR_NAME).id)
    assert_equal [profile_questions(:education_q).id], quick_connect_profile_question_ids(user, members(:f_mentor), program, [ProfileQuestion::Type::EDUCATION])

    role_question.privacy_settings.destroy_all
    assert_equal [], quick_connect_profile_question_ids(users(:mkr_student), members(:f_mentor), program, [ProfileQuestion::Type::EDUCATION])

    role_question.privacy_settings.create(setting_type: RoleQuestionPrivacySetting::SettingType::CONNECTED_MEMBERS)
    assert_equal [profile_questions(:education_q).id], quick_connect_profile_question_ids(users(:mkr_student), members(:f_mentor), program, [ProfileQuestion::Type::EDUCATION])

    role_question.update_attribute(:private, RoleQuestion::PRIVACY_SETTING::USER_AND_ADMIN_ONLY)
    assert_equal [], quick_connect_profile_question_ids(users(:mkr_student), members(:f_mentor), program, [ProfileQuestion::Type::EDUCATION])
    assert_equal [profile_questions(:education_q).id], quick_connect_profile_question_ids(users(:mkr_student), members(:f_admin), program, [ProfileQuestion::Type::EDUCATION])
  end

  def test_get_quick_connect_title
    self.stubs(:mobile_app?).returns(false)
    content = get_quick_connect_title()
    assert_select_helper_function_block "div.gray-bg", content do
      assert_select "span.recommendation_title_text"
    end
  end

  def test_get_quick_connect_title_for_explicit_recommendations
    self.stubs(:mobile_app?).returns(false)
    set_response_text get_quick_connect_title_for_explicit_recommendations[0]
    assert_select "span.visible-xs" do
      "feature.explicit_preference.label.explicit_preferences_recommendations_home_page_label_mobile".translate
      assert_select "a.cjs_show_explicit_preference_popup_recommendations"
    end
    assert_select "span.hidden-xs" do
      "feature.explicit_preference.label.explicit_preferences_recommendations_home_page_label".translate
      assert_select "a.cjs_show_explicit_preference_popup_recommendations" do
        "feature.explicit_preference.label.personalize".translate
      end
    end
  end

  def test_append_home_page_explicit_preferences_button
    content = append_home_page_explicit_preferences_button(content_tag(:span, 'desktop'), content_tag(:span, 'mobile'))
    set_response_text content
    assert_select "span.visible-xs" do
      'mobile'
      assert_select "a.cjs_show_explicit_preference_popup_recommendations"
    end
    assert_select "span.hidden-xs" do
      'desktop'
      assert_select "a.cjs_show_explicit_preference_popup_recommendations" do
        "feature.explicit_preference.label.personalize".translate
      end
    end
  end

  def test_get_preference_based_mentor_lists_recommendations_title
    current_user.stubs(:can_configure_explicit_preferences?).returns(true)
    title = append_text_to_icon("fa fa-fw fa-users m-r-xs", "feature.implicit_preference.mentors_lists.popular_categories".translate)
    self.stubs(:append_home_page_explicit_preferences_button).with(title, title).returns('something')
    assert_equal 'something', get_preference_based_mentor_lists_recommendations_title

    self.stubs(:append_home_page_explicit_preferences_button).with(title, title).never
    current_user.stubs(:can_configure_explicit_preferences?).returns(false)
    assert_equal title, get_preference_based_mentor_lists_recommendations_title
  end

  def test_get_quick_connect_title_when_mentees_cannot_view_mentors_listing
    self.stubs(:mobile_app?).returns(false)
    current_user.stubs(:can_view_mentors?).returns(false)
    content = get_quick_connect_title()
    assert_select_helper_function_block "div.gray-bg", content do
      assert_select "span.recommendation_title_text"
    end
  end

  def test_quick_link_from_notification_icon_view
    l1 = quick_link("Google", 'http://google.com', 'goog', 10, {:notification_icon_view => true})
    set_response_text l1

    assert_select "li.list-group-item.no-padding.no-border" do
      assert_select "a[href='http://google.com']", :text => "Google10"
      assert_select "div.badge-danger.badge.pull-right.m-t-xs.m-l-xs", :text => "10"
      assert_select "div.cui_pending_requests_dropdown_text_container.pull-left", :text => "Google"
    end

    l1 = quick_link("Google", 'http://google.com', 'goog', 0, {:notification_icon_view => true})
    set_response_text l1

    assert_select "li.list-group-item.no-padding.no-border" do
      assert_select "a[href='http://google.com']", :text => "Google"
      assert_no_select "div.badge-danger.badge.pull-right.m-t-xs.m-l-xs", :text => "10"
      assert_select "div.cui_pending_requests_dropdown_text_container.pull-left", :text => "Google"
    end
  end

  def test_quick_link_without_new_items
    l1 = quick_link("Google", 'http://google.com', 'goog')
    set_response_text l1

    assert_select "li" do
      assert_select "a[href='http://google.com']", :text => "Google"
    end
  end

  def test_quick_link_with_new_items
    l2 = quick_link("Yahoo", 'http://yahoo.com', 'goog', 10)
    set_response_text l2
    assert_select "li" do
      assert_select "a[href='http://yahoo.com']", :text => /Yahoo/
      assert_select "a.badge-danger", :text => "10"
    end
  end

  def test_propose_group_settings
    program = programs(:pbe)
    role = program.find_role(RoleConstants::MENTOR_NAME)

    self.stubs(:render_group_proposal_approval_options).returns("<span>approval radio buttons</span>".html_safe)

    assert_false role.has_permission_name?(RolePermission::PROPOSE_GROUPS)
    set_response_text propose_group_settings(role)
    assert_select "input[id=\"program_send_group_proposals_#{role.id}\"][name=\"program[send_group_proposals][]\"][type=\"checkbox\"][value=\"#{role.id}\"]"
    assert_select "span", text: "approval radio buttons"

    role.add_permission(RolePermission::PROPOSE_GROUPS)

    set_response_text propose_group_settings(role)
    assert_select "input[id=\"program_send_group_proposals_#{role.id}\"][name=\"program[send_group_proposals][]\"][type=\"checkbox\"][value=\"#{role.id}\"][checked=\"checked\"]"
    assert_select "span", text: "approval radio buttons"
  end

  def test_render_group_proposal_approval_options
    role = programs(:pbe).find_role(RoleConstants::MENTOR_NAME)
    self.stubs(:get_admin_approval_needed_radio_button).with(role, true).returns("need approval")
    self.stubs(:get_no_approval_needed_radio_button).with(role, true).returns("no approval needed")

    assert_equal "need approval" + "no approval needed", render_group_proposal_approval_options(role, true)
  end

  def test_get_admin_approval_needed_radio_button
    role = programs(:pbe).find_role(RoleConstants::MENTOR_NAME)
    
    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(false)

    set_response_text get_admin_approval_needed_radio_button(role, true)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_yes\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=true]"

    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(true)
    set_response_text get_admin_approval_needed_radio_button(role, true)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_yes\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=true][checked=\"checked\"]"

    set_response_text get_admin_approval_needed_radio_button(role, false)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_yes\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=true]"
  end

  def test_get_no_approval_needed_radio_button
    role = programs(:pbe).find_role(RoleConstants::MENTOR_NAME)
    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(false)
    Group.stubs(:has_groups_proposed_by_role).returns(true)

    self.stubs(:get_disabled_help_text_for_no_approval_group_proposal).returns("<span>disabled text</span>".html_safe)

    assert_false role.needs_approval_to_create_circle?
    set_response_text get_no_approval_needed_radio_button(role, true)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_no\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=false][checked=\"checked\"][disabled=\"disabled\"]"
    assert_select "span", text: "disabled text"

    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(true)
    set_response_text get_no_approval_needed_radio_button(role, true)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_no\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=false][disabled=\"disabled\"]"

    set_response_text get_no_approval_needed_radio_button(role, false)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_no\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=false][disabled=\"disabled\"]"

    Group.stubs(:has_groups_proposed_by_role).returns(false)
    role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    set_response_text get_no_approval_needed_radio_button(role, false)
    assert_select "input[id=\"propose_needs_approval_#{role.name}_no\"][name=\"program[group_proposal_approval][#{role.id}]\"][type=\"radio\"][value=false]"
  end

  def test_get_disabled_help_text_for_no_approval_group_proposal
    program = programs(:pbe)
    set_response_text get_disabled_help_text_for_no_approval_group_proposal(true)
    assert_select "div.small.text-muted", text: "There are proposed mentoring connections awaiting approval. You must respond to them before you can enable this."
    assert_equal "", get_disabled_help_text_for_no_approval_group_proposal(false)
  end

  def test_role_join_settings
    program = programs(:albers)
    @current_organization = program.organization
    self.stubs(:current_program).returns(program)

    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    assert_false mentor_role.join_directly?
    assert mentor_role.membership_request?
    assert mentor_role.has_permission_name?("invite_mentors")
    assert_false mentor_role.has_permission_name?("invite_students")
    content = role_join_settings(mentor_role)
    assert_select_helper_function "input#join_directly_mentor", content, checked: false
    assert_select_helper_function "input#membership_request_mentor", content, checked: true
    assert_select_helper_function "input#invitation_mentor", content, checked: true
    assert_select_helper_function "input#mentor_can_invite_mentor", content, checked: true
    assert_select_helper_function "input#student_can_invite_mentor", content, checked: false
    assert_select_helper_function "input#mentor_can_invite_student", content, count: 0
    assert_select_helper_function "input#join_directly_only_with_sso_mentor", content, count: 0

    @current_organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    student_role.update_attributes!(join_directly: true, membership_request: false)
    assert_false student_role.has_permission_name?("invite_mentors")
    assert student_role.has_permission_name?("invite_students")
    content = role_join_settings(student_role)
    assert_select_helper_function "input#join_directly_student", content, checked: true
    assert_select_helper_function "input#membership_request_student", content, checked: false
    assert_select_helper_function "input#invitation_student", content, checked: true
    assert_select_helper_function "input#mentor_can_invite_student", content, checked: false
    assert_select_helper_function "input#student_can_invite_student", content, checked: true
    assert_select_helper_function "input#join_directly_only_with_sso_student", content, checked: false
  end

  def test_fetch_primary_home_tab
    program = programs(:albers)
    user = users(:f_mentor)

    assert_equal 0, fetch_primary_home_tab(program, user)
    user.primary_home_tab = 2
    user.save!
    assert_equal 2, fetch_primary_home_tab(program, user)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    assert_equal 0, fetch_primary_home_tab(program, user)
  end

  def test_display_home_page_group_logo
    group = groups(:mygroup)
    user = users(:f_mentor)
    content = display_home_page_group_logo(group, user)
    assert_match /media.*img-circle/m, content
    assert_match /madankumarrajan/, content
    assert_match /MM/, content

    group.update_members(group.mentors + [users(:mentor_3)], group.students)
    content = display_home_page_group_logo(group, user)
    assert_match /img-circle/, content
    assert_match /group_logo/, content
    assert_match /group_profile.png/, content
  end

  def test_member_details_in_banner_delete_button
    student = users(:f_student)
    current_user_is :f_student
    mentor = users(:f_mentor)
    @current_program = programs(:albers)
    # @current_user = student
    current_user_is :f_student
    set_response_text member_details_in_banner(mentor.member, "", 90, {delete_button: true})
    assert_select ".remove-mentor-request", 2 # mobile and web
    set_response_text member_details_in_banner(mentor.member, "", 90, {delete_button: false})
    assert_select ".remove-mentor-request", 0
  end

  def test_get_links_for_banner
    student = users(:f_student)
    current_user_is :f_student
    mentor = users(:f_mentor)
    mentor_id = mentor.id
    self.stubs(:show_send_message_link?).returns(true)
    content = get_links_for_banner(mentor, {mentor_id: 90}, show_send_message: true)
    assert_match /Connect/, content[0][0][:label]
    assert_match /\/messages\/new\?receiver_id=#{mentor.member.id}\&src=quick_connect_box/, content[0][0][:js]

    content = get_links_for_banner(mentor, {mentor_id: 90}, show_send_message: true, analytics_param: "md")
    assert_match /\/messages\/new\?receiver_id=#{mentor.member.id}\&src=md/, content[0][0][:js]

    self.stubs(:show_send_message_link?).returns(false)
    content = get_links_for_banner(mentor, {mentor_id: 90}, show_send_message: true)
    assert_equal [], content[0]
  end

  def test_member_details_in_banner_match_details
    current_user_is :f_student
    mentor = users(:f_mentor)
    @current_program = programs(:albers)

    self.stubs(:get_match_details_for_display).returns([" Male", 1])
    set_response_text member_details_in_banner(mentor.member, "", 90, {from_quick_connect: false})
    assert_select "div.match_details", 0
    assert_select "span.ct-match-percent", text: "90% match"
  end

  def test_get_matched_preferences_label
    set_response_text get_matched_preferences_label(0, 5, false)
    assert_select "div" do
      assert_select "span.text-muted", text: "Doesn't match on any of your preferences"
    end
    set_response_text get_matched_preferences_label(0, 5, true)
    assert_select "div" do
      assert_select "span.text-muted", text: "Ignored"
    end
    set_response_text get_matched_preferences_label(3, 5, false, {show_no_match_label: true})
    assert_select "div" do
      assert_select "span.text-muted", text: "Not a Match"
    end
    set_response_text get_matched_preferences_label(3, 5, false)
    assert_select "div" do
      assert_select "strong", text: "Matches on 3 out of 5 preferences"
    end
    set_response_text get_matched_preferences_label(3, 5, false, {quick_connect: true})
    assert_select "span" do
      assert_select "span.h5", text: "3"
      assert_select "span.h5", text: "5"
    end
  end

  def test_get_matched_tags_content
    current_user_is :f_student
    mentor = users(:f_mentor)
    @current_program = programs(:albers)

    self.stubs(:get_match_details_for_display).returns(["Male", 1])
    set_response_text get_matched_tags_content(users(:f_student), mentor, 90, {})
    assert_select "div.cui_margin_correction" do
      assert_select "a.cjs_show_match_details", text: "Male"
    end
  end

  def test_get_program_tabs
    program = programs(:albers)
    tabs = get_program_tabs(program, nil, "ra")
    assert_equal 2, tabs.size
    assert_equal get_program_ra_path(src: "ra"), tabs[0][:url]
    assert_equal Program::RA_TABS::ALL_ACTIVITY, tabs[0][:tab_order]
    assert_equal "all", tabs[0][:div_suffix]
    assert_equal get_program_ra_path(:my => 1, src: "ra"), tabs[1][:url]
    assert_equal Program::RA_TABS::MY_ACTIVITY, tabs[1][:tab_order]
    assert_equal "my", tabs[1][:div_suffix]
    tabs = get_program_tabs(program, 0, "ra")
    assert_equal 2, tabs.size
    tabs = get_program_tabs(program, 1, "ra")
    assert_equal 3, tabs.size
     assert_equal get_program_ra_path(:connection => 1, src: "ra"), tabs[2][:url]
    assert_equal Program::RA_TABS::CONNECTION_ACTIVITY, tabs[2][:tab_order]
    assert_equal "conn", tabs[2][:div_suffix]
    tabs = get_program_tabs(program, nil, "ra")
    assert_equal 2, tabs.size
    assert_equal get_program_ra_path(src: "ra"), tabs[0][:url]
    assert_equal Program::RA_TABS::ALL_ACTIVITY, tabs[0][:tab_order]
    assert_equal "all", tabs[0][:div_suffix]
    assert_equal get_program_ra_path(:my => 1, src: "ra"), tabs[1][:url]
    assert_equal Program::RA_TABS::MY_ACTIVITY, tabs[1][:tab_order]
    assert_equal "my", tabs[1][:div_suffix]
    tabs = get_program_tabs(program, 0, "ra")
    assert_equal 2, tabs.size
    tabs = get_program_tabs(program, 1, "ra")
    assert_equal 3, tabs.size
    assert_equal get_program_ra_path(:connection => 1, src: "ra"), tabs[2][:url]
    assert_equal Program::RA_TABS::CONNECTION_ACTIVITY, tabs[2][:tab_order]
    assert_equal "conn", tabs[2][:div_suffix]
  end

  def test_get_position_text
    @current_program = programs(:albers)
    assert_equal "1st", get_position_text(1)
    assert_equal "2nd", get_position_text(2)
    assert_equal "3rd", get_position_text(3)
    assert_equal "4th", get_position_text(4)
    assert_equal "5th", get_position_text(5)
    assert_equal "6th", get_position_text(6)
    assert_equal "7th", get_position_text(7)
    assert_equal "8th", get_position_text(8)
    assert_equal "9th", get_position_text(9)
    assert_equal "10th", get_position_text(10)
    assert_equal "11", get_position_text(11)
    assert_equal "12", get_position_text(12)
  end

  def test_get_position_div
    set_response_text get_position_div(5)
    assert_select "h3.position-div", text: "5th"
    assert_select "i.fa-arrows"
  end

  def test_get_mentoring_mode_for_ga
    program = programs(:pbe)
    mentoring_mode = get_mentoring_mode_for_ga(program)
    assert_equal "Circles", mentoring_mode

    program = programs(:albers)
    mentoring_mode = get_mentoring_mode_for_ga(program)
    assert_equal "Self Match", mentoring_mode

    program.enable_feature(FeatureName::CALENDAR)
    mentoring_mode = get_mentoring_mode_for_ga(program)
    assert_equal "Self Match Flash", mentoring_mode    

    program = programs(:moderated_program)
    mentoring_mode = get_mentoring_mode_for_ga(program)
    assert_equal "Admin Match", mentoring_mode

    program.enable_feature(FeatureName::CALENDAR)
    mentoring_mode = get_mentoring_mode_for_ga(program)
    assert_equal "Admin Match Flash", mentoring_mode    
  end

  def test_get_edit_terminology_link
    third_role = programs(:pbe).get_role(RoleConstants::TEACHER_NAME)
    edit_link = get_edit_terminology_link
    current_third_role_term = third_role.customized_term.term
    set_response_text(edit_link)
    assert_select "a", text: "display_string.Click_here".translate
    assert_no_match "program_settings_strings.content.current_term".translate(current_third_role_term: current_third_role_term), edit_link

    edit_link = get_edit_terminology_link(third_role)
    set_response_text(edit_link)
    assert_select "a", text: "display_string.Click_here".translate
    assert_match "program_settings_strings.content.current_term".translate(current_third_role_term: current_third_role_term), edit_link
  end

  def test_get_role_removal_denial_flash
    program = programs(:pbe)
    teacher_role = program.get_role(RoleConstants::TEACHER_NAME)
    assert_match "Role cannot be removed as the role has associated users", get_role_removal_denial_flash(teacher_role)
    forum = create_forum(access_role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::TEACHER_NAME], program: program)
    assert_match "Role cannot be removed as the role has associated forums and users", get_role_removal_denial_flash(teacher_role)
    admin_view = program.admin_views.find_by(default_view: [nil, AdminView::EDITABLE_DEFAULT_VIEWS].flatten)
    filter_params_hash = admin_view.filter_params_hash
    filter_params_hash[:roles_and_status][:role_filter_1][:roles] << RoleConstants::TEACHER_NAME
    admin_view.update_attributes!(filter_params: filter_params_hash.to_yaml)
    assert_match "Role cannot be removed as the role has associated forums and users and the role is tied to the following admin views", get_role_removal_denial_flash(teacher_role)
    program.teacher_users.destroy_all
    assert_match "Role cannot be removed as the role has associated forums and the role is tied to the following admin views", get_role_removal_denial_flash(teacher_role)
    forum.destroy
    assert_select_helper_function_block  "ul", get_role_removal_denial_flash(teacher_role) do
      assert_select "li", text: admin_view.title
    end
  end

  def test_get_data_hash_for_banner_logo
    program = programs(:albers)
    expects(:get_data_hash_for_dropzone).with(program.id, ProgramAsset::Type::LOGO, file_name: nil, uploaded_class: ProgramAsset.name, accepted_types: PICTURE_CONTENT_TYPES, class_list: "p-t-xxs", max_file_size: ProgramAsset::MAX_SIZE[ProgramAsset::Type::LOGO])
    get_data_hash_for_banner_logo(program, nil, ProgramAsset::Type::LOGO)
  end

  def test_get_send_request_badge_count
    assert_equal 0, get_send_request_badge_count(0, false)
    assert_equal 0, get_send_request_badge_count(1, true)
    @current_user = users(:mkr_student)
    assert_equal 0, get_send_request_badge_count(0, true)
    @current_user = users(:f_student)
    assert_equal 1, get_send_request_badge_count(0, true)
  end

  def test_program_settings_tabs
    @current_program = programs(:albers)
    @current_organization = programs(:org_primary)
    ProgramsHelperTest.any_instance.stubs(:super_console?).returns(true)
    content = program_settings_tabs(ProgramsController::SettingsTabs::GENERAL, Mentoring_Connection: _Mentoring_Connection)
    set_response_text(content)
    assert_select "div.inner_tabs" do
      assert_select "ul" do
        assert_select "a", text: "Features"
      end
      assert_select "ul" do
        assert_select "a", text: "Matching Settings"
      end
    end

    ProgramsHelperTest.any_instance.stubs(:super_console?).returns(false)
    content = program_settings_tabs(ProgramsController::SettingsTabs::GENERAL, Mentoring_Connection: _Mentoring_Connection)
    assert_no_match(/Features/, content)
  end

  def test_portal_settings_tabs
    @current_organization = programs(:org_nch)
    @current_program = programs(:primary_portal)
    ProgramsHelperTest.any_instance.stubs(:super_console?).returns(true)
    content = program_settings_tabs(ProgramsController::SettingsTabs::GENERAL, Mentoring_Connection: _Mentoring_Connection)
    set_response_text(content)
    assert_select "div.inner_tabs" do
      assert_select "ul" do
        assert_select "a", text: "Features"
      end
      assert_select "ul" do
        assert_select "a", { :count => 0, :html => /Matching Settings/ }
      end
      assert_select "ul" do
        assert_select "a", { :count => 0, :html => /Connection Settings/ }
      end
    end

    ProgramsHelperTest.any_instance.stubs(:super_console?).returns(false)
    content = program_settings_tabs(ProgramsController::SettingsTabs::GENERAL, Mentoring_Connection: _Mentoring_Connection)
    assert_no_match(/Features/, content)
  end

  def test_get_feedback_survey_options
    @current_program = programs(:albers)

    survey_options = get_feedback_survey_options
    assert_equal (@current_program.surveys.of_engagement_type.count + 1), survey_options.count
    assert survey_options.collect{|option| option[1]}.include?("new")
  end

  def test_render_header_alert
    assert_nil render_header_alert(nil)

    html_content = to_html(render_header_alert("some content"))
    assert_select html_content, "div#header_alert" do
      assert_select "div.centered_inner_content", test: "some content"
    end
  end

  def test_render_mentor_request_style_change_disabled_alert
    assert_nil render_mentor_request_style_change_disabled_alert(false, "Groups Note", 5)

    content = render_mentor_request_style_change_disabled_alert(true, "Groups Note", 5)
    assert_select_helper_function "div.help-block", content, text: "Groups Note"

    assert_match(/There are .*5 pending mentoring requests.* that would be lost on changing this setting. Please close the mentoring requests before proceeding/, render_mentor_request_style_change_disabled_alert(true, nil, 5))
  end

  def test_can_show_requests_notification_header_icon
    program = programs(:albers)
    user = users(:f_student)

    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(false)
    
    assert user.is_student?
    assert program.only_career_based_ongoing_mentoring_enabled?
    assert program.matching_by_mentee_alone?
    assert_false program.mentor_offer_enabled?
    assert_false program.matching_by_mentee_and_admin?
    assert_false program.calendar_enabled?
    assert can_show_requests_notification_header_icon?(program, user)

    assert_false can_show_requests_notification_header_icon?(nil, user)
    assert_false can_show_requests_notification_header_icon?(program, nil)

    user = users(:f_admin)

    assert_false user.is_student?
    assert_false user.is_mentor?

    assert_false can_show_requests_notification_header_icon?(program, user)

    user = users(:f_student)
    
    program.stubs(:only_career_based_ongoing_mentoring_enabled?).returns(false)
    program.enable_feature(FeatureName::CALENDAR)
    assert program.calendar_enabled?
    assert can_show_requests_notification_header_icon?(program, user)

    program.unstub(:only_career_based_ongoing_mentoring_enabled?)
    program.enable_feature(FeatureName::CALENDAR, false)
    assert_false program.calendar_enabled?
    program.stubs(:matching_by_mentee_alone?).returns(false)
    program.stubs(:matching_by_mentee_and_admin?).returns(true)
    assert can_show_requests_notification_header_icon?(program, user)

    user = users(:f_mentor)

    assert_false user.is_student?
    assert_false can_show_requests_notification_header_icon?(program, user)

    program.unstub(:matching_by_mentee_and_admin?)
    assert_false can_show_requests_notification_header_icon?(program, user)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    assert program.mentor_offer_needs_acceptance?
    assert can_show_requests_notification_header_icon?(program, user)

    program.update_attribute(:mentor_offer_needs_acceptance, false)
    assert_false can_show_requests_notification_header_icon?(program, user)

    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)

    assert can_show_requests_notification_header_icon?(program, user)
    program = programs(:pbe)
    program.stubs(:can_be_shown_meetings_listing?).returns(false)
    program.stubs(:calendar_enabled?).returns(false)
    assert_false can_show_requests_notification_header_icon?(program, users(:f_admin_pbe))
    assert can_show_requests_notification_header_icon?(program, users(:f_student_pbe))
  end

  def test_home_page_widget_group_logo
    html_content = to_html(home_page_widget_group_logo(groups(:mygroup), :img_class => "img_class"))
    assert_select html_content, "div" do
      assert_select "div.member_box" do
        assert_select "img.photo.group_logo.img-circle.img_class"
        assert_select "img[width='75']"
        assert_select "img[height='75']"
      end
    end

    html_content = to_html(home_page_widget_group_logo(groups(:mygroup), :img_class => "img_class", :size => "25x25"))
    assert_select html_content, "div" do
      assert_select "div.member_box" do
        assert_select "img.photo.group_logo.img-circle.img_class"
        assert_select "img[width='25']"
        assert_select "img[height='25']"
      end
    end
  end

  def test_allowed_tabs
    @current_organization = programs(:org_primary)
    @current_program = programs(:albers)
    self.stubs(:super_console?).returns(false)
    assert_equal_unordered [ProgramsController::SettingsTabs::GENERAL, ProgramsController::SettingsTabs::MEMBERSHIP, ProgramsController::SettingsTabs::CONNECTION, ProgramsController::SettingsTabs::PERMISSIONS, ProgramsController::SettingsTabs::MATCHING], allowed_tabs
    @current_organization.update_attribute(:subscription_type, Organization::SubscriptionType::BASIC)
    @current_organization.make_subscription_changes
    @current_program.make_subscription_changes
    assert_equal_unordered [ProgramsController::SettingsTabs::GENERAL, ProgramsController::SettingsTabs::MEMBERSHIP, ProgramsController::SettingsTabs::CONNECTION, ProgramsController::SettingsTabs::MATCHING], allowed_tabs
  end

  def test_get_community_item_klass
    topic = create_topic(title: "New Topic", body: "sample topic content")
    assert_equal Article.to_s, get_community_item_klass(Article.first)
    assert_equal Topic.to_s, get_community_item_klass(topic)
    assert_equal QaQuestion.to_s, get_community_item_klass(QaQuestion.first)
    assert_equal Forum.to_s, get_community_item_klass(Forum.first)
  end

  def test_get_new_community_item_link_html
    assert_equal link_to(content_tag(:i, "", class: "fa fa-plus-circle fa-fw m-r-xxs") + "feature.article.action.write_new".translate(Article: _Article), new_article_path(src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET)), get_new_community_item_link_html({klass: Article.to_s})
    assert_equal link_to(content_tag(:i, "", class: "fa fa-plus-circle fa-fw m-r-xxs") + "feature.question_answers.action.ask_new_question".translate, qa_questions_path(add_new_question: true, src: EngagementIndex::Src::MENTORING_COMMUNITY_WIDGET)), get_new_community_item_link_html({klass: QaQuestion.to_s})
  end

  def test_get_new_community_item_icon_color
    assert_equal "text-success", get_new_community_item_icon_color(Article.to_s)
    assert_equal "text-navy", get_new_community_item_icon_color(Topic.to_s)
    assert_equal "text-warning", get_new_community_item_icon_color(QaQuestion.to_s)
    assert_equal "text-navy", get_new_community_item_icon_color(Forum.to_s)
  end

  def test_get_new_community_item_icon_class
    assert_equal "fa-file-text", get_new_community_item_icon_class(Article.to_s)
    assert_equal "fa-comment", get_new_community_item_icon_class(Topic.to_s)
    assert_equal "fa-question", get_new_community_item_icon_class(QaQuestion.to_s)
    assert_equal "fa-comments", get_new_community_item_icon_class(Forum.to_s)
  end

  def test_get_community_item_icon_content
    klass = "klass"

    self.stubs(:get_new_community_item_icon_color).with(klass).returns("icon_color")
    self.stubs(:get_new_community_item_icon_class).with(klass).returns("icon_class")

    content = get_community_item_icon_content(klass, {class: "some_class"})
    set_response_text(content)

    assert_select "span.fa-stack.fa-lg.fa-2x.some_class.icon_color" do
      assert_select "i.fa.fa-circle.fa-stack-2x"
      assert_select "i.fa.icon_class.fa-stack-1x.fa-inverse"
    end
  end

  def test_render_new_community_item_content
    item_hash = {klass: "klass"}
    self.stubs(:get_community_item_icon_content).with("klass", {:class => "m-b"}).returns("<span>icon content</span>".html_safe)
    self.stubs(:get_new_community_item_link_html).with(item_hash).returns("some content")

    content = render_new_community_item_content(item_hash)
    set_response_text(content)

    assert_select "span", text: "icon content"
    assert_select "div.height-94", text: "some content"
  end

  def test_render_zero_match_score_settings
    form = mock()
    form.stubs(:check_box).returns("")
    stub_current_program(programs(:albers))

    # Prevent manager and past mentor matching setting
    result = render_zero_match_score_settings(form)
    assert_select_helper_function_block "div.form-group.form-group-sm", result do
      assert_select "div.control-label", text: 'Show 0% match-scores if'
      assert_select "div.controls" do
        assert_select "label.checkbox.pull-left", text: "Mentor is mentees manager.Restrict upto"
        assert_select "label.font-noraml" do
          assert_select "div.col-sm-4.no-padding" do
            assert_select "input#program_manager_matching_level"
          end
        end
        assert_select "label.checkbox.m-t-xs"
        assert_select "div.text-muted", text: "Recompute match scores in match config page after updating the above settings. Please allow 10 minutes approx for the system to recompute the scores."
      end
    end

    # Past mentor matching setting
    current_program.organization.stubs(:manager_enabled?).returns(false)
    result = render_zero_match_score_settings(form)
    assert_select_helper_function_block "div.form-group.form-group-sm", result do
      assert_select "div.control-label", text: 'Show 0% match-scores if'
      assert_select "label.checkbox.pull-left", text: "Mentor is mentees manager.Restrict upto", count: 0
      assert_select "label.checkbox.m-t-xs"
      assert_select "div.text-muted", text: "Recompute match scores in match config page after updating the above settings. Please allow 10 minutes approx for the system to recompute the scores."
    end

    # Prevent manager matching setting
    current_program.organization.stubs(:manager_enabled?).returns(true)
    current_program.stubs(:ongoing_mentoring_enabled?).returns(false)
    result = render_zero_match_score_settings(form)
    assert_select_helper_function_block "div.form-group.form-group-sm", result do
      assert_select "div.control-label", text: 'Show 0% match-scores if'
      assert_select "div.controls" do
        assert_select "label.checkbox.pull-left", text: "Mentor is mentees manager.Restrict upto"
        assert_select "label.font-noraml" do
          assert_select "div.col-sm-4.no-padding" do
            assert_select "input#program_manager_matching_level"
          end
        end
        assert_select "label.checkbox.m-t-xs", count: 0
        assert_select "div.text-muted", text: "Recompute match scores in match config page after updating the above settings. Please allow 10 minutes approx for the system to recompute the scores.", count: 0
      end
    end

    current_program.organization.stubs(:manager_enabled?).returns(false)
    assert_equal "", render_zero_match_score_settings(form)
  end

  def test_get_connection_limit_help_text
    program = programs(:albers)
    program.stubs(:matching_by_admin_alone?).returns(true)
    program.stubs(:mentor_offer_enabled?).returns(false)

    assert_equal "Limit includes mentees with whom they are connected as well as drafted", get_connection_limit_help_text(program)

    program.stubs(:mentor_offer_enabled?).returns(true)
    assert_equal "Limit includes mentees with whom they are connected as well as mentees whose request to connect are pending", get_connection_limit_help_text(program)

    program.stubs(:mentor_offer_enabled?).returns(false)
    program.stubs(:matching_by_admin_alone?).returns(false)
    assert_equal "Limit includes mentees with whom they are connected as well as mentees whose request to connect are pending", get_connection_limit_help_text(program)
  end

  def test_match_score_label
    match_score = 0
    assert_equal "feature.user.label.ignored".translate, match_score_label(match_score, false, true)

    match_score = 100
    assert_equal "feature.user.label.ignored".translate, match_score_label(match_score, false, true)

    match_score = 100
    assert_equal "feature.user.label.ignored".translate, match_score_label(match_score, true, true)

    match_score = 100
    assert_equal "100%", match_score_label(match_score, true, false)
  end

  def test_zero_match_score_message_label
    content = zero_match_score_message_label
    assert_match "Message when match score is 0%", content
    assert_select_helper_function "i.fa.fa-info-circle#not_a_match_help_text", content
  end

  def test_render_max_connections_limit
    form = temp_form_object(User)
    program = programs(:albers)
    assert_select_helper_function_block("div.m-t-xs", render_max_connections_limit(form, program, text_field_id: "user_max_connections_limit", wrapper_class: "m-t-xs")) do
      assert_select "label[for='user_max_connections_limit']", text: "Connections Limit"
      assert_select "div.controls.col-sm-10" do
        assert_select "input#user_max_connections_limit"
        assert_select "p.help-block", text: "Maximum number of students you can connect with at any time."
      end
    end
  end

  def test_render_help_text_for_max_connections_limit
    program = programs(:albers)
    assert_select_helper_function("p.help-block", render_help_text_for_max_connections_limit(program, from_first_visit: true), text: "Maximum number of students you can connect with at any time. This can be adjusted later in your account settings.")
    assert_select_helper_function("p.help-block", render_help_text_for_max_connections_limit(program, from_member_profile: true), text: "Maximum number of students you can connect with at any time.")
    program.stubs(:allow_mentor_update_maxlimit?).returns(false)
    assert_select_helper_function("p.help-block", render_help_text_for_max_connections_limit(program, from_member_profile: true), text: "Maximum number of students you can connect with at any time. Please note that this setting is not visible to the user and the default limit for mentors in this program has been set to 5")
    assert_select_helper_function("p.help-block", render_help_text_for_max_connections_limit(program), text: "Maximum number of students you can connect with at any time.")
  end

  def test_render_add_role_without_approval_help_text
    program = programs(:albers)
    mentor_role = roles("#{program.id}_mentor")
    mentee_role = roles("#{program.id}_student")
    content = render_add_role_without_approval_help_text(mentee_role, mentor_role)
    assert_select_helper_function "i.fa.fa-info-circle#auto_approval_for_student_help_icon", content
    assert_select_helper_function "script", content, text: "\n//<![CDATA[\njQuery(\"#auto_approval_for_student_help_icon\").tooltip({html: true, title: '<div>Lets users with current role as student add mentor role without admin approval</div>', placement: \"top\", container: \"#auto_approval_for_student_help_icon\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#auto_approval_for_student_help_icon\").on(\"remove\", function () {jQuery(\"#auto_approval_for_student_help_icon .tooltip\").hide().remove();})\n//]]>\n"

    content = render_add_role_without_approval_help_text(mentor_role, mentee_role)
    assert_select_helper_function "i.fa.fa-info-circle#auto_approval_for_mentor_help_icon", content
    assert_select_helper_function "script", content, text: "\n//<![CDATA[\njQuery(\"#auto_approval_for_mentor_help_icon\").tooltip({html: true, title: '<div>Lets users with current role as mentor add student role without admin approval</div>', placement: \"top\", container: \"#auto_approval_for_mentor_help_icon\", delay: { \"show\" : 500, \"hide\" : 100 } } );jQuery(\"#auto_approval_for_mentor_help_icon\").on(\"remove\", function () {jQuery(\"#auto_approval_for_mentor_help_icon .tooltip\").hide().remove();})\n//]]>\n"
  end

  def test_get_project_requests_quick_link
    program = programs(:albers)
    new_project_requests_count = 1
    assert_nil get_project_requests_quick_link(program, new_project_requests_count)

    program = programs(:pbe)
    @current_user = users(:f_admin_pbe)
    assert_nil get_project_requests_quick_link(program, new_project_requests_count)

    @current_user = users(:f_student_pbe)
    expects(:quick_link).with("Mentoring Connections Requests", project_requests_path(from_quick_link: true, src: EngagementIndex::Src::BrowseMentors::HEADER_NAVIGATION), "fa fa-user-plus fa-fw p-r-md", new_project_requests_count, { notification_icon_view: true, class: "normal-white-space break-word-all" })
    get_project_requests_quick_link(program, new_project_requests_count)
  end

  def test_get_tabs_for_listing
    url = "Url"
    label_tab_mapping = { "l1" => "t1", "l2" => "t2", "l3" => "t3" }
    active_tab = "l1"
    label_tab_mapping.each do |label, tab|
      expects(:get_tab_for_listing).with(label, tab == active_tab, { url: url, status: tab })
    end
    get_tabs_for_listing(label_tab_mapping, active_tab, url: url, param_name: :status)
  end

  def test_get_tab_for_listing
    label = "Labe1"
    active = true
    data = { url: "Url", status: "status" }
    assert_equal ({
      label: content_tag(:span, label),
      url: "javascript:void(0)",
      active: active,
      tab_class: "cjs_common_report_tab",
      link_options: { data: data }
    }), get_tab_for_listing(label, active, data)

    label = "Labe2"
    active = false
    data = { url: "Url2", tab: "tab" }
    assert_equal ({
      label: content_tag(:span, label),
      url: "javascript:void(0)",
      active: active,
      tab_class: "cjs_common_report_tab",
      link_options: { data: data }
    }), get_tab_for_listing(label, active, data)
  end

  private

  def _mentor
    "mentor"
  end

  def _mentee
    "mentee"
  end

  def _program
    "program"
  end

  def _mentoring_connection
    "mentoring connection"
  end

  def _mentoring_connections
    "mentoring connections"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _Mentoring_Connections
    "Mentoring Connections"
  end

  def _a_article
    "a resource"
  end

  def _article
    "resource"
  end

  def _Article
    "Resource"
  end

  def _articles
    "resources"
  end

  def _Articles
    "Resources"
  end

  def _admin
    "admin"
  end

  def _mentors
    "mentors"
  end

  def _mentees
    "mentees"
  end

  def _Admins
    "Admins"
  end

  def _Admin
    "Admin"
  end

  def _Mentoring
    "Mentoring"
  end

  def _meeting
    "meeting"
  end

  def _mentoring
    "mentoring"
  end

  def _Mentor
    "Mentor"
  end
end
