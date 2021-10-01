When /^I follow PDF and generate HTML view of PDF$/ do
  location = page.evaluate_script(%Q[jQuery("#title_actions a:contains('PDF')").attr("href")])
  page.execute_script(%Q[jQuery("#title_actions a:contains('PDF')").attr("href", "#{location}?debug_pdf=1")])

  step "I follow \"PDF\""
end

When /^I verify the presence of charts$/ do
  assert page.evaluate_script("jQuery('div.highcharts-container').length > 0")
  assert page.evaluate_script("jQuery('div.highcharts-container svg').length > 0")
end

And /^I verify the presence of pie chart$/ do
  assert page.evaluate_script("jQuery('div#cjs_connections_activity_stats div.highcharts-container').length > 0")
  assert page.evaluate_script("jQuery('div.highcharts-container svg').length > 0")
end

Then /^I see that "([^"]*)" tab is selected$/ do |tab|
  assert_equal tab, page.evaluate_script(%Q[jQuery('.cjs_common_report_tab.active').text()])
end

Then /^I select "([^"]*)" from profile filter questions$/ do |question_text|
  question_id = page.evaluate_script(%Q[jQuery(".cjs_question_selector").last().attr("id")])
  steps %{
    And I select \"#{question_text}\" from \"#{question_id}\"
  }
end

Then /^I select "([^"]*)" as profile filter operator$/ do |operator|
  operator_id = page.evaluate_script(%Q[jQuery(".cjs_operator_field").last().attr("id")])
  steps %{
    And I select \"#{operator}\" from \"#{operator_id}\"
  }
end

Then /^I fill "([^"]*)" as profile filter answer$/ do |ans_text|
  ans_id = page.evaluate_script(%Q[jQuery(".cjs_input_hidden").last().attr("id")])
  page.execute_script("jQuery('##{ans_id}').last().val('#{ans_text}')")
end