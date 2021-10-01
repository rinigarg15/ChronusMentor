When /^I select "([^\"]*)" from the sub\-program user import selector$/ do |email|
  page.find("#cjs_user_result tr", text: email).find("input[type=checkbox]").set(true)
end

Then /^I should see the role "([^\"]*)" in "([^\"]*)"$/ do |role_name, program_name|
  within "#profile_side_bar" do
    step "I should see \"#{program_name} #{role_name}\""
  end
end

And /^I click on the filter "([^\"]*)"$/ do |m|
  within "form#search_filter_form" do
    step "I follow \"#{m}\""
  end
end

And /^Ram is an admin for nwen and moderated program$/ do
  program_albers = Program.find_by(name: "Albers Mentor Program")
  program_moderated = Program.find_by(name: "Moderated Program")
  program_nwen = Program.find_by(name: "NWEN")
  member_ram = program_albers.organization.members.find_by(email: "userram@example.com")
  create_user :member => member_ram, :program => program_nwen,
    :role_names => [RoleConstants::ADMIN_NAME], :first_name => "ram", :last_name => "nwen_admin"
  create_user :member => member_ram, :program => program_moderated,
    :role_names => [RoleConstants::ADMIN_NAME], :first_name => "ram", :last_name => "moderated_program_admin"
end

Then /^I should see the users from program "([^\"]*)" and filter "([^\"]*)"$/ do |m,n|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  member_ram = program_albers.organization.members.find_by(email: "userram@example.com")
  program_nwen = Program.find_by(name: "NWEN")
  program_moderated = Program.find_by(name: "Moderated Program")
  nwen_members = program_nwen.users.collect(&:member)

  if m == "all" && n=="all"
    users= []
    member_ram.users.each do |u|
      users = users + u.program.users if u.is_admin?
    end
    expected_members = users.collect(&:member) - nwen_members
  end
  
  if m == "all" && n == "mentor"
    users= []
    member_ram.users.each do |u|
      users = users + u.program.users.mentors if u.is_admin?
    end
    expected_members = users.collect(&:member) - nwen_members
  end

  if m == "all" && n == "student"
    users= []
    member_ram.users.each do |u|
      users = users + u.program.users.students if u.is_admin?
    end
    expected_members = users.collect(&:member) - nwen_members
  end

  if m == "albers" && n == "all"
    expected_members = program_albers.users.collect(&:member) - nwen_members
  end

  if m == "albers" && n == "mentor"
    expected_members = program_albers.users.mentors.collect(&:member) - nwen_members
  end

  if m == "albers" && n == "student"
    expected_members = program_albers.users.students.collect(&:member) - nwen_members
  end
  
  if m == "moderated" && n == "all"
    expected_members = program_moderated.users.collect(&:member) - nwen_members
  end

  if m == "moderated" && n == "mentor"
    expected_members = program_moderated.users.mentors.collect(&:member) - nwen_members
  end

  if m == "moderated" && n == "student"
    expected_members = program_moderated.users.students.collect(&:member) - nwen_members
  end

  count = expected_members.count > 25 ? (25 + 2) : (expected_members.count + 1)
  assert page.has_css?('#cjs_user_result tr', :count => count)
  within "#cjs_user_result" do
    expected_members.each do |m|
      step "I should see \"#{m.email}\""
    end
  end
end

Then /^I select two members$/ do
  m1 = Member.find_by(email: "userrahim@example.com").id
  m2 = Member.find_by(email: "userrobert@example.com").id
  check("check_#{m1}")
  check("check_#{m2}")
end

Then /^I select member with email "([^\"]*)"$/ do |email|
  m1 = Member.find_by(email: email).id
  check("check_#{m1}")
end

And /^I click to sort items by first name$/ do
  page.execute_script("jQuery(sort_by_first_name).click()")
end

When /^admin add "([^\"]*)" as "([^\"]*)"$/ do |user_email, role|
  member = Member.find_by(email: user_email).id
  steps %{
    Then I follow "Manage"
    Then I follow "Add Users"
    Then I follow "Add users from Nation Wide Children Hospital Org"
    Then I check "ct_user_checkbox_#{member}"
    Then I follow "Actions"
    Then I follow "Add to Program"
    Then I check "#{role}"
    Then I press "Submit"
  }
end