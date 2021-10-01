Given /^employees have permission to view other employees$/ do
  program = Program.find_by(name: "Primary Career Portal")
  employee_role = program.get_role(RoleConstants::EMPLOYEE_NAME)
  employee_role.role_permissions.create!(permission_id: Permission.find_by(name: "view_#{RoleConstants::EMPLOYEE_NAME.pluralize}").id)
end

Given /^admins cannot invite employees$/ do
  program = Program.find_by(name: "Primary Career Portal")
  admin_role = program.get_role(RoleConstants::ADMIN_NAME)
  admin_role.permissions.find_by(name: "invite_#{RoleConstants::EMPLOYEE_NAME.pluralize}").destroy
end

Given /^admins cannot add other non admin profiles$/ do
  program = Program.find_by(name: "Primary Career Portal")
  admin_role = program.get_role(RoleConstants::ADMIN_NAME)
  admin_role.permissions.find_by(name: "add_non_admin_profiles").destroy
end

When /^(.*) in the page actions bar$/ do |step_definition|
  within("div#title_actions") do
    step step_definition
  end
end

When /^(.*) in the page canvas$/ do |step_definition|
  within("div#page_canvas") do
    step step_definition
  end
end

When /^I click on dropdown toggle$/ do
  page.find("a.dropdown-toggle", :match => :prefer_exact).click
end

Given /^there are no employees in "([^\"]*)":"([^\"]*)"$/ do |domain, root|
  org = Program::Domain.find_by(subdomain: domain).organization
  program = org.programs.find_by(root: root)

  role = program.get_role(RoleConstants::EMPLOYEE_NAME)
  role.users.each(&:destroy)
end