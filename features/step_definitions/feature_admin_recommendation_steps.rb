Given /^Admin assigns a published mentor recommendation of "([^"]*)" and "([^"]*)" mentors to "([^"]*)" user in program "([^"]*)":"([^"]*)"$/ do |mentor_email_1, mentor_email_2, user_email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  admin = program.admin_users.first

  current_user = Member.find_by(email: user_email).user_in_program(program)
  mentor_1 = Member.find_by(email: mentor_email_1).user_in_program(program)
  mentor_2 = Member.find_by(email: mentor_email_2).user_in_program(program)

  m = MentorRecommendation.new
  m.program = program
  m.sender = admin
  m.receiver = current_user
  m.status = MentorRecommendation::Status::PUBLISHED
  #creating recommendation preferences
  m.recommendation_preferences.build(position: 1, preferred_user: mentor_1)
  m.recommendation_preferences.build(position: 2, preferred_user: mentor_2)    
  m.save!
end

Given /^"([^"]*)" user of program "([^"]*)":"([^"]*)" has no permission to view mentors$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  user = Member.find_by(email: email).user_in_program(program)
  user.roles.find_by(name: "student").remove_permission("view_mentors")
end

Given /^The "([^"]*)" user has a published mentor recommendation in program "([^"]*)":"([^"]*)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  assert user.published_mentor_recommendation.present?
end

Given /^The "(.*?)" user has no ignored preferences in program "(.*?)":"(.*?)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  assert user.ignore_preferences.destroy_all
end

Given /^program "(.*?)":"(.*?)" has mentor recommendations feature enabled$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  program.enable_feature(FeatureName::MENTOR_RECOMMENDATION, true)
end

Then /^I should see "([^"]*)" of "([^"]*)":"([^"]*)" program as preference$/ do |user_email, subdomain, prog_root|
  given_user = Member.find_by(email: user_email).user_in_program(get_program(prog_root, subdomain))
  assert page.has_css?("div", "##{given_user.id}.mentor_preference")
end

Then /^I should not see "([^"]*)" of "([^"]*)":"([^"]*)" program as preference$/ do |user_email, subdomain, prog_root|
  given_user = Member.find_by(email: user_email).user_in_program(get_program(prog_root, subdomain))
  assert page.evaluate_script(%{jQuery("##{given_user.id}.mentor_preference").length}) == 0
end

Then /^the mentor preference order must be correct$/ do
  positions = page.evaluate_script('jQuery(".position-div").size();')
  positions.times do |position|
    assert page.evaluate_script("jQuery('.position-div')[#{position}].textContent;").match((position+1).to_s)
  end
end

Then /^I click on "([^"]*)" user of "([^"]*)":"([^"]*)" program in recommended box$/ do |mentor_email, subdomain, prog_root|
  mentor_id = Member.find_by(email: mentor_email).user_in_program(get_program(prog_root, subdomain)).id
  page.evaluate_script(%{jQuery("#dropdown-#{mentor_id}")[0].click()})
end

Then /^I remove "([^"]*)" of "([^"]*)":"([^"]*)" program as preference$/ do |mentor_email, subdomain, prog_root|
  mentor_id = Member.find_by(email: mentor_email).user_in_program(get_program(prog_root, subdomain)).id
  page.evaluate_script(%{jQuery("##{mentor_id} .remove-mentor-request")[0].click()})
end

Then /^I should see "([^"]*)" user of "([^"]*)":"([^"]*)" program as recommended$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  step "I filter a mentor with name \"#{member.first_name}\" using quick find"
  step "I wait for ajax to complete"
  within (first(:css, "#mentor_#{user.id}")) do
    step "I should see \"Recommended\""
  end
end

Given /^"([^"]*)" user have no pending mentor requests in program "([^"]*)":"([^"]*)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  MentorRequest.where(sender_id: user.id, closed_at: nil).destroy_all
end

Given /^"([^"]*)" user have no admin mentor recommendations in program "([^"]*)":"([^"]*)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  user.mentor_recommendation.try(:destroy)
end

Given /^"([^"]*)" user is not part of any active connection in program "([^"]*)":"([^"]*)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)

  admin_user = program.admin_users.first
  user.groups.active.each do |g|
    g.terminate!(admin_user, "Test reason", program.permitted_closure_reasons.first.id)
  end
end

Given /^"(.*?)" user does not have any mentors in program "(.*?)":"(.*?)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  user.studying_groups.each do |g|
    g.destroy!
  end
end

Given /^"(.*?)" user does not have any meetings in program "(.*?)":"(.*?)"$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  program.meetings.non_group_meetings.where(mentee_id: member.id).destroy_all
end

Then /^I select user with email "([^"]*)" from dropdown in "([^"]*)":"([^"]*)" program$/ do |email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  element_id = "#dropdown-#{user.id}"
  step "I click \"#{element_id}\""
end