
Given /^I create a new view$/ do
  page.execute_script %Q[jQuery("#clicked-title-admin-view").trigger('click');]
  page.execute_script %Q[jQuery(".cjs_create_admin_view_link").trigger('click');]
end

Given /^I click view$/ do
 if (ENV['BS_RUN'] == 'true')
  page.execute_script %Q[jQuery("#admin_view_title").focus();]
 end
end

Given /^I click on the view "([^\"]*)"$/ do |text|
  page.execute_script %Q[jQuery("#clicked-title-admin-view").trigger('click');]
  step "I click on select2 result \"#{text}\""
end

Then /^I should see "([^\"]*)" in the row "([^\"]*)"$/ do |text, id|
  checkbox = page.find("##{id}")
  row = checkbox.find(:xpath, '../..')
  within row do
    step "I should see \"#{text}\""
  end
end

Then /^I should not see "([^\"]*)" in the row "([^\"]*)"$/ do |text, id|
  checkbox = page.find("##{id}")
  row = checkbox.find(:xpath, '../..')
  within row do
    step "I should not see \"#{text}\""
  end
end

Then /^I should see "([^\"]*)" button/ do |name|
  find_button(name).should_not be_nil
end

Then /^I filter table by "([^\"]*)" with "([^\"]*)"$/ do |field, value|
  step "I set the focus to the main window"
  within "th[data-field='#{field}']" do
    step "I click \".k-grid-filter\""
  end
  CucumberWait.retry_until_element_is_visible {page.find('.k-textbox.k-input', :match => :prefer_exact).set(value)}
  if(ENV['BS_RUN'] == 'true')
   page.execute_script "jQuery('.k-textbox.k-input').trigger('change');"
  end
  steps %{
    Then I should see submit button "Filter"
    Then I press "Filter"
    Then I wait for ajax to complete
  }
end

Then /^I filter table by date filter "([^\"]*)" with "([^\"]*)"$/ do |field, value|
  step "I set the focus to the main window"
  within "th[data-field='#{field}']" do
    step "I click \".k-grid-filter\""
  end
  step "I wait for ajax to complete"
  page.execute_script "jQuery('.k-datepicker').click();"
  page.execute_script "jQuery('input.k-input').val('1/12/2020');"
  steps %{
    Then I wait for ajax to complete
    Then I should see "Filter"
    Then I press "Filter"
    Then I wait for ajax to complete
  }
end

Then /^I clear table filter for "([^\"]*)"$/ do |field|
  within "th[data-field=#{field}]" do
    step "I click \".k-grid-filter\""
  end
  steps %{
    Then I should see submit button "Clear"
    Then I press "Clear"
    Then I wait for ajax to complete
  }
end

Then /^I sort table by "([^\"]*)"$/ do |field|
  step "I click \"#{"th[data-field=#{field}]"}\""
end

Then /^I remove "([^\"]*)" from selection$/ do |email|
  member = Member.find_by(email: email)
  step "I uncheck \"ct_admin_view_checkbox_#{member.id}\""
end

Then /^I add "([^\"]*)" from selection$/ do |email|
  member = Member.find_by(email: email)
  step "I check \"ct_admin_view_checkbox_#{member.id}\""
end

Then /^I should see blank table$/ do
  assert page.all('#cjs_admin_view_kendogrid tbody tr').blank?
end

When /I paginate table by "([^\"]*)" items/ do |items_per_page|
  step "I click \".k-select\""
  page.execute_script(%Q{jQuery('.k-animation-container').find("li:contains('#{items_per_page}')").click();})
end

Then /^I press enter in "([^\"]*)"$/ do |id|
  #find('#'+id).native.send_key(:enter)
  # Rails 3.2.13 bug (json 1.7.7). Temporary, until JSON will be fixed.
  page.execute_script %Q[jQuery("##{id}").closest('form').submit();]
end

And /^I fill in tag text area with "([^\"].*)"$/ do |entered_text|
  steps %{
    When I click "#s2id_admin_view_tag_list > .select2-choices"
    And I click on select2 result "#{entered_text}"
  }
end

Then /^I delete the view with title "([^\"].*)"$/ do |title|
  within "div#title_actions" do
   step "I click \"span.caret\""
  end
  steps %{
    And I follow "Delete View"
    And I should see "Are you sure you want to delete this view"
    Then I confirm popup
    Then I should see "The View - #{title} has been deleted successfully"
  }
end

And /^I should see todays date in "([^\"].*)"$/ do |element|
  within("#{element}") do
    step "I should see \"#{DateTime.localize(Time.now, format: :abbr_short)}\""
  end
end

And /^I fill month back date in "([^\"].*)"$/ do |element|
  page.execute_script("jQuery('##{element}').data('kendoDatePicker').value('#{DateTime.localize(1.month.ago, format: :full_display_no_time)}')")
end 

Then /^I add the following users:$/ do |table|
  table.map_column!('user'){|user| user.to_s }
  table.hashes.each do |u|
    member = Member.find_by(email: u[:user])
    step "I check \"ct_admin_view_checkbox_#{member.id}\""
  end
end