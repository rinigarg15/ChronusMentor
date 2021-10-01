And /^"([^\"]*)":"([^\"]*)" is admin-matching only program$/ do |subdomain, root|
  program = get_program(root, subdomain)
  program.update_column(:mentor_request_style, Program::MentorRequestStyle::NONE)
end

And /^I follow \"Connect\" pertaining to the mentor "([^"]*)" in \"Find a Mentor\" page$/ do |user_name|
  xpath = "//div[descendant::a[contains(text(),'#{user_name}')]]/preceding-sibling::div/a[contains(text(), 'Connect')]"
  step "I click by xpath \"#{xpath}\""
end

And /^I choose mentee view as "([^"]*)" and mentor view as "([^"]*)"$/ do |mentee_view, mentor_view|
  steps %{
    And I click "#s2id_bulk_match_mentee_view_id > .select2-choice"
    And I click on select2 result "#{mentee_view}"
    When I click "#s2id_bulk_match_mentor_view_id > .select2-choice"
    And I click on select2 result "#{mentor_view}"
  }
end

And /^I follow "([^"]*)" pertaining to the student "([^"]*)" in \"Bulk Match\" page$/ do |action, user_name|
  xpath = "//tr[descendant::a[contains(text(),'#{user_name}')]]/*/*/*/a[contains(text(),'#{action}')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end

And /^I select "([^"]*)" as mentor for "([^"]*)" in \"Bulk Match\" page$/ do |mentor_name, student_name|
  quick_search_xpath = "//tr[descendant::a[contains(text(),'#{student_name}')]]/*/div[contains(@class,'quick_search_mentors')]"
  mentor_xpath = "#{quick_search_xpath}/*/*/*/*/*[descendant::b[contains(text(), '#{mentor_name}')]]"

  steps %{
    And I click by xpath "#{quick_search_xpath}/div/input"
    And I fill xpath "#{quick_search_xpath}/div/input" with "#{mentor_name}"
    And I click by xpath "#{mentor_xpath}"
  }
end

And /^I select the student "([^"]*)" in \"Bulk Match\" page$/ do |student_name|
  xpath = "//tr[descendant::a[contains(text(),'#{student_name}')]]/td/input"
  step "I click by xpath \"#{xpath}\""
end

And /^I should see available slots as "([^"]*)" for the mentor "([^"]*)" in \"Bulk Match\" page$/ do |count, mentor_name|
  page.should have_xpath("//td[descendant::a[contains(text(), '#{mentor_name}')]][descendant::*/text()[normalize-space(.)=', Available slots: #{count}']]")
end

And /^I should see ongoing connections count as "([^"]*)" for the mentor "([^"]*)" in \"Bulk Match\" page$/ do |count, mentor_name|
  page.should have_xpath("//td[descendant::a[contains(text(), '#{mentor_name}')]][descendant::*/text()[normalize-space(.)='Ongoing mentoring connections: #{count}']]")
end

And /^I should see "([^"]*)" as "([^"]*)" mentors for "([^"]*)" in \"Bulk Match\" page$/ do |mentors_list, type, student_name|
  within(find(:xpath, "//tr[descendant::a[contains(text(),'#{student_name}')]]")) do
    step "I should see \"#{type.capitalize} to: #{mentors_list}\""
  end
end

And /^I update the last connection's name to "([^"]*)"$/ do |name|
  group = Group.order("created_at DESC").first
  group.name = name
  group.save!
end

And /^I verify the link to the drafted connection "([^"]*)" in groups alert$/ do |group_name|
  new_window = window_opened_by do
    step "I follow \"#{group_name}\""
  end
  step "I switch to latest window"
  within_window(new_window) do
    steps %{
      And I should see "Drafted" selected under group tabs
      And I should see "Mentoring Connection Name" in Applied Filters
    }
  end
  new_window.close
  step "I set the focus to the main window"
end

And /^I follow publish for the connection "([^"]*)" from connections listing$/ do |group_name|
  group = Group.find_by(name: group_name)
  xpath = "//a[contains(@class,'publish_group_#{group.id}_web')]"
  step "I click by xpath \"#{xpath}\""
end

And /^I select the connection "([^"]*)" in connections listing$/ do |group_name|
  group = Group.find_by(name: group_name)
  xpath = "//input[@id='cjs_groups_record_#{group.id}']"
  step "I click by xpath \"#{xpath}\""
end

And /^I add "([^"]*)" to the connection "([^"]*)"$/ do |emails, group_name|
  group = Group.find_by(name: group_name)
  users = group.program.all_users.joins(:member).where("members.email IN (?)", emails.split(","))
  mentors = group.mentors
  students = group.students
  users.each { |user| user.is_mentor? ? (mentors << user) : (students << user) }
  group.update_members(mentors, students)
end

And /^I should see mentee requests mentor option disabled$/ do
  step "element with id \"#program_mentor_request_style_0\" should be disabled"
end

And /^I should see mentor offers mentee option disabled$/ do
  step "element with id \"#cjs_offer_mentor_check\" should be disabled"
end

Then /^I check "([^"]*)" for the template with title "([^"]*)"$/ do |check_box, title|
  mentoring_model_id = MentoringModel.find_by(title: title).id
  step "I choose radio button with label \"#{check_box}\" within \"#mentoring_model_#{mentoring_model_id}\""
end