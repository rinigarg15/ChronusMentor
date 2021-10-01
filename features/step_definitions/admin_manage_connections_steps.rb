And /^I click on dropdown of the group "([^\"]*)"$/ do |group_name|
  group = Group.find_by(name: group_name)
  within "#group_#{group.id}" do
    step "I click \".dropdown-toggle\""
  end
end

Then /^I should see "([^\"]*)" in the group "([^\"]*)"$/ do |notes, group_name|
  group = Group.find_by(name: group_name)
  within "#group_pane_#{group.id}" do
    step "I should see \"#{notes}\""
  end
end

Then /^I remove "([^\"].*)" from the connection "([^\"].*)"$/ do |email, group_name|
  steps %{
    And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
    Then I should see "Add/Remove Members"
    And I follow "Add/Remove Members"
    Then I should see "Update Members for the Mentoring Connection Mentors"
  }
  remove_from_select2("PSG mentora")
  step "I press \"Save\""
end

Then /^I add a member to the connection "([^\"].*)"$/ do |group_name|
 group = Group.find_by(name: group_name)
 steps %{
   And I click on dropdown of the group "mentora, mentorb, mentorc, psg, psg, & psg"
   Then I should see "Add/Remove Members"
   And I follow "Add/Remove Members"
   Then I follow "Add" within "div.mentor_list"
 }
 page.execute_script("jQuery('input#group_new_mentor_#{group.id}').val('PSG mentora <mentor1@psg.com>')")
 steps %{
   Then I follow "Add" within "div#add_mentor_#{group.id}"
   Then I should see "To be added"
   And I press "Save"
   Then I should see "PSG mentora" within "dd"
 }
end

And /^I fill in "([^\"]*)" with a date "([^\"]*)"$/ do |field, text|
  page.execute_script("jQuery('##{field}').val('#{text}');")
end

Then /^I should see "([^\"]*)" under group tabs$/ do |tab_name|
  within "#cjs_groups_listing #tab-box" do
    step "I should see \"#{tab_name}\""
  end
end

Then /^I should see "([^\"]*)" selected under group tabs$/ do |tab_name|
  within "#cjs_groups_listing #tab-box" do
    within "li.active" do
      step "I should see \"#{tab_name}\""
    end
  end
end

Then /^I should see "([^\"]*)" in user's group tabs$/ do |tab_name|
  within ".inner_tabs" do
    step "I should see \"#{tab_name}\""
  end
end

Then /^I should see "([^\"]*)" selected in user's group tabs$/ do |tab_name|
  within ".inner_tabs" do
    within "li.active" do
      step "I should see \"#{tab_name}\""
    end
  end
end

Then /^I should see "([^\"]*)" in the first row for groups$/ do |tab_name|
  within "#cjs_groups_listing #groups tr.list_content" do
    step "I should see \"#{tab_name}\""
  end
end

Then /^I remove all fields to display$/ do
  within "div.multiselect-selected-list" do
    step "I click \"span.ui-icon-arrowthickstop-1-w\""
  end
  step "I click \"#cjs_update_view .form-actions .btn-primary\""
end

Then /^I select all mentor columns$/ do
  within "div.multiselect-available-list" do
    step "I click \"span.ui-icon-arrowthickstop-1-e\""
  end
  within (first(:css,"div.ui-priority-secondary")) do
    step "I click \"span.ui-icon-arrowstop-1-w\""
  end
  step "I click \"#cjs_update_view .form-actions .btn-primary\""
end

And /^I click to sort connections by name$/ do
  program = Program.find_by(name: "Albers Mentor Program")
  name_column = program.group_view.group_view_columns.default.find_by(column_key: "name")
  page.execute_script("jQuery(column_#{name_column.id}).click()")
end

And /^I create overdue survey task$/ do
  program = Program.find_by(name: "Albers Mentor Program")
  member = Member.find_by(email: "robert@example.com")
  user = member.user_in_program(program)
  group = user.groups.first
  cm = group.membership_of(user)
  mentoring_model = program.mentoring_models.default.first

  group.update_attribute(:mentoring_model_id, mentoring_model.id)

  survey = program.surveys.find_by(name: "Mentoring Relationship Health")

  task_template = MentoringModel::TaskTemplate.new(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :action_item_id => survey.id, title: "task template title", duration: 1, role_id: program.roles.find{|r| r.name == RoleConstants::MENTOR_NAME }.id)
  
  task_template.mentoring_model_id = mentoring_model.id
  task_template.skip_survey_validations = true
  task_template.save!

  task = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, mentoring_model_task_template_id: task_template.id, connection_membership_id: cm.id, due_date: Time.now-1.day, required: true, status: MentoringModel::Task::Status::TODO, :group => group, :user => user)
end

Given /^I click the "([^"]*)" field with enclosure id as "([^"]*)" of "([^"]*)":"([^"]*)"$/ do |role_name, selector, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  dom_selector = "#s2id_group_members_role_id_#{role.id} " + selector
  step "I click \"#{dom_selector}\""
end

Given /^I fill in "([^"]*)" with "([^"]*)" role from "([^"]*)":"([^"]*)" in the filter box$/ do |content, role_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name.downcase)
  dom_selector = "member_filters_#{role.id}"
  step "I fill in \"#{dom_selector}\" with \"#{content}\""
end

def remove_from_select2(value)
  page.execute_script %Q[jQuery("[class=\'select2-search-choice-close\']").first().click();]
end

def select2(text)
  # page.execute_script %Q[jQuery("[class=\'select2-input\']").first().click();]
  page.find(".select2-input").first.click
  page.all("ul.select2-results li").each do |e|
    if e.text == text
      e.click
      return
    end
  end
end

Then /^I change mentoring mode of mentor with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)" to "([^\"]*)"$/ do |email, organization_subdomain, program_root, mentoring_mode|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  if mentoring_mode == "one time"
    change_to_mentoring_mode = User::MentoringMode::ONE_TIME
  elsif mentoring_mode == "ongoing"
    change_to_mentoring_mode = User::MentoringMode::ONGOING
  end
  user.update_attribute(:mentoring_mode, change_to_mentoring_mode)
  user.reload
end

Then /^admin terminate connection with name "([^\"]*)" of member with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)"$/ do |name, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  user = program.admin_users.first

  Member.find_by(email: email).groups.where(name: name).first.terminate!(user, "reason1", "reason2")
end

When /^I add the following "([a-z]+)" with names "([^\"]*)"$/ do |role_name, users|
  label_text = role_name == "mentors" ? "Mentors" : "Students"
  if users.present?
    step "I close all open select2 dropdowns"
    xpath_selector = "//label[contains(text(),\'#{label_text}\')]/following::input"
    users.split(',').each do |user|
      sleep 0.5
      steps %{
        And I click by xpath "#{xpath_selector}"
        And I fill xpath "#{xpath_selector}" with "#{user}"
        And I click on select2 result "#{user}"
      }
    end
    step "I close all open select2 dropdowns"
  end
end

Then /^I find no matches for the "([a-z]+)" with names "([^\"]*)"$/ do |role_name, users|
  label_text = role_name == "mentors" ? "Mentors" : "Students"
  if users.present?
    step "I close all open select2 dropdowns"
    xpath_selector = "//label[contains(text(),\'#{label_text}\')]/following::input"
    users.split(',').each do |user|
      sleep 0.5
      steps %{
        And I click by xpath "#{xpath_selector}"
        And I fill xpath "#{xpath_selector}" with "#{user}"
        And I should see "No matches found"
      }
    end
    step "I close all open select2 dropdowns"
  end
end

Then /^I remove "([^\"]*)" from the selected list$/ do |user|
  remove_from_select2(user)
  sleep 0.5
end

And /^I follow "([^\"]*)" in connection admin notes section$/ do |action_text|
  within "#admin_group_notes_section" do
    if action_text == "Edit"
      step "I follow \"Edit\""
      step "I should not see \"Add Notes\""
    elsif action_text == "Add Notes"
      step "I follow \"Add Notes\""
      step "I should not see \"Edit\""
    end
  end
end

And /^I should see "([^\"]*)" in connection admin notes section$/ do |content|
  within "#admin_group_notes_section" do
    step "I should see \"#{content}\""
  end
end

And /^I should not see "([^\"]*)" in connection admin notes section$/ do |content|
  within "#admin_group_notes_section" do
    step "I should not see \"#{content}\""
  end
end

And /^I have updated the closed group "([^\"]*)" with notes "([^\"]*)"$/ do |group, notes|
  group = Group.where(status: Group::Status::CLOSED, name: group)[0]
  group.update_attributes!(notes: notes)
end

Then /^I should see "([^\"]*)" as "([^\"]*)" of the closed group "([^\"]*)"$/ do |user_name_with_email, role, group|
  group = Group.where(status: Group::Status::CLOSED, name: group)[0]
  role = if role == "mentor"
          group.program.roles.find_by(name: RoleConstants::MENTOR_NAME)
        elsif role == "mentee"
          group.program.roles.find_by(name: RoleConstants::STUDENT_NAME)
        end

  assert_equal user_name_with_email, page.evaluate_script("jQuery(\"#group_members_role_id_#{role.id}\").val()")
end


Then /^I should see "([^\"]*)" in group attribute "([^\"]*)"$/ do |value, ele_id|
  assert_equal value, page.evaluate_script("jQuery(\"#{ele_id}\").val()")
end

And /^I choose Add "([^\"]*)"-assigned tasks$/ do |role_name|
  role_id = Program.find_by(root: "albers").find_role(role_name).id
  step "I choose \"group_add_member_option_0_#{role_id}\""
end

And /^I choose \"Do not add any tasks\" for "([^\"]*)" role in "([^\"]*)":"([^\"]*)"$/ do |role_name, organization_subdomain, program_root|
  role_id = get_program(program_root, organization_subdomain).find_role(role_name).id
  step "I choose \"group_add_member_option_1_#{role_id}\""
end