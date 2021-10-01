Then /^I "([^"]*)" "([^"]*)" from manage members$/ do |action, user|
  steps %{
    And I hover over "#{user}"
  }
  xpath="//a[contains(text(),'#{user}')]/following-sibling::*/*/a[contains(text(),'#{action}')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

Then /^I "([^"]*)" for the connection "([^"]*)"$/ do |dropdown_action,connection_name|
  xpath="//*[descendant::a[contains(text(),'#{connection_name}')]]/preceding-sibling::*/a[contains(@class, 'dropdown-toggle ')]"
  steps %{
    And I click by xpath "#{xpath}"
  }

  xpath="//*[descendant::a[contains(text(),'#{connection_name}')]]/preceding-sibling::*/a/following-sibling::*/*/a[contains(text(), '#{dropdown_action}')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

Then /^I should not see "([^"]*)" in the drop down action for "([^"]*)"$/ do |dropdown_action,connection_name|
  xpath="//*[descendant::a[contains(text(),'#{connection_name}')]]/preceding-sibling::*/a[contains(@class, 'dropdown-toggle ')]"
  steps %{
    And I click by xpath "#{xpath}"
    And I should not see "#{dropdown_action}"
  }
end

Then /^I create a mentoring connection with the following roles in "([^"]*)"$/ do |state, data|
  hash_details=data.hashes()
  hash_details.each do |hash|
    role= hash['role']
    user=hash['user']
    xpath="//*[contains(text(),'#{role}')]/following-sibling::*/*/a"
    steps %{
        And I click by xpath "#{xpath}"
      }
    xpath="//*[contains(text(),'#{role}')]/following-sibling::*/input"
    steps %{
        And I fill xpath "#{xpath}" with "#{user}"
      }
  end
  if(action.include?("draft"))
    steps %{
      And I press button "save_as_draft"
    }
  end

end

Then /^I filter tasks for "([^\"]*)"$/ do |text|
  if(text == "all")
     text = "tasks_by_all_members_filter"
  elsif(text == "Unassigned")
     text = "unassigned_tasks_filter"
  else
     member_id = Member.find_by(email: text).id
     text = "tasks_by_member_#{member_id}_filter"
  end
  steps %{
    Then I click "#connection_filter"
    Then I choose radio button with id "#{text}"
    Then I click ".cjs_filter_submit_btn" within ".modal-content"
    Then I wait for ajax to complete
  }
end

When /^I assign the task to "([^\"]*)"$/ do |user_role|
  step "I select \"#{user_role}\" from \"mentoring_model_task_template_role_id\""
end

When /^I align the task to the goal "([^\"]*)"$/ do |goal|
  step "I select \"#{goal}\" from \"mentoring_model_task_template_goal_template_id\""
end

Then /^I click on replace member "([^\"]*)"$/ do |member|
  page.execute_script("jQuery('a[title=\"#{member}\"]').next().next().children().children().children().first().children().first().click()")
end

Then /^I click on remove member "([^\"]*)"$/ do |member|
    page.execute_script("jQuery('a[title=\"#{member}\"]').next().next().children().children().children().last().children().first().click()")
end

Then /^I open unread scrap message from "([^\"]*)"$/ do |sender|
  xpath="//span/span[contains(text(),'#{sender}')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end
Then /^I click unread scrap message with subject "([^\"]*)"$/ do |subject|
  xpath="//div[contains(@class, 'cjs-scrap-subject') and text() = '#{subject}']"
  steps %{
    And I click by xpath "#{xpath}"
  }
end