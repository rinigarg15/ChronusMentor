And /I fill the answer "([^\"]*)" with "([^\"]*)"/ do |ques_text, ans_text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  ques = org.profile_questions_with_email_and_name.find_by(question_text: ques_text)
  step "I fill in by css \"profile_answers_#{ques.id}\" with \"#{ans_text}\""
end

Then /I upload the file "([^\"]*)" for the file type question "([^\"]*)"/ do |file_name, question|
  file = fixture_file_upload(File.join('files', file_name))
  FileUploader.expects(:get_file_path).with(kind_of(Integer), kind_of(Integer), kind_of(String), has_entry(file_name: file_name)).returns(file).at_least(0)
  FileUploader.expects(:get_file_path).with(kind_of(Integer), kind_of(Integer), kind_of(String), has_entry(file_name: "")).returns(nil).at_least(0)
  steps %{
    Then I should see "#{question}"
    And I set the attachment field with ".ajax-file-uploader" to "#{file_name}"
    And I wait for upload to complete
    And I should see "File was successfully scanned for viruses"
    And the "#{file_name}" checkbox should be checked
    And I should see ".ajax-file-uploader" hidden
  }
end

Then /I click on the section with header "([^\"]*)"/ do |header|
  page.execute_script("jQuery(\"div.ibox:not('.collapsed'):contains(#{header})\").find('.collapse-link .fa-chevron-down').parent('a').trigger(\"click\")")
  page.execute_script("jQuery(\"div.ibox.collapsed:contains(#{header})\").find('.collapse-link .fa-chevron-up').parent('a').trigger(\"click\")")
end
# Used for sections on 'Customize User Form Fields' page
Then /I open section with header "([^\"]*)"/ do |header|
  page.execute_script("jQuery(\"div:contains(#{header})\").closest(\".cjs-section-click-handle-element\").trigger(\"click\")")
end

Then /I open filter with header "([^\"]*)"/ do |header|
  page.execute_script("jQuery(\".panel.filter_item div.panel-title:contains(#{header})\").trigger(\"click\")")
end

Then /I open Actions from profile/ do
  step "I click \"#mentor_profile .btn.dropdown-toggle\""
end

Then /save section with header "([^\"]*)"/ do |header|
  page.execute_script("jQuery(\"div.ibox:contains(#{header})\").find('.ibox-content input[type=submit]').trigger(\"click\")")
end

And /value of "([^\"]*)" should be "([^\"]*)"/ do |selector, value|
  assert_equal find(selector)["value"].should, value
end

When (/^I fill in other option with "([^\"]*)"$/) do |ans|
  q=ProfileQuestion.last
  select("Other...", :from => "profile_answers_#{q.id}")
  step "I fill in \"preview_#{q.id}\" with \"#{ans}\""
  page.execute_script(%Q[jQuery("#preview_#{q.id}").change();])
end

Then (/^I select ordered options "([^\"]*)" and "([^\"]*)"$/) do |opt0, opt1|
  q = ProfileQuestion.last
  select(opt0, :from => "profile_answers_#{q.id}_0")
  select(opt1, :from => "profile_answers_#{q.id}_1")
end

And /^I select "([^\"]*)" options from "([^\"]*)"$/ do |option, label|
 page.execute_script(%Q[jQuery("#{label}").focus();])
 page.execute_script(%Q[jQuery("#{label}").val("#{option}");])
end

And /^I should see "([^\"]*)" options selected for question "([^\"]*)"$/ do |value, question_text|
  pq = ProfileQuestion.where(question_text: question_text).last
  assert_equal value, find("#profile_question_options_count_#{pq.id} option[selected]").text
end

Then (/^I fill other field of index "([^\"]*)" with "([^\"]*)"$/) do |index, other|
  q = ProfileQuestion.last
  step "I fill in \"preview_#{q.id}_#{index}\" with \"#{other}\""
  page.execute_script(%Q[jQuery("#preview_#{q.id}_#{index}").change();])
end

And (/^I should see question with title "([^\"]*)" is hidden$/) do |ques_text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  ques = org.profile_questions_with_email_and_name.find_by(question_text: ques_text)
  assert page.evaluate_script(%Q[jQuery(".cjs_question_#{ques.id}").is(':hidden');])
end

And (/^I should see question with title "([^\"]*)" is not hidden$/) do |ques_text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  ques = org.profile_questions_with_email_and_name.find_by(question_text: ques_text)
  assert page.evaluate_script(%Q[jQuery(".cjs_question_#{ques.id}").is(':visible');])
end

And (/^I select the option "([^\"]*)" for the question "([^\"]*)"$/) do |opt, ques_text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  ques = org.profile_questions_with_email_and_name.find_by(question_text: ques_text)
  CucumberWait.retry_until_element_is_visible { select(opt, :from => "profile_answers_#{ques.id}") }
end

Then /^I upload a picture$/ do
  steps %{
    When I set the attachment field "profile_picture_image" to "pic_2.png"
    Then I press "Upload"
    Then I press "Save"
    Then I should see "The picture has been successfully updated"
  }
end

Then /^I upload a picture url$/ do
  steps %{
    Then I fill in "profile_picture_image_url" with "http://docs.seleniumhq.org/images/big-logo.png"
    Then I press "Upload"
    Then I press "Save"
    Then I should see "The picture has been successfully updated"
  }
end

Then /^I should see "([^\"]*)" score in the profile score box$/ do |email|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  prog = org.programs.find_by(root: "albers")
  member = org.members.where(:email => email).first
  user = member.user_in_program(prog)
  sum_score = user.profile_score.sum
  within ".profile_status_box" do
    step "I should see \"#{sum_score}\""
  end
end

Then (/^I quicksearch for "([^\"]*)" in "([^\"]*)" question$/) do |search_text, ques|
  q = ProfileQuestion.find_by(question_text: ques)
  step "I should scroll by \"2000\""
  step "I fill in \"quick_find_profile_answer_#{q.id}\" with \"#{search_text}\""
end

Then (/^I quick search for "([^\"]*)"$/) do |search_text|
  step %Q{I fill in "sf_quick_search" with "#{search_text}"}
  find('#quick_search button').click
end

Then (/^I should see "([^\"]*)" in "([^\"]*)" question$/) do |text, ques|
  q = ProfileQuestion.find_by(question_text: ques)
  assert page.evaluate_script(%Q[jQuery("#profile_answers_#{q.id} > label.cjs_quicksearch_item:contains('#{text}')").is(':visible');])
end

Then (/^I should not see "([^\"]*)" in "([^\"]*)" question$/) do |text, ques|
  q = ProfileQuestion.find_by(question_text: ques)
  assert page.evaluate_script(%Q[jQuery("#profile_answers_#{q.id} > label.cjs_quicksearch_item:contains('#{text}')").is(':hidden');])
end

Then (/^I fill in other option with "([^\"]*)" in "([^\"]*)" question$/) do |other_text,ques|
  q = ProfileQuestion.find_by(question_text: ques)
  step "I check \"profile_answers_#{q.id}_other\""
  assert page.evaluate_script(%Q[jQuery("#other_option_#{q.id}").is(':visible');])
  step "I fill in \"preview_#{q.id}\" with \"#{other_text}\""
end

Then (/^I should see other option not hidden in "([^\"]*)" question$/) do |ques|
  q = ProfileQuestion.find_by(question_text: ques)
  assert page.evaluate_script(%Q[jQuery("#profile_answers_#{q.id}_other_container").is(':visible');])
end

And /I "([^\"]*)" "([^\"]*)" question/ do |action, ques_text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  ques = org.profile_questions_with_email_and_name.find_by(question_text: ques_text)
  step "I hover over \"li#not_applicable_item_#{ques.id}\""
  within("li#not_applicable_item_#{ques.id}") do
    step "I click \"span.small\""
  end
end

And /I "([^\"]*)" and "([^\"]*)" "([^\"]*)" question/ do |action_1, action_2, ques_text|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  ques = org.profile_questions_with_email_and_name.find_by(question_text: ques_text)
  step "I hover over \"li#not_applicable_item_#{ques.id}\""
  within("li#not_applicable_item_#{ques.id}") do
    step "I click \"span.small\""
  end
  step "I hover over \"li#not_applicable_item_#{ques.id}\""
  within("li#not_applicable_item_#{ques.id}") do
    step "I click \"span.small\""
  end
end

And /^I save the section "([^\"]*)"$/ do |section|
  secid = Organization.where(name: "Primary Organization").first.sections.find_by(title: "#{section}").id
  step "I press \"Save\" within \"div#collapsible_section_content_#{secid}\""
end

And /^I remove all the existing mentoring slots for "([^\"]*)"$/ do |email|
  Member.find_by(email: email).mentoring_slots.destroy_all
end

When(/^I change meeting availability preference to configuring calendar slots$/) do
  steps %{
    And I follow "Settings"
    When I choose "member_will_set_availability_slots_true" within "#settings_section_onetime"
    And I scroll to bottom of page
    When I press "Save" within "#settings_section_onetime"
    Then I should see "Your changes have been saved"
  }
end

Then /^I check the content in mentoring slot list to be repeats "([^\"]*)" until "([^\"]*)"$/ do |weeks, date|
  within(".cjs_availability_slot_list") do
    day_of_week = 1.day.from_now.strftime("%A").first(2)
    if weeks.include?(day_of_week)
      step "I should see \"Repeats every week on #{weeks} until #{date}\""
    else
      step "I should see \"Repeats every week on #{weeks}, #{day_of_week} until #{date}\""
    end
  end
end


When(/^I change meeting availability preference of member with email "(.*?)" to configure availability slots$/) do |email|
  member = Member.find_by_email(email)
  member.update_attribute(:will_set_availability_slots, true)
end

Then /^I should see the toggle button "([^"]*)" selected$/ do |button|
  assert page.evaluate_script("jQuery('##{button}').is(':checked')")
end


Then /^I should see the toggle button "([^"]*)" not selected$/ do |button|
  assert_false page.evaluate_script("jQuery('##{button}').is(':checked')")
end

And /^I should see "([^\"]*)" in program summary of "([^\"]*)":"([^\"]*)"$/ do |content, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  step "I should see \"#{content}\" within \"div#program_tile_content_#{program.id}\""
end

And /^I should not see "([^\"]*)" in program summary of "([^\"]*)":"([^\"]*)"$/ do |content, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  step "I should not see \"#{content}\" within \"div#program_tile_content_#{program.id}\""
end