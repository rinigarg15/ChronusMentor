module GlobalReportsHelper

  def get_percentage_difference_rollup(count_hash)
    return "" if count_hash[:previous].blank?
    data_array = [{content: get_percentage_difference_between_time_periods(count_hash), additional_class: "light-gray-bg p-t-xxs"}]
    rollup_body_sub_boxes(data_array, additional_class: "animated fadeInDown")
  end

  def get_engagement_stats(engagement_created_hash, time_period_symbol)
    return nil if ((time_period_symbol == :previous) && engagement_created_hash[:meetings][time_period_symbol].nil?)
    engagement_created_hash[:messages][time_period_symbol] + engagement_created_hash[:posts][time_period_symbol] + engagement_created_hash[:meetings][time_period_symbol].size
  end

  def get_engagement_tooltip_content(engagement_created_hash)
    engagement_counts_hash = {messages: engagement_created_hash[:messages][:current], posts: engagement_created_hash[:posts][:current], meetings: engagement_created_hash[:meetings][:current].length}
    engagement_count_messages = []
    engagement_counts_hash.each do |key, value|
      engagement_count_messages << "feature.global_reports.overall_impact.content.#{key}".translate(count: value) if (value > 0)
    end
    engagement_count_messages
  end

  def get_percentage_difference_between_time_periods(count_hash)
    current_count, previous_count = [count_hash[:current], count_hash[:previous]]
    content = get_safe_string
    percentage = ReportsFilterService.get_percentage_change(previous_count, current_count)
    content_tag(:span, class: "small font-bold") do
      content << "#{percentage.abs}%"
      content << get_caret(percentage)
      "feature.global_reports.overall_impact.content.precentage_difference_html".translate(percentage_difference: content_tag(:span, content, class: "font-600 big #{get_caret_class(percentage)}"))
    end
  end

  def get_actions_for_users_satisfaction_configuration
    content = get_safe_string
    content << get_icon_content("fa fa-exclamation-triangle text-warning hide cjs_survey_satisfaction_warning_for_super_admin") if super_console?
    content << positive_outcome_configuration_link(get_icon_content("fa fa-cog text-info"))
    content_tag(:span, content, class: "pull-right")
  end

  def get_survey_satisfaction_configuration_state(survey_satisfaction_configuration_hash)
    if survey_satisfaction_configured?(survey_satisfaction_configuration_hash)
      render_more_less("feature.global_reports.overall_impact.content.based_on_surveys_list_html".translate(surveys_list: to_sentence_sanitize(survey_satisfaction_configuration_hash[:surveys].map{|survey| link_to(survey.name, survey_survey_questions_path(survey, root: survey.program.root))}, last_word_connector: " #{"display_string.and".translate} ")), 150)
    else
      get_ignored_or_not_configured_state(survey_satisfaction_configuration_hash)
    end
  end

  def get_survey_satisfaction_configuration_actions(program_id, survey_satisfaction_configuration_hash)
    if program_outcomes_feature_disabled?(survey_satisfaction_configuration_hash)
      program_outcomes_feature_disabled_action(program_id)
    elsif survey_satisfaction_configuration_ignored?(survey_satisfaction_configuration_hash[:config])
      content_tag(:span, update_survey_satisfaction_configuration_path({key: "reconsider", icon: "fa-eye", button_class: "btn-default"}, {program_id: program_id, reconsider: true}), class: "p-r-xs pull-right")
    else
      content_tag(:span, link_to_function("feature.global_reports.overall_impact.action.configure_html".translate(icon: get_icon_content("fa fa-cog")), "jQuery.ajax({url: '#{edit_overall_impact_survey_satisfaction_configuration_global_reports_path(program_id: program_id)}'});", class: "btn btn-xs btn-outline btn-info"), class: "p-r-xs pull-right m-b-xs") + 
      content_tag(:span, update_survey_satisfaction_configuration_path({key: "ignore", icon: "fa-eye-slash", button_class: "btn-default"}, {program_id: program_id, ignore: true}), class: "p-r-xs pull-right m-b-xs") 
    end
  end

  def show_super_admin_configration_missing_warning?(survey_satisfaction_configuration_hash)
    program_outcomes_feature_disabled?(survey_satisfaction_configuration_hash) || survey_satisfaction_not_configured?(survey_satisfaction_configuration_hash)
  end

  def safe_percentage(numerator, denominator)
    result = numerator.fdiv(denominator)
    return 0 if result.nan?
    return 100 if (result.infinite? == 1)
    (result * 100).round
  end

  def positive_outcome_configuration_link(text_or_icon)
    content = get_safe_string
    content << text_or_icon
    content << set_screen_reader_only_content("feature.outcomes_report.title.configure_positive_outcomes_popup_title".translate)
    link_to_function(content, "jQueryShowQtip('', '', '#{overall_impact_survey_satisfaction_configurations_global_reports_path}', {}, {largeModal: true});")
  end

  def overall_impact_loader
    content_tag(:div, class: "m-t-xs m-b-xs p-b-sm") do 
      render partial: "common/loading_rectangles"
    end
  end

  private

  def get_ignored_or_not_configured_state(survey_satisfaction_configuration_hash)
    element_text, element_class = 
      if survey_satisfaction_configuration_ignored?(survey_satisfaction_configuration_hash[:config])
        ["feature.global_reports.overall_impact.content.ignored_html".translate(icon: get_icon_content("fa fa-eye-slash")), "label"]
      elsif survey_satisfaction_not_configured?(survey_satisfaction_configuration_hash)
        ["feature.global_reports.overall_impact.content.not_configured_html".translate(icon: get_icon_content("fa fa-exclamation-triangle")), "label label-danger"]
      end
    content_tag(:span, element_text, class: element_class)
  end

  def survey_satisfaction_configuration_ignored?(config)
    config == false
  end

  def survey_satisfaction_not_configured?(configuration_hash)
    !survey_satisfaction_configuration_ignored?(configuration_hash[:config]) && configuration_hash[:surveys].blank?
  end

  def program_outcomes_feature_disabled?(configuration_hash)
    !configuration_hash[:program_outcomes_feature_enabled]
  end

  def survey_satisfaction_configured?(configuration_hash)
    !survey_satisfaction_configuration_ignored?(configuration_hash[:config]) && configuration_hash[:surveys].present?
  end

  def update_survey_satisfaction_configuration_path(text_options, url_params)
    text = "feature.global_reports.overall_impact.action.#{text_options[:key]}_html".translate(icon: get_icon_content("fa #{text_options[:icon]}"))
    link_to_function(text, "jQuery.ajax({url: '#{update_overall_impact_survey_satisfaction_configuration_global_reports_path(url_params)}', method: 'PUT'});", class: "btn btn-xs btn-outline #{text_options[:button_class]}")
  end

  def program_outcomes_feature_disabled_action(program_id)
    program = Program.find(program_id)
    action_link = super_console? ? link_to("display_string.enable_feature".translate(feature_name: "features_list.program_outcomes_report.title".translate), edit_program_path(tab: ProgramsController::SettingsTabs::FEATURES, root: program.root)) : "feature.global_reports.overall_impact.action.contact_support_to_configure_html".translate(support_url: get_support_link(root: program.root))
    content_tag(:span, action_link, class: "pull-right")
  end
end