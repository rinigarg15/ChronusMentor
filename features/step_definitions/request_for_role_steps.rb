Then /^I call "([^\"]*)" role as "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |role_name, coustom_name, subdomain, prog_root|
	program = get_program(prog_root, subdomain)
	organization = program.organization
	case role_name
		when 'student'
			program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute(:term, coustom_name)
		when 'mentor'
			program.roles.find_by(name: RoleConstants::MENTOR_NAME).customized_term.update_attribute(:term, coustom_name)
	end
end

Then /^I add "([^\"]*)" permission for "([^\"]*)" role in "([^\"]*)":"([^\"]*)"$/ do |permission, role_name, subdomain, prog_root|
	program = get_program(prog_root, subdomain)
	program.add_role_permission(role_name, permission)
end

Then /^I remove "([^\"]*)" permission for "([^\"]*)" role in "([^\"]*)":"([^\"]*)"$/ do |permission, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  program.remove_role_permission(role_name, permission)
end

Then /^I add a membership question in non default section for mentor and student roles in "([^"]*)":"([^"]*)"$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  pq = program.organization.profile_questions.where(question_text: 'About Me').first
  pq.role_questions.each do |rq|
    rq.available_for = RoleQuestion::AVAILABLE_FOR::BOTH
    rq.save
  end
end

Then /^I add profile questions for "([^\"]*)" role in "([^"]*)":"([^"]*)"$/ do |role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role = program.find_role(role_name)
  pq = program.organization.profile_questions.where(question_text: 'About Me').first
  rq = pq.role_questions.create(role_id: role.id)
end

Then /^I should not see join options for "([^"]*)":"([^"]*)"$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  step "I should not see \"enrollment_page_join_#{program.id}\""
end