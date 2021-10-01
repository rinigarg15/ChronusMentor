Then /^I scroll to bottom of page$/ do
  page.execute_script "window.scrollTo(0, document.body.scrollHeight)"
end

Then /^I scroll the find users dropdown "([^\"]*)" to see "([^\"]*)"$/ do |id, user_id|
  bool = 1
  while (bool == 1)
    page.execute_script "jQuery('#{id}').scrollTop(jQuery('#{id}')[0].scrollHeight);"
    if (page.has_css?("div#{user_id}"))
      bool = 0
    end
  end  
end

Then /^I should see recommended count (\d+) in the row (\d+) of record "([^\"]*)"$/ do |count, row_num, id|
  row_num = row_num.to_i
  if row_num > 1
    row_num = row_num + 1
    col_num = 3
  else
    col_num = 5
  end
  student_record = page.find("#{id}")
  td_cell = student_record.find(:xpath, "((.//tr)[#{row_num}]//td)[#{col_num}]")
  within td_cell do
    step "I should see \"#{count}\""
  end
end

Then /^I should see (\d+) "([^\"]*)" in "([^\"]*)"$/ do |num, type, id|
  if type == "trash_icons"
    assert_equal num.to_i, page.evaluate_script("jQuery('#{id} .fa-trash').filter(':visible').length")
  elsif type == "mentors"
    assert_equal num.to_i, page.evaluate_script("jQuery('#{id} tr').filter(':visible').length - jQuery('#{id} tr:contains(\"Unmatched\")').filter(':visible').length - jQuery('#{id} thead').length - jQuery('#{id} tr.cjs-quick-search-mentors-row').filter(':visible').length")
  end
end

Then /^I remove mentor (\d+) in "([^\"]*)"$/ do |num, id|
  page.execute_script "jQuery('#{id} .fa-trash').filter(':visible')[#{num.to_i} - 1].click()"
end

Then /^I should see (\d+) recommendations in "([^\"]*)" state$/ do |num, status|
  if (num != "0")
    Timeout.timeout(Capybara.default_max_wait_time) do
      while (!page.evaluate_script("jQuery('#cjs_bulk_match_result .cui-td-group-status:contains(\"#{status}\")').is(':visible')")) do
      end
    end
  else
    Timeout.timeout(Capybara.default_max_wait_time) do
      while (page.evaluate_script("jQuery('#cjs_bulk_match_result .cui-td-group-status:contains(\"#{status}\")').is(':visible')")) do
      end
    end
  end
  assert_equal num.to_i, page.evaluate_script("jQuery('#cjs_bulk_match_result .cui-td-group-status:contains(\"#{status}\")').filter(':visible').length")
end

And /^I confirm (\d+) recommendations in "([^\"]*)" state$/ do |num, status|
  program = Program.find_by(root: "albers")
  status_value = (status == "Drafted") ? MentorRecommendation::Status::DRAFTED : MentorRecommendation::Status::PUBLISHED
  assert_equal num.to_i, program.mentor_recommendations.where(status: status_value).count
end

When /^I (?:open|close) status action dropdown of "([^\"]*)"$/ do |id|
  page.execute_script("jQuery('#{id} .caret').filter(':visible').click()")
end

Then /^I should( not)? see "([^\"]*)" for "([^\"]*)"$/ do |negate, type, id|
  selector = "input[type=checkbox]"
  assert_equal !negate, page.evaluate_script("jQuery('#{id} #{selector}').is(':visible')")
end

Then /^I should not see "([^\"]*)" in the student row "([^\"]*)"$/ do |text, id|
  within "tbody#{id}" do
    step "I should not see \"#{text}\""
  end
end

Given /^minimum preferred mentors count is "([^"]*)" in program "([^"]*)":"([^"]*)"$/ do |count, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  program.min_preferred_mentors = count
  program.save!
end