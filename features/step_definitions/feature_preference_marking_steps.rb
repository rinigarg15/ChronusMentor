Then /^I click "(.*?)" of mentor recommendation with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |class_element, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)
  step "I click \"#{class_element}\" within \"div#user_#{mentor.id}\""
end

Then /^I click "(.*?)" of mentor with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |class_element, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)
  step "I click \"#{class_element}\" within \"div#mentor_#{mentor.id}\""
end

Then /^I follow "(.*?)" for user with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |text, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)

  step "I follow \"#{text}\" within \".mentor_#{mentor.id}\""
end

Then /^I should not see "(.*?)" of mentor with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |text, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)
  step "I should not see \"#{text}\" within \"#mentor_#{mentor.id}\""
end

Then /^I should see "(.*?)" of mentor with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |text, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)

  step "I should see \"#{text}\" within \"#mentor_#{mentor.id}\""
end

Then /^I follow "(.*?)" text for user with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |text, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)

  step "I follow \"#{text}\" within \"div#mentor_#{mentor.id}\""
end

Then /^I follow "(.*?)" link for user with email "(.*?)" in program "(.*?)":"(.*?)"$/ do |text, email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)

  step "I follow \"#{text}\" within \"div#user_#{mentor.id}\""
end
