And /^allow_non_match_connection set to false for program "([^\"]*)"$/ do |program_root|
  program = Program.find_by(root: program_root)
  program.update_column(:allow_non_match_connection, false)
end

And /^zero_match_score_message set to "([^\"]*)" for program "([^\"]*)"$/ do |message, program_root|
  program = Program.find_by(root: program_root)
  program.update_attribute(:zero_match_score_message, message)
end

And /^mentor_request_style set to MENTEE_TO_MENTOR for program "([^\"]*)"$/ do |program_root|
  program = Program.find_by(root: program_root)
  program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
end

And /^Mentor "([^\"]*)" did not match student "([^\"]*)" in program "([^\"]*)"$/ do |mentor_email, student_email, program_root|
  program = Program.find_by(root: program_root)
  student = Member.find_by(email: student_email).user_in_program(program)
  @mentor = program.mentor_users.joins(:member).where('members.email' => mentor_email).first
  find_condition = {:student_id => student.id, "mentor_hash.#{@mentor.id}" => { '$exists' => true }}
  Matching::Persistence::Score.collection.update_one(find_condition, { :$set => {"mentor_hash.#{@mentor.id}" => [0.0, true]}})
end

And /^I visit the last page/ do
  page.execute_script("jQuery(\"ul.pagination li a\").eq(-2).click()")
end

And /^The match score should show 'Not a match' for the not matched mentor$/ do
  selector = "#mentor_#{@mentor.id}"
  within (first(selector)) do
    page.has_content?("feature.user.label.not_a_match".translate)
  end
end

And /^Connect menu should include 'Send message' only for the not matched mentor$/ do
  within (first("#mentor_#{@mentor.id}")) do
   step "I follow \"Connect\""
  end
  selector = "#mentor_#{@mentor.id} .dropdown-menu"
  within (first(".disabled")) do
    step "I should see \"Request Mentoring Connection\""
  end
  within selector do
    page.text == "feature.user.label.send_message".translate
  end
end

And /^I hover over the match score and should see "([^\"]*)"$/ do |message|
  selector = "mentor_#{@mentor.id} .ct-match-percent"
  step "I hover over \"#{selector}\" and should see \"#{message}\""
end

And /^"Available Next" is not a link for the given non matched mentor$/ do
  page.should_not have_css("#cjs_availability_#{@mentor.id} a")
end

And /^I follow the profile of non matched mentor$/ do
  step "I follow \"#{@mentor.name}\""
end

And /^I should see disabled "([^\"]*)"$/ do |title|
  text = clear_utf_symbols(title)
  within (first(".disabled")) do
    step "I should see \"#{text}\""
  end
end

And /^I hover over the disabled link and should see "([^"]*)"$/ do |message|
  message = clear_utf_symbols(message)
  selector = "mentor_profile .disabled"
  step "I hover over \"#{selector}\" and should see \"#{message}\""
end

And /^I should see disabled Request Meeting$/ do
  page.should have_xpath("//div[@class='cui-qtip-contentwrapper popup mentor_info']/div[@id='mentor_#{@mentor.id}']/div[@class='pic-offset3']/span[@class='disabled_link']")
end