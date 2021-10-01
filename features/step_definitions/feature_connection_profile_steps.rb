Then /^I create connection profile questions$/ do
  steps %{
    And I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    Then I follow "Customize Mentoring Connections Profile Fields"
    Then I should see "Add New Question"
    And I follow "Add New Question"
    And I fill in "survey_question_question_text_new" with "Question1"
    And I fill in "help_text_new" with "Question1 Description"
    And I press "Add"
    Then I should see "Question1"
    And I follow "Add New Question"
    And I fill in "survey_question_question_text_new" with "Question2"
    And I select "Multi line" from "common_question_type_new"
    And I fill in "help_text_new" with "Question2 Description"
    And I press "Add"
    Then I should see "Question2"
    And I follow "Add New Question"
    And I fill in "survey_question_question_text_new" with "Question3"
    And I select "Multiple entries" from "common_question_type_new"
    And I fill in "help_text_new" with "Question3 Description"
    And I press "Add"
    Then I should see "Question3"
    And I follow "Add New Question"
    And I fill in "survey_question_question_text_new" with "Question4"
    And I select "Pick one answer" from "common_question_type_new"
    And I fill in "help_text_new" with "Question4 Description"
    And I add choices "c1,c2,c3" for survey question
    And I press "Add"
    Then I should see "Question4"
    And I follow "Add New Question"
    And I fill in "survey_question_question_text_new" with "Question5"
    And I select "Pick multiple answers" from "common_question_type_new"
    And I fill in "help_text_new" with "Question5 Description"
    And I add choices "d1,d2,d3" for survey question
    Then I check "connection_question[allow_other_option]"
    And I press "Add"
    Then I should see "Question5"
    And I follow "Add New Question"
    And I fill in "survey_question_question_text_new" with "Question6"
    And I select "Upload File" from "common_question_type_new"
  }
  assert page.evaluate_script("jQuery(\"#help_text_new\").val() == \"Please upload a file of the following types: pdf, doc, xls, ppt, docx, pptx, xlsx, mp4 (File size limit is 20MB)\"")
  steps %{
    And I fill in "help_text_new" with "Question6 Description"
    And I press "Add"
    Then I should see "Question6"
  }
end

Then /^I view the connection profile$/ do
  steps %{
    And I follow "View Mentoring Connection Profile" within "#quick_links"
    Then I should see "Question1"
    Then I should see "connection is doing great"
    Then I should see "c1"
    Then I should see "d1"
    Then I should see "connection is doing great multiple entries"
    Then I should see "connection is doing great multi line"
    Then I should see "profile_questions_invalid.csv"
  }
end

Then /^I fill in answers "([^\"]*)" for the connection profile questions$/ do |answers|
  questions = CommonQuestion.last(6)
  answers.split(',').each_with_index do |ans, i|
    ans = ans.gsub("'", '').strip
    if questions[i].choice_based?
      # Do not choose anything if not given.
      unless ans.empty?
        #Multiple Answers allowed?
        if (questions[i].question_type == 3)
          step "I check \"common_answers_#{questions[i].id}_#{ans.downcase}\""
          next
        end
        #Rating Scale
        if (questions[i].question_type == 4)
          step "I choose \"common_answers_#{questions[i].id}_#{ans.downcase}\""
          next
        end
        #Only one answer
        step "I select \"#{ans}\" from \"common_answers_#{questions[i].id}\""
        #choose "common_answers_#{questions[i].id}_#{ans.downcase}"
        next
      end
      next
    end
    if (questions[i].question_type == 6)
      step "I fill in \"connection_answers_#{questions[i].id}\" with \"#{ans}\""
      next
    end
    if (questions[i].question_type == 5)
      step "I fill in \"common_answers_#{questions[i].id}\" with file \"files/profile_questions_invalid.csv\""
    else
      step "I fill in \"common_answers_#{questions[i].id}\" with \"#{ans}\""
    end
  end
  steps %{
    Then I fill in "Required Connection Question" with "testing"
    And I press "Save"
    Then I should see the flash "Connection profile has been saved"
  }
end

Then /^I should see "([^\"]*)" in the "([a-z]+)" listing of mentoring area members pane in "([^\"]*)":"([^\"]*)"$/ do |user_name, role_name, subdomain, program_root|
  program = get_program(program_root, subdomain)
  role = program.find_role(role_name)
  steps %{
    Then I should see \"#{user_name}\" within \"#users_of_role_#{role.id}\"
  }
end

And /^I expand the "([a-z]+)" listing of mentoring area members pane$/ do |role_name|
  steps %{
    And I click by xpath "#{xpath_for_collapsible_header(role_name.camelize, false)}"
    And I wait for ajax to complete
  }
end

And /^I create project template with title "([^\"]*)"$/ do |title|
  steps %{
    And I follow "Manage"
    And I follow "Project Plan Templates"
    And I follow "Create a New Template"
    And I fill in "cjs_title_field" with "#{title}"
    And I press "Save and proceed to Configure Features »"
  }
end

And /^I click my connection mobile icon$/ do
  page.execute_script("jQuery('.cjs_connections_tab').click();")
end

And /^I create task templates$/ do
  steps %{
    When I click ".add-action-opener"
    And I follow "New Task"
    And I fill in "mentoring_model_task_template_title" with "Mentor Task"
    And I assign the task to "Mentor"
    And I press "Save Task"
    Then I wait for ajax to complete
  }
end

And /^I create milestone template with title "([^\"]*)"$/ do |title|
  steps %{
    When I click "#cjs_add_milestone_template"
    And I should see "Add Custom Milestone" within "#remoteModal"
    And I fill in "cjs_milestone_template_form_title_" with "#{title}"
    And I press "Save" within ".modal.in"
    Then I wait for remote Modal to be hidden
    Then I should see "#{title}"
  }
end

And /^I should see milestone "([^\"]*)" completed$/ do |title|
  page.should have_xpath("//span[contains(text(),'#{title}')]/preceding-sibling::i[contains(@class,'fa-check-circle')]")
end


And /^I should see milestone "([^\"]*)" not completed$/ do |title|
  page.should_not have_xpath("//span[contains(text(),'#{title}')]/preceding-sibling::i[contains(@class,'fa-check-circle')]")
end

And /^I create( required)? task template with title "([^\"]*)" for "([^\"]*)" milestone$/ do |required, title, milestone_title|
  steps %{
    Then I click by xpath "//div[contains(text(),'#{milestone_title}')]"
    And I should see "Add a new action"
    And I follow "Add a new action"
    And I should see "New Task"
    And I follow "New Task"
    And I should see "Assign To"
    And I fill in "mentoring_model_task_template_title" with "#{title}" within "#cjs_new_mentoring_model_task_template_new"
    And I assign the task to "Mentor"
  }

  if required
    steps %{
      And I check "mentoring_model_task_template_required"
      Then I set a harcoded value for deadline
    }
  end

  steps %{
    And I press "Save Task"
    Then I wait for ajax to complete
  }
end

And /^I create messages enabled project template with task templates$/ do
  steps %{
    Then I create project template with title "Messages enabled with task templates"
    Then I check "mentoring_model_check_box_allow_messaging"
    Then I uncheck "mentoring_model_check_box_allow_forum"
    And I press "Save and proceed to Add Content »"
    And I create task templates
  }
end

And /^I create messages enabled project template without task templates$/ do
  steps %{
    Then I create project template with title "Messages enabled without task templates"
    Then I check "mentoring_model_check_box_allow_messaging"
    Then I uncheck "mentoring_model_check_box_allow_forum"
    And I press "Save and proceed to Add Content »"
  }
end

And /^I create both disabled project template without task templates$/ do
  steps %{
    Then I create project template with title "Both disabled without task templates"
    Then I uncheck "mentoring_model_check_box_allow_messaging"
    Then I uncheck "mentoring_model_check_box_allow_forum"
    And I press "Save and proceed to Add Content »"
  }
end

And /^I create both disabled project template with task templates$/ do
  steps %{
    Then I create project template with title "Both disabled with task templates"
    Then I uncheck "mentoring_model_check_box_allow_messaging"
    Then I uncheck "mentoring_model_check_box_allow_forum"
    And I press "Save and proceed to Add Content »"
    And I create task templates
  }
end


