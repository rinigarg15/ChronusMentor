And /^I fill in the extended profile fields "([^\"]*)" for "([^\"]*)" with "([^\"]*)"$/ do |fields, role, text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,'primary')
  p = org.programs.find_by(root: 'albers')
  fields.split(',').each do |f_text|
    p.profile_questions_for(role).select{|q| q.question_text==f_text}.each do |ques|
      step "I fill in \"profile_answers_#{ques.id}\" with \"#{text}\""
    end
  end
end

And /^I give permission to admins in program "([^\"]*)":"([^\"]*)"$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  program.update_attribute(:allow_track_admins_to_access_all_users, true)
end

Given /^I suspend member with email "([^\"]*)"$/ do |email|
  member = Member.find_by(email: email)
  member.update_attribute(:state, Member::Status::SUSPENDED)
end

Given /^I remove member with email "([^\"]*)" as global admin$/ do |email|
  member = Member.find_by(email: email)
  member.update_attribute(:admin, false)
end

Then /^the state of "([^\"]*)" should be dormant$/ do |email|
  member = Member.find_by(email: email)
  assert_equal member.state, Member::Status::DORMANT
end

And /^I reset the password for member with email "([^\"]*)"$/ do |email|
  member = Member.find_by(email: email)
  member.update_attribute(:crypted_password, nil)
  member.login_identifiers.destroy_all
end

Then /^I should see "(.*?)" in green color$/ do |section_title|
  section_id = Section.find_by(title: section_title).id
  page.evaluate_script(%Q[jQuery(".#{section_id}").find("i.fa").hasClass("text-navy")])
end

Then /^I should see "(.*?)" in gray color$/ do |section_title|
  section_id = Section.find_by(title: section_title).id
  page.evaluate_script(%Q[jQuery(".#{section_id}").find("i.fa").hasClass("text-gray")])
end

When /^I (set|reset) filter by program "([^\"]*)":"([^\"]*)"$/ do |_, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  step "I click \"#filter_program_id_#{program.id}\""
end

When /^I (set|reset) filter by role "([^\"]*)" of "([^\"]*)":"([^\"]*)"$/ do |_, role_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  role_id = program.find_role(role_name).id
  step "I click \"#filter_role_#{role_id}\""
end