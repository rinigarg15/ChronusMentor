When /^I reject the request from "([^\"]*)" for the reason "([^\"]*)"$/ do |email, reason|
  req = MembershipRequest.pending.find_by(email: email)
  within "div#mem_req_#{req.id}" do
    step "I follow \"Reject\""
  end
  steps %{
    Then I should see "Reason for rejection"
    And I fill in "membership_request_response_text" with "#{reason}" within "#new_membership_request"
    And I press "Submit"
  }
end

When /^I "([^\"]*)" request from "([^\"]*)"$/ do |action, email|
  req = MembershipRequest.pending.find_by(email: email)
  step "I click on \"#{action}\" for the group \"mem_req_#{req.id}\""
end

When /^I accept the request from "([^\"]*)" with message "([^\"]*)"$/ do |email, message|
  req = MembershipRequest.pending.find_by(email: email)
  within "div#mem_req_#{req.id}" do
    step "I follow \"Accept\""
  end
  step "I should see \"Accept Request\""
  unless message.blank?    
    step "I fill in \"membership_request_response_text\" with \"#{message}\""
  end
  step "I press \"Accept\""
end

When /^I accept the request from the deactivated user "([^\"]*)" with message "([^\"]*)"$/ do |email, message|
  req = MembershipRequest.pending.find_by(email: email)
  within "div#mem_req_#{req.id}" do
    step "I follow \"Accept\""
  end
  unless message.blank?
    step "I fill in \"membership_request_response_text\" with \"#{message}\""
  end
  steps %{
    Then I hover over "label_student_role"
    Then I should see "This role is already assigned to user. To remove it, go to users profile and change roles."
  }
end

When /^I accept the request from "([^\"]*)" with message "([^\"]*)" as a "([^\"]*)"$/ do |email, message, role|
  req = MembershipRequest.pending.find_by(email: email)
  within "div#mem_req_#{req.id}" do
    step "I follow \"Accept\""
  end
  unless message.blank?    
    step "I fill in \"membership_request_response_text\" with \"#{message}\""
  end
  steps %{
    And I uncheck "mentor_role"
    And I uncheck "student_role"
    Then I check "#{role}_role"
    And I press "Accept"
  }
end

When /^I set eligibilty rules for "([^\"]*)" in "([^\"]*)"$/ do |role,program_name|
  role_id = Program.find_by(name: "Albers Mentor Program").roles.find_by(name: role).id
  steps %{
    Then I follow "eligibility_rules_link_#{role_id}"
    Then I should see "#admin_view_profile_questions_questions_1_value" hidden
    Then I should see "#admin_view_profile_questions_questions_1_choice" hidden
    Then I select "Language" from "admin_view_profile_questions_questions_1_question"
    Then I select "Contains Any Of" from "admin_view_profile_questions_questions_1_operator"
    Then I click ".cjs_hidden_input_box_container input.select2-input"
    Then I click on select2 result "English"
    Then I follow "Add one more"
    Then I select "Phone" from "admin_view_profile_questions_questions_2_question"
    Then I select "Filled" from "admin_view_profile_questions_questions_2_operator"
    Then I fill in "admin_view_#{role}_eligibility_message" with "Not eligible to join"
    Then I press "Save" within ".cjs_adminview_form"
    Then I should see "Eligibility rules successfully created"
    Then I press "Save"
  }
end

When /^I ignore the request from "([^\"]*)"$/ do |email|
  req = MembershipRequest.pending.find_by(email: email)
  within "div#mem_req_#{req.id}" do
    step "I follow \"Ignore\""
  end
  step "I press \"Confirm\""
end

Given /all membership questions are not mandatory/ do
  RoleQuestion.membership_questions.each do |q|
    q.update_attribute(:required, false)
  end
end

Given /^a pending membership request with email "([^\"]*)" and role as "([^\"]*)"$/ do |email, roles|
  program = Program.find_by(root: "albers")
  member = Member.find_by(email: email)
  create_membership_request(program: program, member: member, roles: roles.split(", ").collect(&:downcase))
end

Given /^a pending membership request created at "([^\"]*)" with email "([^\"]*)" and role as "([^\"]*)"$/ do |year, email, roles|
  step "a pending membership request with email \"#{email}\" and role as \"#{roles}\""
  membership_request = MembershipRequest.last
  membership_request.update_attribute(:created_at, DateTime.new(year.to_i)) 
end

Then /^I click on the individual dropdown for the membership request with email "([^\"]*)"$/ do |email|
  program = Program.find_by(root: "albers")
  membership_request = program.membership_requests.find_by(email: email)
  page.execute_script("jQuery('#mem_req_#{membership_request.id} .dropdown-toggle').click();")
end

Then /^I fill in the subject and content with "([^\"]*)" and "([^\"]*)" respectively$/ do |subject, content|
  steps %{
    And I fill in "admin_message_subject" with \"#{subject}\"
    And I fill in CKEditor "admin_message_content" with \"#{content}\"
  }
end

And /^I select all requests in the page$/ do
  steps %{
    And I click "#cjs_primary_checkbox"
  }
end

And /^I select all requests in the view$/ do
  steps %{
    And I click "#cjs_primary_checkbox"
    And I click "#cjs_select_all_handler"
  }
end

And /^I fill in sent between field with "([^\"]*)"$/ do |value|
  page.execute_script("jQuery('#report_time_filter_form .cjs_daterange_picker_value').val('#{value}')")
end

And /^I fill through console in "([^\"]*)" with "([^\"]*)"$/ do |selector, value|
  page.execute_script("jQuery('#{selector}').val('#{value}')")
end

When /^membership request instruction form of "([^\"]*)":"([^\"]*)" is "([^\"]*)"$/ do |subdomain, prog_root, instruction|
  prog = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain).programs.find_by(root: prog_root)
  MembershipRequest::Instruction.create(:program_id => prog.id, :content => instruction)
end

And /fill in all membership questions for "([^\"]*)"/ do |role|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,'primary')
  p = org.programs.find_by(root: 'albers')
  p.role_questions_for(role).membership_questions.collect(&:profile_question).uniq.each do |mem_ques|
    step "I fill in \"profile_answers_#{mem_ques.id}\" with \"Test_#{mem_ques.question_text}\"" if mem_ques.question_type==1
    #select "1965", :from => "common_answers_#{mem_ques.id}" if mem_ques.question_text=="Graduation year"
  end
end

Before("@membership_requests") do
  set_current_program_for_integration(Program.find_by(root: "albers"))
end

And /^I should see "([^\"]*)" selected for items per page/ do |value|
  assert page.has_css?("#items_per_page_selector option[selected][value=\'#{value}\']")
end

And /^I fill in filter question for "([^\"]*)" with "([^\"]*)" in "([^\"]*)":"([^\"]*)"/ do |question_text, value, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  pq = program.organization.profile_questions.where(question_text: question_text).first
  steps %{
    And I fill in "sf_pq_#{pq.id}" with "#{value}"
    And I press "Go"
  }
end

And /^I sort requests by "([^\"]*)"/ do |value|
  find('.cjs_sortable_element', :text => value).click
end

And /^I should see "([^\"]*)" in table "([^\"]*)" row/ do |value, row|
  within("#cjs_mem_req_record") do
    expected_text=all("tr")[row.to_i].text
    assert all("tr")[row.to_i].has_content?(value),"expected value doesn't match #{expected_text}"
  end
end

Then /^I should see "([^\"]*)" in Applied Filters/ do |value|
  within ("div#your_filters") do
    step "I should see \"#{value}\""
  end
end

Then /^I should see the sender filled as "([^\"]*)"$/ do |sender_name_with_email|
  steps %{
    Then I should see "#search_filters_receiver" filled as \"#{sender_name_with_email}\"
  }
end

Then /^I should see the daterange filled$/ do
  assert page.evaluate_script("jQuery('.cjs_daterange_picker_start').val()").present?
  assert page.evaluate_script("jQuery('.cjs_daterange_picker_end').val()").present?
end

Then /^I should see "([^\"]*)" filled as "([^\"]*)"$/ do |selector, value|
  assert_equal value, page.evaluate_script("jQuery('#{selector}').val()")
end

Then /^I configure manager type question for membership form/ do
  secid = Organization.where(name: "Primary Organization").first.sections.find_by(title: "Work and Education").id
  progid = Program.find_by(name: "Albers Mentor Program").id
  mentorroleid = Program.find_by(name: "Albers Mentor Program").roles.find_by(name: "mentor").id
  manager_ques_id = Organization.where(name: "Primary Organization").first.profile_questions.select{|ques| ques.manager?}.first.id
  steps %{
    And I click "div.cjs-section-container[data-section-id='#{secid}']"
    When I scroll the div ".cjs-profile-question-slim-scroll"
    And I click ".cjs_profile_question_#{manager_ques_id}"
    Then I wait for ajax to complete
    And I follow "Roles"
    And I click edit advanced options
    Then I wait for ajax to complete
  }
  check("role_questions_available_for_membership_#{manager_ques_id}_#{mentorroleid}")
  step "I scroll the div \".cjs-side-panel-slim-scroll\""
  step "I press \"Save\""
end

Given /^the membership mode for "([^\"]*)" is "([^\"]*)"$/ do |role_name, membership_mode|
  program = Program.find_by(root: "albers")
  role = program.find_role role_name.downcase
  if membership_mode == "Apply to join"
    role.update_attributes(membership_request: true, join_directly: false, join_directly_only_with_sso: false)
  else
    role.update_attributes(membership_request: false, join_directly: true, join_directly_only_with_sso: false)
  end
end

When /^I want to join as "([^\"]*)" with "([^\"]*)"$/ do |role, email|
  MembershipRequestsController.any_instance.stubs(:simple_captcha_valid?).returns(true)
  step "I follow \"Join\""
  CucumberWait.retry_until_element_is_visible { page.choose("roles_#{role.downcase}")}
  steps %{
    And I fill in "email" with "#{email}"
    And I fill in "captcha" with "IJKKCL"
    And I press "Continue"
    And I should see "Thank you for your interest in joining!"
    And I should see "Check your email (#{email.strip}) for instructions to join."
    And I should see "Didn't get the email? Please check your spam/clutter folder and move the email to your inbox to prevent any further emails being sent to your spam/clutter folder or click here to resend it."
    And I should not see "Join" within "nav#chronus_header"
  }
end

Then /^I click on the signup link sent in email to "([^\"]*)"$/ do |email|
  steps %{
    And a mail should go to "#{email}" having "To finish signing-up, click on the button below."
    When I open new mail
  }
  signup_link = links_in_email(current_email).select { |link| link.match(/membership_request/) }.first
  step "I follow \"#{signup_link}\" in the email"
end

Then /^I click on the login link sent in email meant for existing users to "([^\"]*)"$/ do |email|
  step "a mail should go to \"#{email}\" having \"Please login with your existing password to continue on your way.\""
  step "I open new mail"
  signup_link = links_in_email(current_email).select { |link| link.match(/login/) }.first
  step "I follow \"#{signup_link}\" in the email"
end

And /^I fill the password and submit the membership application form$/ do
  steps %{
    And I fill in "membership_request_password" with "monkey"
    And I fill in "membership_request_password_confirm" with "monkey"
    And I press "Submit"
  }
end

And /^I fill the basic information and submit the membership application form$/ do
  steps %{
    And I fill in "membership_request_first_name" with "Abc"
    And I fill in "membership_request_last_name" with "def"
    And element with id "#membership_request_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Submit"
    And I fill the password and submit the membership application form
  }
end

And /^I fill the basic information with wrong name and submit the membership application form$/ do
  steps %{
    And I fill in "membership_request_first_name" with "1Abc"
    And I fill in "membership_request_last_name" with "def"
    And element with id "#membership_request_email" should be disabled
    Then I valdiate and give my consent for terms and conditions by clicking "Submit"
    And I fill the password and submit the membership application form
  }
end

And /^I should not see the name and email fields$/ do
  steps %{
    And I should see "#membership_request_first_name" hidden
    And I should see "#membership_request_last_name" hidden
    And I should see "#membership_request_email" hidden
  }
end


And /^I make special type and file type questions available in the membership form for "([^\"]*)" in "([^\"]*)" program$/ do |role, program|
  steps %{
    And I make "Upload your Resume" question available in the membership form for "#{role}" in "primary":"#{program}"
    And I make "Upload your Resume" question available in the membership form for "#{role}" in "primary":"#{program}"

    And I make "Education" question available in the membership form for "#{role}" in "primary":"#{program}"
    And I make "Education" question available in the membership form for "#{role}" in "primary":"#{program}"

    And I make "Work" question available in the membership form for "#{role}" in "primary":"#{program}"
    And I make "Work" question available in the membership form for "#{role}" in "primary":"#{program}"

    And I make "Current Publication" question available in the membership form for "#{role}" in "primary":"#{program}"
    And I make "Current Publication" question available in the membership form for "#{role}" in "primary":"#{program}"

    And I make "Current Manager" question available in the membership form for "#{role}" in "primary":"#{program}"
    And I make "Current Manager" question available in the membership form for "#{role}" in "primary":"#{program}"
  }
end

When /^I overwrite "([^"]*)" education question of member "([^"]*)" with "([^"]*)"$/ do |existing_or_new, email, education|
  member = Member.find_by(email: email)
  education_ques_id = member.organization.profile_questions.select{|ques| ques.education?}.first.id
  education_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: education_ques_id).first.educations.first.id
  education_array = education.split(',')
  steps %{
    And I fill in "profile_answers[#{education_ques_id}][#{existing_or_new}_education_attributes][#{education_id}][school_name]" with "#{education_array[0]}"
    And I fill in "profile_answers[#{education_ques_id}][#{existing_or_new}_education_attributes][#{education_id}][degree]" with "#{education_array[1]}"
    And I fill in "profile_answers[#{education_ques_id}][#{existing_or_new}_education_attributes][#{education_id}][major]" with "#{education_array[2]}"
  }
end

When /^I overwrite "([^"]*)" experience question of member "([^"]*)" with "([^"]*)"$/ do |existing_or_new, email, experience|
  member = Member.find_by(email: email)
  experience_ques_id = member.organization.profile_questions.select{|ques| ques.experience?}.first.id
  experience_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: experience_ques_id).first.experiences.first.id
  experience_array = experience.split(',')
  steps %{
    And I fill in "profile_answers[#{experience_ques_id}][#{existing_or_new}_experience_attributes][#{experience_id}][company]" with "#{experience_array[0]}"
    And I fill in "profile_answers[#{experience_ques_id}][#{existing_or_new}_experience_attributes][#{experience_id}][job_title]" with "#{experience_array[1]}"
  }
end

When /^I overwrite "([^"]*)" publication question of member "([^"]*)" with "([^"]*)"$/ do |existing_or_new, email, publication|
  member = Member.find_by(email: email)
  publication_ques_id = member.organization.profile_questions.select{|ques| ques.publication?}.first.id
  publication_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: publication_ques_id).first.publications.first.id
  publication_array = publication.split(',')
  steps %{
    And I fill in "profile_answers[#{publication_ques_id}][#{existing_or_new}_publication_attributes][#{publication_id}][title]" with "#{publication_array[0]}"
    And I fill in "profile_answers[#{publication_ques_id}][#{existing_or_new}_publication_attributes][#{publication_id}][publisher]" with "#{publication_array[1]}"
    And I fill in "profile_answers[#{publication_ques_id}][#{existing_or_new}_publication_attributes][#{publication_id}][authors]" with "#{publication_array[2]}"
  }
end

When /^I overwrite "([^"]*)" manager question of member "([^"]*)" with "([^"]*)"$/ do |existing_or_new, email, manager|
  member = Member.find_by(email: email)
  manager_ques_id = member.organization.profile_questions.select{|ques| ques.manager?}.first.id
  manager_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: manager_ques_id).first.manager.id
  manager_array = manager.split(',')
  steps %{
    And I fill in "profile_answers[#{manager_ques_id}][#{existing_or_new}_manager_attributes][#{manager_id}][first_name]" with "#{manager_array[0]}"
    And I fill in "profile_answers[#{manager_ques_id}][#{existing_or_new}_manager_attributes][#{manager_id}][last_name]" with "#{manager_array[1]}"
    And I fill in "profile_answers[#{manager_ques_id}][#{existing_or_new}_manager_attributes][#{manager_id}][email]" with "#{manager_array[2]}"
  }
end

Then /^"([^"]*)" education answer of member "([^"]*)" should contain "([^"]*)"$/ do |existing_or_new, email, education|
  member = Member.find_by(email: email)
  education_ques_id = member.organization.profile_questions.select{|ques| ques.education?}.first.id
  education_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: education_ques_id).first.educations.first.id
  education_array = education.split(',')
  steps %{
    Then the "profile_answers[#{education_ques_id}][#{existing_or_new}_education_attributes][#{education_id}][school_name]" field should contain "#{education_array[0]}"
    Then the "profile_answers[#{education_ques_id}][#{existing_or_new}_education_attributes][#{education_id}][degree]" field should contain "#{education_array[1]}"
    Then the "profile_answers[#{education_ques_id}][#{existing_or_new}_education_attributes][#{education_id}][major]" field should contain "#{education_array[2]}"
  }
end

Then /^"([^"]*)" experience answer of member "([^"]*)" should contain "([^"]*)"$/ do |existing_or_new, email, experience|
  member = Member.find_by(email: email)
  experience_ques_id = member.organization.profile_questions.select{|ques| ques.experience?}.first.id
  experience_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: experience_ques_id).first.experiences.first.id
  experience_array = experience.split(',')
  steps %{
    Then the "profile_answers[#{experience_ques_id}][#{existing_or_new}_experience_attributes][#{experience_id}][company]" field should contain "#{experience_array[0]}"
    Then the "profile_answers[#{experience_ques_id}][#{existing_or_new}_experience_attributes][#{experience_id}][job_title]" field should contain "#{experience_array[1]}"
  }
end

Then /^"([^"]*)" publication answer of member "([^"]*)" should contain "([^"]*)"$/ do |existing_or_new, email, publication|
  member = Member.find_by(email: email)
  publication_ques_id = member.organization.profile_questions.select{|ques| ques.publication?}.first.id
  publication_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: publication_ques_id).first.publications.first.id
  publication_array = publication.split(',')
  steps %{
    Then the "profile_answers[#{publication_ques_id}][#{existing_or_new}_publication_attributes][#{publication_id}][title]" field should contain "#{publication_array[0]}"
    Then the "profile_answers[#{publication_ques_id}][#{existing_or_new}_publication_attributes][#{publication_id}][publisher]" field should contain "#{publication_array[1]}"
    Then the "profile_answers[#{publication_ques_id}][#{existing_or_new}_publication_attributes][#{publication_id}][authors]" field should contain "#{publication_array[2]}"
  }
end

Then /^"([^"]*)" manager answer of member "([^"]*)" should contain "([^"]*)"$/ do |existing_or_new, email, manager|
  member = Member.find_by(email: email)
  manager_ques_id = member.organization.profile_questions.select{|ques| ques.manager?}.first.id
  manager_id = existing_or_new == "new" ? "" : member.profile_answers.where(profile_question_id: manager_ques_id).first.manager.id
  manager_array = manager.split(',')
  steps %{
    Then the "profile_answers[#{manager_ques_id}][#{existing_or_new}_manager_attributes][#{manager_id}][first_name]" field should contain "#{manager_array[0]}"
    Then the "profile_answers[#{manager_ques_id}][#{existing_or_new}_manager_attributes][#{manager_id}][last_name]" field should contain "#{manager_array[1]}"
    Then the "profile_answers[#{manager_ques_id}][#{existing_or_new}_manager_attributes][#{manager_id}][email]" field should contain "#{manager_array[2]}"
  }
end

Then /^the "([^"]*)" field should contain "([^"]*)" for member with email "([^"]*)"$/ do |question, answer, email|
  member = Member.find_by(email: email)
  profile_question_id = member.organization.profile_questions.find_by(question_text: question).id
  step "the \"profile_answers[#{profile_question_id}]\" field should contain \"#{answer}\""
end


And /^I click on all members title$/ do
  page.execute_script(%Q[jQuery.find("#clicked-title-admin-view")[0].click()])
end

And /^I close the all members view dropdown$/ do
  page.execute_script(%Q[jQuery("#select2-drop").hide()])
  page.execute_script(%Q[jQuery("#select2-drop-mask").hide()])
end


Then /^I should see state "([^\"]*)" for request from "([^\"]*)"$/ do |state, email|
  req = MembershipRequest.pending.find_by(email: email)
  step "I should see \"#{status}\" within \"#mem_req_#{req.id}\""
end

And /^I shift to list view$/ do
  steps %{
    And I click "#list_view"
  }
end

And /^I shift to detailed view$/ do
  steps %{
    And I click "#detailed_view"
  }
end

And /^I "(enable|disable)" membership request customization for "([^\"]*)"$/ do |enable_or_disable, subdomain|
  program_or_organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, subdomain)
  program_or_organization = program_or_organization.programs.find_by(root: PROGRAM_ROOT) unless PROGRAM_ROOT.blank?
  enable_or_disable == "enable" ? enable_membership_request!(program_or_organization) : disable_membership_request!(program_or_organization)
end

Then /^I valdiate and give my consent for terms and conditions by clicking "([^\"]*)"$/ do |button|
  see_text = (button == "Submit" ? "Submit" : "Sign up")
  page.has_content?("By clicking \"#{see_text}\" you are indicating that you have read and agreed to the Acceptable Use Policy. You are also indicating that you have read the Privacy Policy which also contains information on our use of cookies.")
  steps %{
    Then the "signup_terms" checkbox_id should not be checked
    Then I press "#{button}"
    Then I should see "Please fill the highlighted fields with appropriate values to proceed"
    Then I check "signup_terms"
    Then the "signup_terms" checkbox_id should be checked
  }
end