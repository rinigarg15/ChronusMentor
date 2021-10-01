Given /^"([^\"]*)" role have permission to "([^\"]*)" in "([^\"]*)"$/ do |role_name, permission, program_name|
  program =  Program.find_by(name: program_name)
  role = program.roles.find_by(name: role_name)
  role.add_permission(permission)
  role.save!
end

And /^I have permission to add mentors$/ do
  all_student_roles = Role.where(name: RoleConstants::STUDENT_NAME)
    all_student_roles.each do |role|
      role.add_permission('invite_mentors')
    end
end

And /^I have permission to add students$/ do
  all_mentor_roles = Role.where(name: RoleConstants::MENTOR_NAME)
    all_mentor_roles.each do |role|
      role.add_permission('invite_students')
    end
end

And /^the invitations to mentors should be really sent$/ do
  i = ProgramInvitation.all.last
  assert_equal i[:message], "Yoyo dude, you have been invited as a mentor"
  assert_equal i[:sent_to], "no_yoyo@chronus.com"
  assert_equal i.role_names, ["mentor"]
end

And /^the invitations to students should be really sent$/ do
  i = ProgramInvitation.all.last
  assert_equal i[:message], "Yoyo dude, you have been invited as a student"
  assert_equal i[:sent_to], "no_yoyo@chronus.com"
  assert_equal i.role_names, ["student"]
end

And /^the invitations to mentors and students should be really sent$/ do
  i = ProgramInvitation.all.last
  assert_equal i[:message], "Yoyo dude, you have been invited as a mentor and student"
  assert_equal i[:sent_to], "no_yoyo@chronus.com"
  assert_equal i.role_names, ["mentor", "student"]
end

When /^I choose "([^\"]*)" from "([^\"]*)"$/ do |value,field|
  choose("#{field}_#{value}")
end