Then /^I should see "([^\"]*)" answered "([^\"]*)" as "([^\"]*)"$/ do |user_email, question, answer|
  member = Member.find_by(email: user_email)
  parent_element = "#cui_member_#{member.id}"
  steps %{
    Then I should see "#{question}" within "#{parent_element}"
    Then I should see "#{answer}" within "#{parent_element}"
  }
end

When /^the "([^\"]*)" admin has added required questions for "([^\"]*)"(?: to "([^\"]*)")?$/ do |program_name, role, section|
  p = Program.find_by(name: program_name)
  org = p.organization
  section = org.sections.find_by(title: section || "Mentoring Profile")
  role = p.get_role([role])
  prof_q = ProfileQuestion.create!(:organization => org, :question_type => CommonQuestion::Type::STRING, :section => section,
    :question_text => "Whats your age?")
  prof_q.role_questions.create!(:required => true, :role => role)
end

Then /^I add choices "([^\"]*)"$/ do |choices|
  click_link_or_button "Bulk add"
  step "I fill in \"profile_question_0_new_options\" with \"#{choices}\""
  #page.find(:css, '.modal-dialog textarea').set(choices)
  page.find(:css, '.modal-dialog input[type=submit]').click
  step "I wait for ajax to complete"
end

Then /^I replace choices "([^\"]*)"$/ do |choices|
  profile_question_id = ProfileQuestion.last.id
  click_link_or_button "Bulk add"
  #page.find(:css, '.modal-dialog textarea').set(choices)
  step "I fill in \"profile_question_#{profile_question_id}_new_options\" with \"#{choices}\""
  page.find(:css, "#bulk_add_mode_#{profile_question_id}_replace_options").click
  page.find(:css, '.modal-dialog input[type=submit]').click
  step "I wait for ajax to complete"
end

And /^I see choices "([^\"]*)" in order$/ do |choices|
  profile_question_id = ProfileQuestion.last.id
  assert_equal choices, find("#profile_question_choices_list_#{profile_question_id}").text(:all)
end

And /^I don't see choices "([^\"]*)" in order$/ do |choices|
  profile_question_id = ProfileQuestion.last.id
  assert_not_equal choices, find("#profile_question_choices_list_#{profile_question_id}").text(:all)
end

And /^I add choice "([^\"]*)" next to "([^\"]*)"$/ do |new_choice, existing_choice|
  profile_question = ProfileQuestion.last

  choice_id = profile_question.question_choices.find{|choice| choice.text == existing_choice}.id
  page.execute_script("jQuery('#profile_question_#{profile_question.id}_#{choice_id}_container .cjs_add_choice').click()")

  new_element =  page.all(:css, "#profile_question_choices_list_#{profile_question.id} li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == ""
  end

  within(new_element) do
    find(:css, "input[type=text]").set(new_choice)
  end
end

Then /^I edit choice "([^\"]*)" inside the "([^\"]*)" question in "([^\"]*)" to "([^\"]*)"$/ do |choice, question_text, organization_name, new_choice|
  organization = Organization.find_by(name: organization_name)
  profile_question = organization.profile_questions.find_by(question_text: question_text)
  question_choice_id = profile_question.question_choices.find_by(text: choice).id
  find("#profile_question_#{profile_question.id}_#{question_choice_id}_container input[type=text]").set(new_choice)
end

# TODO_PROFILE_CONFIG_UI - remove it after cleanup
Then /^I perform missed migrations$/ do
  ProfileQuestion.where(question_type: ProfileQuestion::Type::EDUCATION).update_all(question_type: ProfileQuestion::Type::MULTI_EDUCATION)
  ProfileQuestion.where(question_type: ProfileQuestion::Type::EXPERIENCE).update_all(question_type: ProfileQuestion::Type::MULTI_EXPERIENCE)
  ProfileQuestion.where(question_type: ProfileQuestion::Type::PUBLICATION).update_all(question_type: ProfileQuestion::Type::MULTI_PUBLICATION)
end