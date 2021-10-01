Given /^I directly go to "([^"]*)"$/ do |page_url|
  visit "#{page_url}"
end

Then /^I add questions under "([^"]*)"$/ do |competency_name|
  within( find(:xpath, "//span[normalize-space(text())='#{competency_name}']/following-sibling::div[1]") ) do
    click_link 'publish'
  end
end

Then /^I add a new question "([^"]*)" of type "([^"]*)"$/ do |question_title, question_type|
  steps %{
    And I fill in "three_sixty_question[title]" with "#{question_title}"
    And I select "#{question_type}" from "three_sixty_question[question_type]"
    And I press "Save"
  }
end

Then /^I type in "([^\"]*)" into autocomplete list "([^\"]*)" and I choose "([^\"]*)"$/ do |typed, input_name,should_select|
   page.execute_script("jQuery('input#member_name_with_email').val('student example <rahim@example.com>')")
end

Then /^I fill the survey$/ do
  page.all("input").each do |s|
    if s.value == rand(1..5).to_s
        choose(s[:id])
    end
  end
  steps %{
    Then I fill in "Give an example to signify the ability to work in a team?" with "he is a very good motivator"
    Then I press "Submit"
  }
end

Then /^"([^\"]*)" does the review$/ do |email|
  steps %{
    Then I open mail of "#{email}"
    And I follow "Complete the survey" in the email
    Then I should see "Your Details"
    Then I fill the survey
  }
end

Then /^I delete a competency question$/ do
  org = get_organization("primary")
  question = org.three_sixty_competencies.last.questions.first
  within "div#competency_question_row_#{question.id}" do
   step "I click \".fa-trash\""
  end
end

Then /^I delete a competency question of drafted survey$/ do
  question = ThreeSixty::SurveyQuestion.last
  within "#cjs_three_sixty_survey_question_#{question.id}" do
   step "I click \".fa.fa-trash\""
  end
end

Then /^I delete an open ended question$/ do
  org = get_organization("primary")
  question = org.three_sixty_oeqs.last
  within "div#open_ended_question_row_#{question.id}" do
   step "I click \".fa-trash\""
  end
end

Then /^I delete a drafted survey$/ do
  survey = ThreeSixty::Survey.find_by(title: "Survey For Level 3 Employees")
  within "#three_sixty_survey_#{survey.id}" do
   step "I follow \"Delete\""
 end
end

Then /^I delete the survey "([^\"]*)"$/ do |surveyname|
  survey = ThreeSixty::Survey.find_by(title: "#{surveyname}")
  within "#three_sixty_survey_#{survey.id}" do
   step "I follow \"Delete\""
 end
end

Then /^I delete a reviewer group$/ do
  page.find("div#three_sixty_reviewer_groups .ibox-content ul>li:nth-of-type(1) a:nth-of-type(2)").click
end

Then /^I edit a question$/ do
  org = get_organization("primary")
  question = org.three_sixty_oeqs.last
  within "div#open_ended_question_row_#{question.id}" do
   step "I click \".fa-pencil\""
  end
end

Then /^I edit the open ended question$/ do
 org = get_organization("primary")
 question = org.three_sixty_oeqs.last
 steps %{
   Then I fill in "three_sixty_open_ended_question_title_#{question.id}" with "What are your hobbies? Prioritize them."
   And I press "Save" within "div#open_ended_question_row_#{question.id}"
   Then I should see "What are your hobbies? Prioritize them."
 }
end

Then /^I fill in "([^"]*)" as reviewer group$/ do |text|
  select2_select(text)
end

def select2_select(text)
  page.find("#s2id_autogen1").click
  page.all("ul.select2-results li").each do |e|
    if e.text == text
      e.click
      return
    end
  end
end

Then /^I update the threshold of reviewer group "([^"]*)" with "([^"]*)" in "([^"]*)"$/ do |reviewer_group_name, threshold, subdomain|
  org = get_organization(subdomain)
  reviewer_group = org.three_sixty_reviewer_groups.find_by(name: reviewer_group_name)
  reviewer_group.update_attribute(:threshold, threshold)
end

Then /^I edit the reviewer group "([^"]*)" with "([^"]*)" and "([^"]*)" in "([^"]*)"$/ do |reviewer_group_name, name, threshold, subdomain|
  org = get_organization(subdomain)
  reviewer_group = org.three_sixty_reviewer_groups.find_by(name: reviewer_group_name)
  page.find("li#three_sixty_reviewer_group_#{reviewer_group.id} a:nth-of-type(1)").click
  steps %{
    And I fill in "three_sixty_reviewer_group_name_#{reviewer_group.id}" with "#{name}"
    And I fill in "reviewer_group_threshold_#{reviewer_group.id}" with "#{threshold}"
    And I press "Save"
  }
end

Then /^I update the reviewer group "([^"]*)" with "([^"]*)" and "([^"]*)" in "([^"]*)"$/ do |reviewer_group_name, name, threshold, subdomain|
  org = get_organization(subdomain)
  reviewer_group = org.three_sixty_reviewer_groups.find_by(name: reviewer_group_name)
  steps %{
    And I fill in "three_sixty_reviewer_group_name_#{reviewer_group.id}" with "#{name}"
    And I fill in "reviewer_group_threshold_#{reviewer_group.id}" with "#{threshold}"
    And I press "Save"
  }
end

Then /^I delete "([^"]*)" competency in primary$/ do |competency|
  org = get_organization("primary")
  id = org.three_sixty_competencies.find_by(title: competency).id
  page.execute_script %Q[jQuery("#three_sixty_competency_#{id}").find("[class*=\'fa-trash\']").click();]
end