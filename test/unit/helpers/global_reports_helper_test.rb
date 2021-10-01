require_relative './../../test_helper.rb'
class GlobalReportsHelperTest < ActionView::TestCase
  include MeetingsHelper

  def test_get_percentage_difference_rollup
    assert_equal "", get_percentage_difference_rollup({current: 2, previous: nil})
    assert_equal "", get_percentage_difference_rollup({current: 2})

    self.stubs(:rollup_body_sub_boxes).returns("rollup")
    assert_equal "rollup", get_percentage_difference_rollup({current: 2, previous: 1})
  end

  def test_get_engagement_stats
    assert_nil get_engagement_stats({messages: {current: 12}, meetings: {current: [12]}}, :previous)
    assert_equal 23, get_engagement_stats({messages: {current: 12}, meetings: {current: [12]}, posts: {current: 10}}, :current)
  end

  def test_get_percentage_difference_between_time_periods
    content = get_percentage_difference_between_time_periods({current: 2, previous: 1})
    assert_select_helper_function_block "span", content, {text: "100% compared to previous time period"} do
      assert_select "span.text-navy", text: "100%"
      assert_select "i.fa-caret-up"
    end

    content = get_percentage_difference_between_time_periods({current: 1, previous: 1})
    assert_select_helper_function_block "span", content, {text: "0% compared to previous time period"} do
      assert_select "span.text-warning", text: "0%"
      assert_select "i.fa-unsorted"
    end

    content = get_percentage_difference_between_time_periods({current: 0, previous: 1})
    assert_select_helper_function_block "span", content, {text: "100% compared to previous time period"} do
      assert_select "span.text-danger", text: "100%"
      assert_select "i.fa-caret-down"
    end
  end

  def test_get_actions_for_users_satisfaction_configuration
    self.stubs(:super_console?).returns(false)
    content = get_actions_for_users_satisfaction_configuration
    assert_select_helper_function_block "span.pull-right", content do
      assert_select_helper_function_block "a[data-click=\"jQueryShowQtip('', '', '/global_reports/overall_impact_survey_satisfaction_configurations', {}, {largeModal: true});\"][href=\"javascript:void(0)\"]", content do
        assert_select "i.fa-cog.text-info"
      end
    end

    self.stubs(:super_console?).returns(true)
    content = get_actions_for_users_satisfaction_configuration
    assert_select_helper_function_block "span.pull-right", content do
      assert_select_helper_function_block "a[data-click=\"jQueryShowQtip('', '', '/global_reports/overall_impact_survey_satisfaction_configurations', {}, {largeModal: true});\"][href=\"javascript:void(0)\"]", content do
        assert_select "i.fa-cog.text-info"
      end
      assert_select "i.fa-exclamation-triangle.text-warning.hide.cjs_survey_satisfaction_warning_for_super_admin"
    end
  end

  def test_get_survey_satisfaction_configuration_state
    program = programs(:albers)
    survey = program.surveys.first

    hash = {program_name: program.name, surveys: [survey], config: nil, program_outcomes_feature_enabled: true}
    assert_match "<span>Based on the responses from <a href=\"/p/albers/surveys/90/survey_questions\">Introduce yourself</a>.</span>", get_survey_satisfaction_configuration_state(hash)
    
    hash = {program_name: program.name, surveys: [survey], config: true, program_outcomes_feature_enabled: true}
    assert_match "<span>Based on the responses from <a href=\"/p/albers/surveys/90/survey_questions\">Introduce yourself</a>.</span>", get_survey_satisfaction_configuration_state(hash)

    hash = {program_name: program.name, surveys: [survey], config: false, program_outcomes_feature_enabled: true}
    assert_match "<span class=\"label\"><i class=\"fa fa-eye-slash fa-fw m-r-xs\"></i> Ignored</span>", get_survey_satisfaction_configuration_state(hash)

    hash = {program_name: program.name, surveys: [], config: false, program_outcomes_feature_enabled: true}
    assert_match "<span class=\"label\"><i class=\"fa fa-eye-slash fa-fw m-r-xs\"></i> Ignored</span>", get_survey_satisfaction_configuration_state(hash)

    hash = {program_name: program.name, surveys: [], config: nil, program_outcomes_feature_enabled: true}
    assert_match "<span class=\"label label-danger\"><i class=\"fa fa-exclamation-triangle fa-fw m-r-xs\"></i> Not configured Yet</span>", get_survey_satisfaction_configuration_state(hash)

    hash = {program_name: program.name, surveys: [], config: true, program_outcomes_feature_enabled: true}
    assert_match "<span class=\"label label-danger\"><i class=\"fa fa-exclamation-triangle fa-fw m-r-xs\"></i> Not configured Yet</span>", get_survey_satisfaction_configuration_state(hash)
  end

  def test_get_survey_satisfaction_configuration_actions
    program = programs(:albers)
    survey = program.surveys.first

    hash = {program_name: program.name, surveys: [survey], config: nil, program_outcomes_feature_enabled: false}
    self.stubs(:super_console?).returns(false)
    content = get_survey_satisfaction_configuration_actions(program.id, hash)
    assert_match "/p/albers/session/zendesk", content
    assert_match "Support", content

    self.stubs(:super_console?).returns(true)
    content = get_survey_satisfaction_configuration_actions(program.id, hash)
    assert_equal "<span class=\"pull-right\"><a href=\"/p/albers/edit?tab=4\">Enable Program Outcomes Report</a></span>", content

    hash = {program_name: program.name, surveys: [survey], config: false, program_outcomes_feature_enabled: true}
    content = get_survey_satisfaction_configuration_actions(program.id, hash)
    assert_select_helper_function_block "span.p-r-xs", content do
      assert_select_helper_function_block "a[data-click=\"jQuery.ajax({url: '/global_reports/update_overall_impact_survey_satisfaction_configuration?program_id=#{program.id}&reconsider=true', method: 'PUT'});\"][href=\"javascript:void(0)\"]", content, text: "Reconsider" do
        assert_select "i.fa-eye"
      end
    end

    hash = {program_name: program.name, surveys: [survey], config: nil, program_outcomes_feature_enabled: true}
    content = get_survey_satisfaction_configuration_actions(program.id, hash)
    assert_select_helper_function_block "span.p-r-xs:first", content do
      assert_select_helper_function_block "a[data-click=\"jQuery.ajax({url: '/global_reports/update_overall_impact_survey_satisfaction_configuration?ignore=true&program_id=#{program.id}', method: 'PUT'});\"][href=\"javascript:void(0)\"]", content, text: "Ignore" do
        assert_select "i.fa-eye-slash"
      end
    end
    assert_select_helper_function_block "span.p-r-xs:last", content do
      assert_select_helper_function_block "a[data-click=\"jQuery.ajax({url: '/global_reports/edit_overall_impact_survey_satisfaction_configuration?program_id=#{program.id}'});\"][href=\"javascript:void(0)\"]", content, text: "Configure" do
        assert_select "i.fa-cog"
      end
    end
  end

  def test_show_super_admin_configration_missing_warning
    hash = {surveys: ["some text"], config: nil, program_outcomes_feature_enabled: false}
    assert show_super_admin_configration_missing_warning?(hash)

    hash = {surveys: ["some text"], config: nil, program_outcomes_feature_enabled: true}
    assert_false show_super_admin_configration_missing_warning?(hash)

    hash = {surveys: [], config: false, program_outcomes_feature_enabled: true}
    assert_false show_super_admin_configration_missing_warning?(hash)
  end

  def test_overall_impact_loader
    content = overall_impact_loader
    assert_select_helper_function_block "div.m-t-xs.m-b-xs.p-b-sm", content do
      assert_select "div.sk-spinner.sk-spinner-wave"
    end
  end

  def test_get_engagement_tooltip_content
    assert_equal ["3 messages"], get_engagement_tooltip_content({messages: {current: 3}, posts: {current: 0}, meetings: {current: []}})
    assert_equal ["3 posts"], get_engagement_tooltip_content({messages: {current: 0}, posts: {current: 3}, meetings: {current: []}})
    assert_equal ["3 meetings"], get_engagement_tooltip_content({messages: {current: 0}, posts: {current: 0}, meetings: {current: [1, 2, 3]}})
    assert_equal ["1 message", "3 meetings"], get_engagement_tooltip_content({messages: {current: 1}, posts: {current: 0}, meetings: {current: [1, 2, 3]}})
  end
end