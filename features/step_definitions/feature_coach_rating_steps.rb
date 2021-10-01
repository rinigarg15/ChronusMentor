Then /^I create rating for mentor with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)"$/ do |email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  program.enable_feature(FeatureName::COACH_RATING, true)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)
  group = mentor.groups.published.first

  feedback_form = program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first
  Feedback::Response.create_from_answers(group.students.first, mentor, 4.5, group, feedback_form, {feedback_form.questions.first.id => "very helpful"})
end

Then /^I close group for student with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)"$/ do |email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  student = member.user_in_program(program)
  group = student.studying_groups.first
  group.terminate!(program.admin_users.first, "Test reason", program.permitted_closure_reasons.first.id)
end

Then /^I hover over rating of mentor with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)"$/ do |email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)

  step "I hover over \"mentor_rating_#{mentor.id}\""
end

Then /^I open ratings of mentor with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)"$/ do |email, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  mentor = member.user_in_program(program)

  step "I follow \"mentor_reviews_#{mentor.id}\""
end