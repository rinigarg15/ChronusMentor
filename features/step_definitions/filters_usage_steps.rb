And /^there are some available for advance search configuration and ordered option question for "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  organization = program.organization
  role = program.get_role(role_name)
  question = organization.profile_questions.build(
      question_text: "Automation Preference",
      question_type: ProfileQuestion::Type::ORDERED_OPTIONS,
      options_count: 2,
      section: organization.sections.default_section.first)
    question.save!
    ["Selenium", "Cucumber", "Saucelabs", "Browserstack"].each_with_index do |text, i|
      question.question_choices.create!(text: text, position: i+1)
    end

    role_q = question.role_questions.new
    role_q.role = role
    role_q.save!
  secid = organization.sections.find_by(title: "More Information").id
  qid = organization.profile_questions.where(question_text: "What is your name")[0].id
  q2id = organization.profile_questions.where(question_text: "What is your name")[2].id 
  roleid = program.roles.find_by(name: "mentor").id
  steps %{
    When I have logged in as "robert@example.com"
    And I follow "Edit Profile" within "div#SidebarRightContainer"
    Then I select ordered options "Cucumber" and "Selenium"
    And I press "Save"
    Then I logout
    When I have logged in as "userrobert@example.com"
    And I follow "Edit Profile" within "div#SidebarRightContainer"
    Then I select ordered options "Cucumber" and "Saucelabs"
    And I press "Save"
    Then I logout
    When I have logged in as "ram@example.com"
    When I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    Then I follow "Customize"
    And I click "div.cjs-section-container[data-section-id='#{secid}']"
    And I click ".cjs_profile_question_#{qid}"
    Then I wait for ajax to complete
    And I follow "Roles"
    And I click ".cjs_profile_question_edit_role_settings"
  }
  uncheck("role_questions_filterable_#{qid}_#{roleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I wait for ajax to complete
    And I click ".cjs_profile_question_#{q2id}"
    Then I wait for ajax to complete
    And I follow "Roles"
    And I click ".cjs_profile_question_edit_role_settings"
    Then I wait for ajax to complete
  }
  uncheck("role_questions_filterable_#{q2id}_#{roleid}")
  steps %{
    When I scroll the div ".cjs-side-panel-slim-scroll"
    And I press "Save"
    Then I logout
  }
end

Then /^I apply location filter$/ do
  page.execute_script("jQuery('input#search_filters_location_3_name').val('Chennai, Tamil Nadu, India')")
  steps %{
    And I press "Go" inside "Location" content
    And I should not see "robert user"
    Then I should see "Good unique name"
  }
end

And /^I apply choice based filter in combination with location filter$/ do
  filterid = Organization.where(name: "Primary Organization").first.profile_questions.where(question_text: "What is your name")[1].id
  step "I click on \"What is your name\" header"
  check("sfpq_#{filterid}_2")
  step "I should see \"View all mentors\""
end

Then /^I remove location filter and check only choice based filter$/ do
  filterid = Organization.where(name: "Primary Organization").first.profile_questions.where(question_text: "What is your name")[1].id
  steps %{
    When I remove filter with id "filter_item_profile_question_3"
    Then I should see "robert user"
    And I should not see "Good unique name"
  }
  check("sfpq_#{filterid}_0")
  steps %{
    Then I should see "robert user"
    And I should see "Good unique name"
  }
end

Then /^I filter for "([^\"]*)" connections$/ do |filter_name|
  within "#filter_pane" do
    steps %{
      When I click on "Status" header
      And I click ".checkbox ##{filter_name}"
      Then I wait for ajax to complete
    }
  end
  within "#your_filters" do
    step "I should see \"Reset all\""
  end
end

Then /^I click on "([^\"]*)" header$/ do |header_text|
  step "I click by xpath \"#{xpath_for_collapsible_header(header_text)}\""
end

Then /^(.*) inside "([^\"]*)" content$/ do |step_definition, filter_text|
  within(:xpath, xpath_for_collapsible_content(filter_text)) { step step_definition }
end

Then /^I filter for "([^\"]*)" connections in v1$/ do |filter_name|
  within "#filter_pane" do
    steps %{
      And I click on "Status" header
      And I click ".checkbox ##{filter_name}"
      Then I wait for ajax to complete
    }
  end
  within "#your_filters" do
    step "I should see \"Reset all\""
  end
end

Then /^I filter and see inactive connections$/ do
  within "#filter_pane" do
    steps %{
      And I click on "Status" header
      Then I click ".checkbox #sub_filter_active"
      Then I wait for ajax to complete
      }
  end
  steps %{
    Then I should see "student_c example"
  }
end

Then /^I filter by Student Name$/ do
  within "#filter_pane" do
    steps %{
      Then I should see "Mentoring Connection Name"
      Then I click on "Student" header
      When I fill in students field with "student_b example"
      And I press "Go"
      Then I click on "Student" header
    }
  end

  steps %{
    Then I should see "chronus & example"
    Then I remove filter with id "filter_item_status"
    Then I should see "chronus & example"
    And I should not see "student_c example"
    Then I follow "Reset all"
  }
end

Then /^I apply Closes on filter$/ do
  step "I wait for animation to complete"
  within "#filter_pane" do
    steps %{
      Then I click on "Closes on" header
      Then I wait for animation to complete
    }
    page.execute_script %Q[jQuery(".cjs_daterange_picker_presets").val("next_7_days"); jQuery(".cjs_daterange_picker_presets").trigger('change');]
  end
  within "#filter_pane" do
    step "I press \"Go\""
  end
  steps %{
    Then I should see "mentor & example"
    And I should not see "chronus & example"
  }
end

Then /^I apply text based filters$/ do
  filterid = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Entire Education").id
  filter2id = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Current Education").id
  steps %{
    Then I click on "Entire Education" header
    And I fill in "sf_pq_#{filterid}" with "mechanical"
    And I press "Go"
    Then I wait for ajax to complete
    When I remove filter with id "filter_item_availability_status"
    Then I wait for ajax to complete
    Then I should see "Good unique name"
    Then I should see "mentor_d chronus"
    And I should not see "robert user"
    Then I click on "Current Education" header
    And I fill in "sf_pq_#{filter2id}" with "mechanical"
    And I press "Go" inside "Current Education" content
    Then I wait for ajax to complete
    Then I should see "Good unique name"
    Then I should not see "mentor_d chronus"
  }
end

Then /^I press "([^\"]*)" inside xpath "([^\"]*)"$/ do |selector, xpath|
  within(:xpath, xpath) do
    step "I press \"#{selector}\""
  end
end

Then /^I apply ordered option filter in combination with text based filter$/ do
  orderoption = ProfileQuestion.last.id
  step "I click on \"Automation Preference\" header"
  check("sfpq_#{orderoption}_1")
  steps %{
    Then I wait for ajax to complete
    Then I should see "Good unique name"
    Then I should not see "mentor_d chronus"
    And I should not see "robert user"
  }
end

Then /^I remove text based filter and check only ordered option filter$/ do
  orderoption = ProfileQuestion.last.id
  filterid = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Entire Education").id
  filter2id = Organization.where(name: "Primary Organization").first.profile_questions.find_by(question_text: "Current Education").id

  steps %{
    When I remove filter with id "filter_item_profile_question_#{filter2id}"
    Then I wait for ajax to complete
    Then I should see "Good unique name"
    Then I should not see "mentor_d chronus"
    And I should not see "robert user"
    When I remove filter with id "filter_item_profile_question_#{filterid}"
    Then I wait for ajax to complete
    Then I should see "Good unique name"
    Then I should not see "mentor_d chronus"
    And I should see "robert user"
  }

  check("sfpq_#{orderoption}_2")
  uncheck("sfpq_#{orderoption}_1")

  steps %{
    Then I wait for ajax to complete
    Then I should not see "Good unique name"
    And I should see "robert user"
    Then I remove filter with id "filter_item_profile_question_#{orderoption}"
    Then I wait for ajax to complete
  }
end

Then /^I remove filter with id "([^\"]*)"$/ do|filter_id|
  xpath = "//span[@id='#{filter_id}']/descendant::span[contains(text(),'X')]"
  step "I click by xpath \"#{xpath}\""
end

Then /^I filter using quick find$/ do
  within "#quick_search" do
    steps %{
      And I fill in "sf_quick_search" with "poet"
      And I click ".btn"
    }
  end
  steps %{
    Then I wait for ajax to complete
    Then I should see "View all mentors"
    Then I remove filter with id "filter_item_quick_search"
    Then I wait for ajax to complete
    Then I should not see "View all mentors"
  }
end

Then /^I filter a mentor "([^\"]*)" using quick find$/ do|search_text|
  within "#quick_search" do
    steps %{
      And I fill in "sf_quick_search" with "#{search_text}"
      And I click ".btn"
    }
  end
  steps %{
    Then I should see "#{search_text}"
    Then I remove filter with id "filter_item_quick_search"
   }
end

Then /^I filter a mentor with drafted connections using quick find$/ do
  within "#quick_search" do
    steps %{
      And I fill in "sf_quick_search" with "robert"
      And I click ".btn"
    }
  end
end

Then /^I filter a mentor with name "([^\"]*)" using quick find$/ do |search_text|
  within "#quick_search" do
    steps %{
      And I fill in "sf_quick_search" with "#{search_text}"
      And I click ".btn"
    }
  end
end

Then /^I filter mentor requests on sender$/ do
  steps %{
    And I fill in "search_filters_sender" with "Hello"
    And I press "Go"
  }
end

Then /^I filter mentor requests on receiver$/ do
  steps %{
    And I fill in "search_filters_receiver" with "Hello"
    And I press "Go"
  }
end



And /^I remove the status filter$/ do
  step "I remove filter with id \"filter_item_availability_status\""
end

Then /^I filter for connections with status "([^\"]*)"$/ do |filter_name|
  steps %{
    Then I follow "Filters"
    Then I should see "Status"
    Then I should see "#{filter_name}"
    And I click by xpath "//*[contains(text(),'#{filter_name}')]/input"
    Then I wait for ajax to complete
    And I click by xpath "//*[contains(text(),'Status')]"
  }
 end

Then /^I clear and close the filter$/ do
  steps %{
    Then I should see "Clear all"
    Then I follow "Filters"
    And I follow "Clear all"
    Then I wait for ajax to complete
  }
end

Then /^I select "([^\"]*)" from reports date range presets$/ do |present|
  id = find(".cjs_daterange_picker_presets")[:id]
  steps %{
    And I select "#{present}" from "#{id}"
  }
end

And /^I check the events status before rsvp$/ do
 within(find(:xpath, "//*[@id=\"requests_modal\"]/div/div/div[2]/div/a[2]/div[2]")) do
   step "I should see \"1\""
 end
end  

And /^I check the events status after rsvp$/ do
 within(find(:xpath, "//*[@id=\"requests_modal\"]/div/div/div[2]/div/a[2]/div[2]")) do
   step "I should not see \"1\""
 end
end  

def xpath_for_collapsible_header(search_text, exact_match = true)
  selector = exact_match ? "normalize-space()='#{search_text}'" : "contains(normalize-space(),'#{search_text}')"
  %Q[//div[#{selector}]/parent::div[contains(@id,'collapsible') and contains(@id,'header')]]
end

def xpath_for_collapsible_content(search_text, exact_match = true)
  selector = exact_match ? "normalize-space()='#{search_text}'" : "contains(normalize-space(),'#{search_text}')"
  %Q[//div[#{selector}]/ancestor::a[contains(@data-toggle,'collapse')]/following-sibling::div[contains(@id,'collapsible') and contains(@id,'content')]]
end
