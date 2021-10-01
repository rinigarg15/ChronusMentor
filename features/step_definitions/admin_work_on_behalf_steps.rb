And /^Mentees cannot publish article$/ do
  Role.find_by(name: "student").remove_permission("write_article")
end

And /^I should see the article contributor "([^\"]*)"$/ do |a|
  assert_equal Member.find_by(first_name: a), Article.last.author
end

Given /^"([^\"]*)" is "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |email, role, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  student = User.find_by_email_program(email, program)
  if role == "student"
    student.add_role(RoleConstants::STUDENT_NAME) unless student.is_student?
  elsif role =="admin"
    student.add_role(RoleConstants::ADMIN_NAME) unless student.is_admin?
  end
end

Then /^wob banner should be shown below Chronus Header$/ do
  page.should have_xpath('//nav[@id="chronus_header"]/div[@id="chronus_header_wrapper"]/following-sibling::div[@id="wob_banner"]')
end

Then(/^I enable WOB in "([^\"]*)"$/) do |sub|
  Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, sub).enable_feature(FeatureName::WORK_ON_BEHALF)
end