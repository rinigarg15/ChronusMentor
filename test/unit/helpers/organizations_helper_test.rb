require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/organizations_helper"

class OrganizationsHelperTest < ActionView::TestCase
  def test_get_ip_container_with_ip_address
    output = get_ip_container(IPAddr.new('127.0.0.1'), true)
    set_response_text(output)
    assert_select 'div.has-below' do
      assert_select 'input.has-next.form-control', count: 2
      assert_select 'input.has-next.form-control[value=?]', '127.0.0.1', count: 1
    end
  end

  def test_get_ip_container_with_range
    output = get_ip_container(IPAddr.new('127.0.0.101')..IPAddr.new('127.0.0.202'), true)
    set_response_text(output)
    assert_select 'div.has-below' do
      assert_select 'input.has-next.form-control', count: 2
      assert_select "input.has-next.form-control[value='127.0.0.101']", count: 1
      assert_select "input.has-next.form-control[value='127.0.0.202']", count: 1
    end
  end

  def test_get_page_action_for_multi_track_admin
    assert_equal ({label: "Activities Dashboard", url: root_organization_path(activities_dashboard: true), class: "btn btn-primary btn-large"}), get_page_action_for_multi_track_admin(true)
    assert_equal ({label: "Global Dashboard", url: root_organization_path, class: "btn btn-primary btn-large"}), get_page_action_for_multi_track_admin(false)
  end

  def test_prepare_disabled_list
    org = programs(:org_primary)
    prog = programs(:albers)
    org.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    assert_equal FeatureName.dependent_features[FeatureName::MENTORING_CONNECTIONS_V2].values.flatten+[FeatureName::MANAGER, FeatureName::CAMPAIGN_MANAGEMENT], prepare_disabled_list(org)
    assert_equal FeatureName.dependent_features[FeatureName::MENTORING_CONNECTIONS_V2].values.flatten+[FeatureName::MANAGER, FeatureName::CAMPAIGN_MANAGEMENT], prepare_disabled_list(prog)

    prog.update_attribute(:engagement_type, Program::EngagementType::PROJECT_BASED)
    assert prog.project_based?
    assert_equal FeatureName.dependent_features[FeatureName::MENTORING_CONNECTIONS_V2].values.flatten+FeatureName.specific_dependent_features[:project_based].values.flatten+[FeatureName::MANAGER, FeatureName::CAMPAIGN_MANAGEMENT], prepare_disabled_list(prog)

    prog.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_false prog.project_based?
    assert_equal FeatureName.dependent_features[FeatureName::MENTORING_CONNECTIONS_V2].values.flatten+[FeatureName::MANAGER, FeatureName::CAMPAIGN_MANAGEMENT], prepare_disabled_list(prog)

    org.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    org.profile_questions.where(question_type: ProfileQuestion::Type::MANAGER).destroy_all
    assert_equal [FeatureName::CAMPAIGN_MANAGEMENT], prepare_disabled_list(org)
    assert_equal [FeatureName::CAMPAIGN_MANAGEMENT], prepare_disabled_list(prog.reload)
    prog.user_campaigns.destroy_all
    assert_equal [], prepare_disabled_list(prog.reload)

    role = prog.roles.first
    role.update_attributes(eligibility_rules: true, membership_request: false, join_directly: false, join_directly_only_with_sso: false, invitation: false)
    assert_equal [], prepare_disabled_list(org)
    assert prepare_disabled_list(prog.reload).include?(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES)
  end

  def test_rollup_box_wrapper
    expects(:tooltip).with("title_tooltip_class", "title_tooltip", false, is_identifier_class: true, placement: 'bottom').never
    content = rollup_box_wrapper {'block content'}
    assert_select_helper_function_block "div.cjs_current_status_tiles", content do
      assert_select "h4", text: "title", count: 0
      assert_select "span.title_tooltip_class", html: get_icon_content('fa fa-info-circle text-info'), count: 0
      assert_select "div.row" do
        "block content"
      end
    end
    expects(:tooltip).with("title_tooltip_class", "title_tooltip", false, is_identifier_class: true, placement: 'bottom').never
    content = rollup_box_wrapper(title: "title") {'block content'}
    assert_select_helper_function_block "div.cjs_current_status_tiles", content do
      assert_select "h4", text: "title"
      assert_select "span.title_tooltip_class", html: get_icon_content('fa fa-info-circle text-info'), count: 0
      assert_select "div.row" do
        "block content"
      end
    end
    expects(:tooltip).with("title_tooltip_class", "title_tooltip", false, is_identifier_class: true, placement: 'bottom').once
    content = rollup_box_wrapper(title: "title", title_tooltip: "title_tooltip", title_tooltip_class: "title_tooltip_class") {'block content'}
    assert_select_helper_function_block "div.cjs_current_status_tiles", content do
      assert_select "h4", text: "title"
      assert_select "span.title_tooltip_class", html: get_icon_content('fa fa-info-circle text-info')
      assert_select "div.row" do
        "block content"
      end
    end
  end

  def test_rollup_body_box
    assert_select_helper_function_block "div.box_grid_class", rollup_body_box(box_grid_class: "box_grid_class", text_number: 11, right_addon: content_tag(:span, "right addon", class: "right_addon_class")) do
      assert_select "i.text-navy"
      assert_select "span", text: "11"
      assert_select "a", count: 0
      assert_select "span.right_addon_class", text: "right addon"
    end

    assert_select_helper_function_block "div.box_grid_class", rollup_body_box(box_grid_class: "box_grid_class", text_number: 11) do
      assert_select "i.text-navy"
      assert_select "span", text: "11"
      assert_select "a", count: 0
    end

    assert_select_helper_function_block "div.col-xs-12", rollup_body_box(box_icon_class: "box_icon_class", link_number: 7, link_number_path: "/path") do
      assert_select "i.text-navy.box_icon_class"
      assert_select "a.h2", text: "7", href: "/path"
    end

    assert_select_helper_function_block "div.col-xs-12", rollup_body_box(link_number: 5, link_number_path: "/path1", link_number_additional_html: content_tag(:span, "abc")) do
      assert_select "a.h2", text: "5 abc", href: "/path" do
        assert_select "span", text: "abc"
      end
    end
  end

  def test_rollup_body_sub_boxes
    data_array = [{title: "title", content: "content"}]
    assert_select_helper_function "div.col-xs-12", rollup_body_sub_boxes(data_array)

    data_array << {title: "title1", content: "content1"}
    assert_select_helper_function "div.col-xs-6", rollup_body_sub_boxes(data_array)
  end

  def test_rollup_body_sub_box
    data = {title: "title", content: "content"}
    assert_select_helper_function_block "div.col-xs-12", rollup_body_sub_box(data, default_col_class: "col-xs-12") do
      assert_select "div", text: "title"
      assert_select "h4", text: "content"
    end

    data = {title: "title", content: "content", box_grid_class: "col-xs-4"}
    assert_select_helper_function_block "div.col-xs-4", rollup_body_sub_box(data, default_col_class: "col-xs-12") do
      assert_select "div", text: "title"
      assert_select "h4", text: "content"
    end
  end

  def test_program_license_summary
    program = programs(:albers)
    assert_match "#{program.all_users.active.size} active users in the program", program_license_summary(program, "program")

    program.update_attribute(:number_of_licenses, 1000)
    assert_match "#{program.all_users.active.size} of 1000 licenses are in use", program_license_summary(program, "program")
  end

  def test_display_user_states_in_program
    user = users(:inactive_user)
    program = programs(:psg)
    assert user.suspended?

    content = display_user_states_in_program(program, ["mentor"], " (Deactivated)")
    assert_match "Mentor (Deactivated)", content

    content = display_user_states_in_program(program, ["student"], " (Pending)")
    assert_match "Student (Pending)", content

    content = display_user_states_in_program(program, ["mentor"], "")
    assert_match "Mentor", content
  end

  def test_display_user_actions_in_program
    user = users(:inactive_user)
    program = programs(:psg)
    mentor_role = program.find_role RoleConstants::MENTOR_NAME
    student_role = program.find_role RoleConstants::STUDENT_NAME
    assert user.suspended?

    options = { program_roles: [mentor_role, student_role], prog_mem_req_pending_roles: [student_role] }
    content = display_user_actions_in_program(user, program, options)
    assert_match "Join Program", content

    mentor_role.stubs(:membership_request?).returns(false)
    student_role.stubs(:membership_request?).returns(false)
    content = display_user_actions_in_program(user, program, options)
    assert_match /Join Program/, content

    student_role.stubs(:membership_request?).returns(true)
    options[:program_roles] = [student_role]
    content = display_user_actions_in_program(user, program, options)
    assert_no_match /Join Program/, content

    user.update_attribute(:state, User::Status::ACTIVE)
    content = display_user_actions_in_program(user, program, options)
    assert_no_match /Join Program/, content
  end

  def test_get_features_to_hide
    program = programs(:albers)
    standalone_program = programs(:no_subdomain)

    result = get_features_to_hide(program)
    assert_equal_unordered (FeatureName.removed_as_feature_from_ui + FeatureName.organization_level_features), result

    program.update_attributes(engagement_type: Program::EngagementType::CAREER_BASED)
    result = get_features_to_hide(program)
    assert_equal_unordered (FeatureName.removed_as_feature_from_ui + FeatureName.organization_level_features + FeatureName.ongoing_mentoring_related_features), result

    result = get_features_to_hide(program.organization)
    assert_equal FeatureName.removed_as_feature_from_ui, result

    result = get_features_to_hide(standalone_program)
    assert_equal FeatureName.removed_as_feature_from_ui, result
  end

  def test_render_editable_feature
    program = programs(:albers)

    response = render_editable_feature(program, FeatureName::LINKEDIN_IMPORTS, "organization[enabled_features][]", [])
    assert_select_helper_function "div.fixed-checkbox-offset", response, text: "Enable users to import work experience from their LinkedIn profiles"
  end

  def test_error_messages_for_regions
    expected_hash = {"us"=>"For hosting in US region, please use <a target=\"_blank\" href=\"https://mentor.chronus.com\">mentor.chronus.com</a>", "europe"=>"For hosting in Europe region, please use <a target=\"_blank\" href=\"https://mentoreu.chronus.com\">mentoreu.chronus.com</a>"}

    assert_equal expected_hash, JSON.parse(error_messages_for_regions)
  end

  def test_render_selected_region_alert
    assert_nil render_selected_region_alert
    self.stubs(:can_render_select_region?).returns(true)
    assert_select_helper_function "div#cjs_selected_region_alert", render_selected_region_alert, text: ""
  end

  def test_display_alert_messages_for_regions
    expected_hash = {"us"=>"You are creating organization in US region", "europe"=>"You are creating organization in Europe region"}

    assert_equal expected_hash, JSON.parse(display_alert_messages_for_regions)
  end

  private

  def _admin
    "admin"
  end

  def _Program
    "Program"
  end
end
