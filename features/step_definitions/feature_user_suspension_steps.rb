Given /^the user with email "([^\"]*)" is suspended only in program "([^\"]*)"$/ do |email, root|
  program = Program.find_by(root: root)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  user.update_attribute(:state, User::Status::SUSPENDED)
end

Given /^the user with email "([^\"]*)" is suspended globally$/ do |email|
  member = Member.find_by(email: email)
  admin = member.organization.members.admins.first
  member.suspend!(admin, "Suspension reason", { send_email: false })
end

And /^I should not see view and edit profile links$/ do
  steps %{
    And I should not see "View Profile"
    And I should not see "Edit Profile"
    And I should not see "Account Settings"
  }
end

And /^I should not see "([^\"]*)" in my programs listing$/ do |program_name|
  within ".navbar-header" do
    steps %{
      And I click ".my_programs_listing_link"
      And I should not see "#{program_name}" within ".cui_program_selector"
    }
  end
end

Then /^I should see "([^\"]*)" for program "([^\"]*)" in enrollment page$/ do |content, root|
  program = Program.find_by(root: root)
  step "I should see \"#{content}\" within \".enrollment_program_#{program.id}\""
end

When /^I hover over reactivate membership$/ do
  step "I hover over \"cjs_reactivate_link\""
end

And /^I should see "([^\"]*)" in the row of "([^\"]*)" "([^\"]*)"$/ do |content, object_type, email|
  user_or_member = (object_type == User.name.downcase) ? get_user(email) : Member.find_by(email: email)
  step "I should see \"#{content}\" in the row \"ct_admin_view_checkbox_#{user_or_member.id}\""
end

And /^I should not see "([^\"]*)" in the row of "([^\"]*)" "([^\"]*)"$/ do |content, object_type, email|
  user_or_member = (object_type == User.name.downcase) ? get_user(email) : Member.find_by(email: email)
  step "I should not see \"#{content}\" in the row \"ct_admin_view_checkbox_#{user_or_member.id}\""
end

When /^I add "([^\"]*)" to the program "([^\"]*)" as "([^\"]*)"$/ do |email, program, roles|
  roles = roles.split(COMMON_SEPARATOR)
  member = Member.find_by(email: email)
  steps %{
    And I check "ct_admin_view_checkbox_#{member.id}"
    And I follow "Actions"
    And I click on "cjs_add_to_program" in Actions
    And I should see "Note: This action does not apply for users suspended in #{member.organization.name}."
    And I should see "#{member.name}"
    Then I select "#{program}" from "admin_view_program_id"
  }
  roles.each do |role|
    step "I check \"#{role}\""
  end
  step "I press \"Submit\""
end

When /^I invite "([^\"]*)" to the program "([^\"]*)" as "([^\"]*)"$/ do |email, program, roles|
  roles = roles.split(COMMON_SEPARATOR)
  member = Member.find_by(email: email)
  steps %{
    And I check "ct_admin_view_checkbox_#{member.id}"
    And I follow "Actions"
    And I click on "cjs_invite_to_program" in Actions
    And I should see "Note: This action does not apply for users suspended in #{member.organization.name}."
    And I should see "#{member.name}"
    Then I select "#{program}" from "admin_view_program_id"
    And I choose "role_assign_roles"
  }
  roles.each { |role| And "I check \"#{role}\"" }
  step "I press \"Send Invites\""
end

And /^I should not see "([^\"]*)" in admin actions pane$/ do |content|
  step "I should not see \"#{content}\" within \"div#admin_actions\""
end

Given /^"([^\"]*)" is promoted as global admin$/ do |email|
  member = Member.find_by(email: email)
  member.update_attribute(:admin, true)
end

And /^I should see the rows are sorted by "([^\"]*)"$/ do |column_name|
  step "I should see \"#{column_name}\" within \"tr.cui_table_sort th.sort_asc\""
end

Then /^I visit the global profile of "([^\"]*)"$/ do |email|
  m = Member.find_by(email: email)
  visit member_path(m, organization_level: true)
end

private

def get_user(email, root = "albers")
  program = Program.find_by(root: root)
  member = Member.find_by(email: email)
  user = member.user_in_program program
end