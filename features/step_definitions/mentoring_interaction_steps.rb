When /^I create a new goal "([^\"]*)" for "([^\"]*)"$/ do |goal, student|
  p = Program.find_by(root: "albers")
  u = User.find_by_email_program(student, p)
  steps %{
    And "I fill in \"task_title_new\" with \"#{goal}\""
    And "I fill in \"task_due_date_new\" with \"#{Time.now+7.days}\""
  }
  # The student id should be set so that the goal is private
  within "#new_task" do
    step "I press \"Add\""
  end
end

Then /^there are no mentor requests$/ do
  p =Program.find_by(root: "albers")
  p.mentor_requests.delete_all
end

Then /^I fill the last mentor request request text with "([^\"]*)"$/ do |response_text|
  last_mentor_request = MentorRequest.last
  step "I fill in \"mentor_request_response_text_#{last_mentor_request.id}\" with \"#{response_text}\""
end

When /^I create a group goal "([^\"]*)" for "([^\"]*)"$/ do |arg1, arg2|
  steps %{
    And I fill in "task_title_new" with "#{arg1}"
    And I fill in "task_due_date_new" with a date "#{formatted_time_in_words(Time.now+7.days, no_time: true)}"
  }
  within "#new_task" do
    step "I press \"Add\""
  end
end

When /^I create a private goal "([^\"]*)" for "([^\"]*)"$/ do |arg1, arg2|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"annauniv")
  uid = org.members.find_by(email: arg2).users.first.id
  steps %{
    And I fill in "task_title_new" with "#{arg1}"
    And I fill in "task_due_date_new" with a date "#{formatted_time_in_words(Time.now+7.days, no_time: true)}"
  }
  within "div#privacy" do
    choose "goal_privacy_#{uid}"
  end
  within "#new_task" do
    step "I press \"Add\""
  end
end

Then /^I should see the goal "([^\"]*)" for "([^\"]*)"$/ do |arg1, arg2|
  t = Task.find_by(title: arg1)
  within "div#tasks_group #task_wrapper_#{t.id}" do
    step "I should see \"#{arg1}\""
    within("div.assigned") do
      step "I should see \"#{arg2}\""
    end
  end
end

Then /^I checkin with the following details "([^"]*)","([^"]*)"$/ do |hours, minutes|
  page.execute_script("jQuery('select[name=\"group_checkin[hours]\"]').val(#{hours})")
  page.execute_script("jQuery('select[name=\"group_checkin[minutes]\"]').val(#{minutes})")
  step "I press \"Save\""
end

Then /^I filter by checkins today for mentor checkin report$/ do
  steps %{
    And I fill in the date range picker with "#{DateTime.localize(Time.now, format: :full_display_no_time)}" and "#{DateTime.localize(Time.now, format: :full_display_no_time)}"
    And I press "Go"
  }
end