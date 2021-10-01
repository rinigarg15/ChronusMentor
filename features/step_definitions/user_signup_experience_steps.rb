When /^the current program admin has added required questions for "([^\"]*)"(?: to "([^\"]*)")?$/ do |role, section|
  p = Program.find_by(root: "albers")
  org = p.organization
  section = org.sections.find_by(title: section || "Mentoring Profile")
  role = p.get_role([role])
  prof_q = ProfileQuestion.create!(:organization => org, :question_type => CommonQuestion::Type::STRING, :section => section,
    :question_text => "Whats your age?")
  prof_q.role_questions.create!(:required => true, :role => role)
end

And /^a required education question is added for "([^\"]*)"(?: to "([^\"]*)")?$/ do |role, section|
  p = Program.find_by(root: "albers")
  org = p.organization
  section = org.sections.find_by(title: section || "Mentoring Profile")
  role = p.get_role([role])
  prof_q = ProfileQuestion.create!(:organization => org, :question_type => ProfileQuestion::Type::EDUCATION, :section => section,
    :question_text => "School")
  prof_q.role_questions.create!(:required => true, :role => role)
end

When /^Admin sends program invitation email to "([^\"]*)" as "([^\"]*)"$/ do |arg1, arg2|
  p = Program.find_by(root: "albers")
  ProgramInvitation.create!(
    :sent_to => arg1,
    :user => p.admin_users.first,
    :program => p,
    :role_names => [arg2],
    :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE,
    :message => 'some message')
end

Then /^I answer the required questions for "([^\"]*)"$/ do |arg1|
  p = Program.find_by(root: "albers")
  u = User.find_by_email_program(arg1, p)
  q = p.role_questions_for(u.role_names.first).required.find { |q| q.profile_question.non_default_type? }.profile_question
  field = "profile_answers_#{q.id}"
  step "I fill in \"#{field}\" with \"Abc\""
end

Then /^I answer the education experience questions for "([^\"]*)"$/ do |arg1|
  steps %{
    And I fill in education_question of "primary":"albers" with "Test School,Test Degree,Test Major"
    And I fill in experience_question of "primary":"albers" with "Test SCompany, Test Job"
  }
end

Then /^I should see the profile update message "([^\"]*)"$/ do |arg1|
  within "div#profile_update" do
    step "I should see \"#{arg1}\""
  end
end

Then /^I should not see the tabs in program header$/ do
  within ("ul#side-menu") do
    steps %{
      Then I should not see "Home"
      Then I should not see "Mentors"
      Then I should not see "Mentees"
      Then I should not see "Advice"
    }
  end 
end

Then /^I try to go to articles page$/ do
  visit articles_path(:root => "albers")
end

Then /^I hover on tab "([^"]*)"$/ do |arg1|
  page.execute_script("jQuery(\"#side-menu li a:contains('#{arg1}')\").click()")
end

Given /^the current program has no announcements for students$/ do
  p = Program.find_by(root: "albers")
  p.announcements.destroy_all 
end

Given /^I visit home page with guidance popup experiment enabled$/ do
  visit root_path(root: "albers", show_guidance_popup: true, from_first_visit: true)
end