And /^I reply to the inbox message from mentoring area$/ do
  scrap_id = Scrap.find_by(subject: "Second message before connecting").id
  step "I click \"#scrap_item_#{scrap_id}\""
  step "I click \"#reply_link_#{scrap_id}\""
  steps %{
    And I fill in "message_content_#{scrap_id}" with "Replying to inbox message from the mentoring area"
    And I press "Reply"
  }
end

And /^I reply "([^\"]*)" to the scrap with subject "([^\"]*)"$/ do |reply_message, subject|
  scrap_id = Scrap.where(subject: subject).last.id
  page.execute_script "jQuery('#message_content_#{scrap_id}').focus();"
  step "I fill in \"message_content_#{scrap_id}\" with \"#{reply_message}\""
end

Then /^I visit inbox with "([^\"]*)" unread messages$/ do |count|
  count = "" if count.to_i == 0
  page.find("a#inbox", :text => count, :exact => true).click
end

Then /^I should see inbox link$/ do
  page.has_css?("a#inbox")
end

Then /^I set english as locale for "([^\"]*)"$/ do |email|
  Member.where(email: email)[0].member_language.destroy
end

Then /^I open reply pane for the message "([^\"]*)"$/ do |message_number|
  step "I wait for \"2\" seconds"
  page.execute_script ("jQuery(jQuery('.cjs_mail_section')[#{message_number.to_i-1}]).find('.cjs_reply_link').click()");
  step "I wait for \"2\" seconds"
end

Then /^I click delete for the message "([^\"]*)"$/ do |message_number|
  page.execute_script ("jQuery(jQuery('.cjs_mail_section')[#{message_number.to_i-1}]).find('div.btn-group ul.dropdown-menu').show();");
  step "I follow \"Delete\""
end


Then /^I should see the sibling scrap "([^"]*)"$/ do |text|
  page.evaluate_script(%Q[jQuery("div.cjs-scrap-siblings:contains('#{text}')").is(':visible')])
end


Then /^I should not see the sibling scrap "([^"]*)"$/ do |text|
  !page.evaluate_script(%Q[jQuery("div.cjs-scrap-siblings:contains('#{text}')").is(':visible')])
end
