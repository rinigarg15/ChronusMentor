When /^I delete the task$/ do
  steps %{
    Then I click on dropdown toggle within ".cjs-task-template-header"
    And I follow "Delete"
  }
end

When /^I delete the facilitation task$/ do
  steps %{
    Then I click on dropdown toggle within ".cjs-facilitation-template-header"
    And I follow "Delete"
  }
end

Then /^I should see the harcoded date$/ do
  program_albers = Program.find_by(name: "Albers Mentor Program")
  formatted_date = program_albers.created_at + 1.days
  step "I should see \"#{DateTime.localize(formatted_date, format: :abbr_short_no_year)}\""
end

When /^I select "([^\"]*)" days after program creation as due date for "([^\"]*)"$/ do |days, date_filter|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  formatted_date = program_albers.created_at + days.to_i.days
  selected_date = formatted_date.strftime("%B %d, %Y")
  step "I select \"#{selected_date}\" for \"##{date_filter}\" from datepicker"
end

When /^I should see "([^\"]*)" days after program creation as due date for "([^\"]*)"$/ do |days, date_filter|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  formatted_date = program_albers.created_at + days.to_i.days
  selected_date = formatted_date.strftime("%B %d, %Y")
  assert page.evaluate_script("jQuery('#mentoring_model_facilitation_template_specific_date').val() == '#{selected_date}'")
end

When /^I edit the user goal$/ do
  goal_id = MentoringModel::Goal.last.id
  step "I fill in \"mentoring_model_goal_title_#{goal_id}\" with \"EDITED GOAL TITLE\""
end

When /^I edit the user milestone$/ do
  mm_id = MentoringModel::Milestone.last.id
  step "I fill in \"cjs_mentoring_model_milestone_title_#{mm_id}\" with \"EDITED MILESTONE TITLE\""
end

Then /^I open the last created milestone$/ do
  mm_id = MentoringModel::Milestone.last.id
  step "I click \".cjs_milestone_description_handler_#{mm_id}\""
end

When /^I mark the task "([^\"]*)" complete$/ do |task_title|
  page.execute_script("jQuery(\"span:contains('#{task_title}')\").first().parents(\".cjs-task-title-handler\").find(\"input[type='checkbox']\").click()")
end

Then /^I click task title$/ do
  task_id = MentoringModel::Task.last.id
  step "I click \"#mentoring_model_task_#{task_id} .cjs_expand_mentoring_model_task\""
end

Then /^I click on add new comment$/ do
  task_id = MentoringModel::Task.last.id
  steps %{
    Then I click on dropdown toggle within ".cjs-task-edit-action-#{task_id}"
    And I follow "Add New Comment"
    Then I wait for ajax to complete
  }
end

Then /^the checkbox for task "([^\"]*)" should( not)? be checked$/ do |task_title, negate|
  task = MentoringModel::Task.where(title: task_title).last
  assert_equal negate.nil?, (page.evaluate_script("jQuery('#cjs-mentoring-model-task-#{task.id}').prop('checked')") || false)
end

Then /^I add a new comment "([^\"]+)"$/ do |comment|
  task_id = MentoringModel::Task.last.id
  step "I fill in \"mentoring_model_task_comment_content_#{task_id}\" with \"#{comment}\""
end

Then /^I should not see task dropdown$/ do
  assert page.evaluate_script("jQuery(\".cjs-edit-content-header\").find(\".dropdown-toggle\").length == 0")
end

Then /^I hover on last comment$/ do
  comment_id = MentoringModel::Task::Comment.last.id
  step "I hover over \"mentoring_model_task_comment_#{comment_id}_container\""
end

Then /^I click on "([^\"]+)"$/ do |text|
  matcher = ['*', { :text => text }]
  element = page.find(:css, *matcher)
  while better_match = element.first(:css, *matcher)
    element = better_match
  end
  element.click
end

Then /^I click on text "([^\"]+)"$/ do |text|
  step "I click by xpath \"//*[contains(text(),'#{text}')]\""
end

Then /^I submit the answers "([^\"]*)" of "([^\"]*)"$/ do |answers, survey_name|
  survey = Survey.find_by(name: survey_name)
  questions = survey.survey_questions.order(:position)
  answers.split(',').each_with_index do |ans, i|
    ans = ans.gsub("'", '').strip
    if questions[i].choice_based?
      # Do not choose anything if not given.
      unless ans.empty?
        choose "common_answers_#{questions[i].id}_#{ans.downcase}"
      end
    else
      step "I fill in \"common_answers_#{questions[i].id}\" with \"#{ans}\""
    end
  end
  step "I press \"Submit\""
end

Then /^I should see "([^\"]*)" on hovering forum tooltip$/ do |text|
  page.execute_script %Q[jQuery('#mentoring_model_check_box_allow_forum').parents('.cjs_mm_setting_container').find('span[data-toggle="tooltip"]').mouseover();]
  step "I should see \"#{text}\""
end

Then /^I should see "([^\"]*)" on hovering messaging tooltip$/ do |text|
  page.execute_script %Q[jQuery('#mentoring_model_check_box_allow_messaging').parents('.cjs_mm_setting_container').find('span[data-toggle="tooltip"]').mouseover();]
  step "I should see \"#{text}\""
end

Then /^I fill the answers "([^\"]*)" of "([^\"]*)"$/ do |answers, survey_name|
  survey = Survey.find_by(name: survey_name)
  questions = survey.survey_questions.order(:position)
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
      step "I fill in \"survey_answers_#{questions[i].id}\" with \"#{ans}\""
    else
      step "I fill in \"common_answers_#{questions[i].id}\" with \"#{ans}\""
    end
  end
end

Then /^I fill the answers "(.*?)" of "(.*?)" for "(.*?)"$/ do |answers, survey_name, state|
  survey = Survey.find_by(name: survey_name)
  questions = survey.survey_questions.where(condition: (state == "CANCELLED"? SurveyQuestion::Condition::CANCELLED : SurveyQuestion::Condition::COMPLETED)).order(:position)
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
      step "I fill in \"survey_answers_#{questions[i].id}\" with \"#{ans}\""
    else
      step "I fill in \"common_answers_#{questions[i].id}\" with \"#{ans}\""
    end
  end
end

Then /^I see survey details "([^\"]*)" today$/ do |text|
  time = DateTime.localize(Time.now, format: :short)
  #And "I should see \"#{text + time}\""
  step "I should see \"#{text}\""
end

Then /^I check for appropriate assignees on hover$/ do
  task_id = MentoringModel::TaskTemplate.last.id
  within "#mentoring_model_task_template_#{task_id}" do
    page.should have_xpath("//*[div[@id='mentoring_model_task_template_#{task_id}']]/descendant::*[img[@title='Unassigned Task']]")
  end
  task_id = MentoringModel::TaskTemplate.last(2)[0].id
  within "#mentoring_model_task_template_#{task_id}" do
    page.should have_xpath("//*[div[@id='mentoring_model_task_template_#{task_id}']]/descendant::*[img[@title='Assigned to Student']]")
  end
  task_id = MentoringModel::TaskTemplate.last(3)[0].id
  within "#mentoring_model_task_template_#{task_id}" do
    page.should have_xpath("//*[div[@id='mentoring_model_task_template_#{task_id}']]/descendant::*[img[@title='Assigned to Mentor']]")
  end
end

Given /^audit message is enabled for the program "([^"]*)":"([^"]*)"$/ do |arg1, arg2|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,arg1)
  org.audit_user_communication = true
  org.save!
end

Then /^I set a harcoded value for deadline$/ do
  steps %{
    And I select "Specific Date" from "mentoring_model_task_template_date_assigner"
    And I select "1" days after program creation as due date for "mentoring_model_task_template_specific_date"
  }
end

def get_task_section(section)
  case section
    when "completed"; MentoringModel::Task::Section::COMPLETE
    when "overdue"; MentoringModel::Task::Section::OVERDUE
    when "upcoming"; MentoringModel::Task::Section::UPCOMING
    when "pending"; MentoringModel::Task::Section::REMAINING
  end
end

Then /^I follow "([^\"]*)" tasks$/ do |section|
  step "I click \".cjs_tasks_list_handler_#{get_task_section(section)}\""
end

And /^I should see no "([^\"]*)" tasks hidden$/ do |section|
  step "I should see \"#cjs_section_task_empty_list_#{get_task_section(section)}\" hidden"
end

And /^I should see no "([^\"]*)" tasks$/ do |section|
  step "I should see \"#cjs_section_task_empty_list_#{get_task_section(section)}\" not hidden"
end

Then /^I view the milestone "([^"]*)"$/ do |milestone|
  xpath = "//*[contains(text(),'#{milestone}')]/preceding::a[1]"
  step "I click by xpath \"#{xpath}\""
end

When /^I choose the survey "([^"]*)"$/ do |survey|
  step "I select \"#{survey}\" from \"mentoring_model_task_template_action_item_id\""
end