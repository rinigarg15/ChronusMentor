When /^I select "([^\"]*)" days after program creation as "([^\"]*)"$/ do |days, element|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  formatted_date = program_albers.created_at + days.to_i.days
  page.execute_script("jQuery('#{element}').data('kendoDatePicker').value('#{DateTime.localize(formatted_date, format: :full_display_no_time)}')")
end

When /^I select "([^\"]*)" days and "([^\"]*)" days after program creation$/ do |days1, days2|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  formatted_date1 = program_albers.created_at + days1.to_i.days
  formatted_date2 = program_albers.created_at + days2.to_i.days
  page.execute_script("jQuery('#report_time_filter_form .cjs_daterange_picker_value').val('#{formatted_date1.to_date} - #{formatted_date2.to_date}')")
end

When /^I should see "([^\"]*)" days and "([^\"]*)" days after program creation as the selected date range$/ do |start_date, end_date|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  step "I should see \"#{DateTime.localize(program_albers.created_at + start_date.to_i.days, format: :abbr_short)} - #{DateTime.localize(program_albers.created_at + end_date.to_i.days, format: :abbr_short)}\""
end

And /^I should see the tooltip text "([^\"]*)" on hovering over the info icon for "([^\"]*)"$/ do |tooltip_text, section_key|
  ordered_section_keys = [
    "users_total", "users_connected", "mentoring_connections_total", "users_with_completed_mentoring_connections",
    "mentoring_connections_completed", "users_reporting_positive_results", "mentoring_connections_reporting_positive_results"
  ]
  page.execute_script("jQuery('i.fa.fa-info-circle.small.dim.m-l-xs').eq(#{ordered_section_keys.index(section_key)}).trigger('mouseover')")
  step "I should see \"#{tooltip_text}\""
end

Then /^I should see the tab "([^"]*)" selected in "([^"]*)"$/ do |tab_name, container|
  within "##{container}" do
    within "li.active" do
      step "I should see \"#{tab_name}\""
    end
  end
end

Then /^I clear selection for date "([^\"]*)"$/ do |element|
  steps %{
    Then I set the focus to the main window
    Then I scroll to the top of the page
    And I click "#{element}"
    Then I should see "Clear Selection"
    And I follow "Clear Selection"
  }
end

Then /^I cannot select a date prior to program created date$/ do
  program_albers = Program.find_by(root: "albers")
  formatted_start_date = program_albers.created_at.strftime("%B %d, %Y")
  program_start_date = page.evaluate_script(%Q[jQuery('.cjs_daterange_picker_start').data().minDate])
  assert_equal formatted_start_date, program_start_date
end

Then /^I should see default dates as the selected date range$/ do
  program_albers = Program.find_by(name: "Albers Mentor Program")
  formatted_start_date = program_albers.created_at.strftime("%B %d, %Y")
  formatted_end_date = Time.current.strftime("%B %d, %Y")
  step "I should see \"#{formatted_start_date} - #{formatted_end_date}\""
end

Then /^I select "([^\"]*)" as positive outcomes question$/ do |question_text|
  question_id = Program.find_by(name: "Albers Mentor Program").common_questions.find_by(question_text: question_text).id
  page.execute_script("jQuery('.cjs_positive_outcome_popup_selection_container').find('input.cjs_positive_outcome_question_selector').val('#{question_id}')")
end

Then /^I select "([^\"]*)" as positive outcomes choice for question "([^\"]*)"$/ do |choice, question_text|
  question = Program.find_by(name: "Albers Mentor Program").common_questions.find_by(question_text: question_text)
  qc_id = question.question_choices.find_by(text: choice).id
  page.execute_script("jQuery('.cjs_positive_outcome_popup_selection_container').find('input.cjs_positive_outcome_choices').val('#{qc_id}')")
end

Then /^I select a new metric "(.*?)"$/ do |metric_text|
  option_value = page.evaluate_script("jQuery('#report_metric_abstract_view_id option:contains(#{metric_text})').val()")
  page.execute_script("jQuery('#report_metric_abstract_view_id option[value=#{option_value}]').attr('selected', 'selected')")
  page.execute_script("jQuery('#report_metric_title').val('#{metric_text}')")
  steps %{
    Then I press "Add"
  }
end

And /^I click on start date selector$/ do
  page.execute_script("jQuery('.cjs_daterange_picker_start:first').click()")
end
