Given /^there are questions "([^\"]*)" for "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |questions_text, role_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  organization = program.organization
  role = program.get_role(role_name)
  questions_text.split(",").each do |question_text|
    question = organization.profile_questions.build(
      :question_text => question_text,
      :question_type => ProfileQuestion::Type::STRING,
      :section => organization.sections.default_section.first)
    question.save!
    role_q = question.role_questions.new
    role_q.role = role
    role_q.save!
  end
end

Given /^there is match config for student question "([^\"]*)" and mentor question "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |student_question_text, mentor_question_text, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  organization = program.organization

  student_profile_question = organization.profile_questions.find_by(question_text: student_question_text)
  mentor_profile_question = organization.profile_questions.find_by(question_text: mentor_question_text)
  student_role_question = program.role_questions.find_by(profile_question_id: student_profile_question.id)
  mentor_role_question = program.role_questions.find_by(profile_question_id: mentor_profile_question.id)
  MatchConfig.create!(:program => program, :mentor_question => mentor_role_question, :student_question => student_role_question)
end

Then /^I am trying to remove the field "([^\"]*)" under the section "([^\"]*)"$/ do |profile_question_text, section_title|
  sleep 0.5
  profile_question = ProfileQuestion.find_by(question_text: profile_question_text)
  step "I click on the section with header \"#{section_title}\""
  page.execute_script %Q[jQuery("div.cjs_profile_question_#{profile_question.id} .fa-trash").first().parent('a').click();]
end

Then /^Confirmation dialog should contain "([^\"]*)"$/ do |text|
  within ".sweet-alert", visible: true do
    step "I should see \"#{text}\""
  end
end

Then /^Confirmation dialog should not contain "([^\"]*)"$/ do |text|
  within ".sweet-alert", visible: true do
    step "I should not see \"#{text}\""
  end
end

Then /^the help text should be "([^\"]*)"$/ do |value|
  elem_id = page.evaluate_script(%Q[jQuery(".q_ck_editor").attr("id")])
  content = page.evaluate_script("CKEDITOR.instances['#{elem_id}'].getData()")
  assert_equal value, content
end

Then /^I set help text to "([^\"]*)"$/ do |content|
  elem_id = page.evaluate_script(%Q[jQuery(".q_ck_editor").attr("id")])
  page.evaluate_script("CKEDITOR.instances['#{elem_id}'].setData('#{content}')")
end

Then /^I am editing the field "([^\"]*)"$/ do |profile_question_text|
  profile_question = ProfileQuestion.find_by(question_text: profile_question_text)
  page.execute_script %Q[jQuery(".cjs_profile_question_#{profile_question.id}").click();]
  step "I wait for ajax to complete"
end

Then /^I uncheck student for editing field and save the form$/ do
  page.execute_script %Q[jQuery("input[id$='_student']").first().click();]
  page.execute_script %Q[jQuery("form[id^='edit_profile_question'] input[type='submit']").click();]
end

Then /^I should see the editable field "([^\"]*)"$/ do |text|
  within ".common_questions" do
    step "I should see \"#{text}\""
  end
end

Then /^I should not see the editable field "([^\"]*)"$/ do |text|
  within ".common_questions" do
    step "I should not see \"#{text}\""
  end
end

Then /^I should see the popup containing the fields "([^"]*)"$/ do |common_fields|
  common_fields.split(/,\s?/).each do |common_text|
    within "#update_profile_summary_fields_form" do
      step "I should see \"#{common_text}\""
    end
  end
end


And /^The popup should not contain the fields "([^"]*)"$/ do |common_fields|
  common_fields.split(/,\s?/).each do |common_text|
    within "#update_profile_summary_fields_form" do
      step "I should not see \"#{common_text}\""
    end
  end
end

When /^I select "([^"]*)" from the popup for "([^"]*)"$/ do |common_fields, role_name|
  within "#update_profile_summary_fields_form" do
    common_fields.split(/,\s?/).each do |common_text|
    check "common_fields_#{common_text}_#{role_name}"
    end
  end
end

And /^I unselect "([^"]*)" from the popup for "([^"]*)"$/ do |common_fields, role_name|
  within "#update_profile_summary_fields_form" do
    common_fields.split(/,\s?/).each do |common_text|
      uncheck "common_fields_#{common_text}_#{role_name}"
    end
  end
end

Then /^I should see "([^"]*)" in the profile summary$/ do |field|
  within "#results_pane" do
    step "I should see \"#{field}\""
  end  
end

And /^I should not see "([^"]*)" in the profile summary$/ do |field|
  within "#results_pane" do
    step "I should not see \"#{field}\""
  end
end

And /I click on the last section/ do
  last_id = Section.last.id
  within "div#profile_section_#{last_id}" do
    step "I click \".cjs-section-click-handle-element\""
  end  
end

And /I click on add new section/ do
  step "I click \".cjs-new-section-invoker\""
end

And /I click on add new question/ do
  step "I click \".cjs-new-field-invoker\""
end

And /I create sections and questions for "([^\"]*)"/ do |role|
  org = Organization.where(name: "Albers Mentor Program").first
  prog = org.programs.ordered.first
  q_role = prog.roles.with_name(role)[0]
  sec = org.sections.create!(:title => "New section", :position => 8, :organization => org)
  org.sections.create!(:title => "Blank section", :position => 8, :organization => org)
  q1 = org.profile_questions.new(:section => sec, :question_text => "New Mentor Field", :position => 1, :matchable => true, :question_type => 1)
  q1.save!
  role_q1 = q1.role_questions.new(:role => q_role)
  role_q1.save!
  q2 = org.profile_questions.new(:section => sec, :question_text => "New Mentor Student Field", :position => 2, :matchable => true, :question_type => 1)
  q2.save!
  role_q2 = q2.role_questions.new(:role => q_role)
  role_q2.save!
end

And /^I configured question for "([^"]*)" role in the program "([^"]*)"$/ do |roles, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.ordered.first
  section = org.sections.last
  profile_question = ProfileQuestion.last
  roles.split(",").each do |role_name|    
    within "div#mentoring_connections_select_options" do
      check("profile_questions_#{prog.id}_#{section.id}_#{profile_question.id}_#{role_name}")
    end
  end
end

And /^I configured question for "([^"]*)" role in the program "([^"]*)" and set default visibility$/ do |role, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.ordered.first

  steps %{
    And I follow "Programs"
    And I configured question for "#{role}" role in the program "#{subdomain}"
    Then I wait for ajax to complete
    And I set default visibility in program "#{subdomain}"
  }
end

And /^I set default visibility in program "([^"]*)"$/ do |subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.ordered.first
  terms =  prog.roles_without_admin_role.collect{|r| r.customized_term.pluralized_term_downcase} 

  steps %{
    And I click ".cjs_profile_question_edit_role_settings"
    Then I check "User"
    Then I check "User's mentoring connection"
    Then I check "All users"
  }
  terms.each do |term|
    step "I check \"All #{term}\""
  end
  steps %{
    When I uncheck "Editable by administrators only"
    And I press "Save" within "form"
  }
end

Then /^I click edit advanced options$/ do
  step "I click \"a.font-noraml.pointer.cjs_profile_question_edit_role_settings\""
end

Then /^I click Advanced Options$/ do
  step "I click \"a.m-b-xs.cjs_advanced\""
end

And /^I check "([^\"]*)" option to be disabled and unchecked$/ do |opt|
  field_labeled(opt, disabled: true).should_not be_checked
end

And /^I check "([^\"]*)" option to be enabled$/ do |opt|
  assert_nil field_labeled(opt)[:disabled]
end

Then /^I choose "([^\"]*)" for visibility$/ do |opt|
  select(opt)
end

And /^I check options for adminstrators only for visibility$/ do
  field_labeled("Editable by administrators only", disabled: true).should be_checked
  field_labeled("Mandatory", disabled: true).should_not be_checked
  field_labeled("Show in profile summary", disabled: true).should_not be_checked
  field_labeled("Available for advanced search", disabled: true).should_not be_checked
end

And /^I edit the "([^"]*)" section of "([^"]*)" title to "([^"]*)" And description to "([^"]*)"$/ do |section_selector, subdomain, name, description|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.ordered.first
  section = case section_selector
  when "last"
    org.sections.last
  when "default"
    org.sections.default_section.first
  end
  steps %{
    And I click "div.cjs-section-container[data-section-id='#{section.id}']"
    And I click ".cjs-section-edit-invoker"
    Then I should see "Edit Section"
    And I fill in "edit_section_title_#{section.id}_edit_section_form_#{section.id}" with "#{name}"
    And I fill in "section_description_edit_section_form_#{section.id}" with "#{description}"
    And I press "Save"
  }
end

And /^I edit the last question of "([^"]*)" title to "([^"]*)"$/ do |subdomain, name|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.ordered.first
  section = org.sections.last
  question = section.profile_questions.first
  steps %{
    And I click ".cjs_profile_question_#{question.id}"
    And I fill in "profile_question_text_#{question.id}" with "#{name}"
    And I press "Save"
    Then I wait for ajax to complete
    And I follow "Roles"
  }
  uncheck("profile_questions_#{prog.id}_#{section.id}_#{question.id}_student")
  step "I wait for ajax to complete"
end

And /^I click on "([^\"]*)" inside the "([^\"]*)" question in "([^\"]*)"$/ do |link_name, question_text, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  prog = org.programs.ordered.first
  question = org.profile_questions_with_email_and_name.find_by(question_text: question_text)
  step "I click \".cjs_profile_question_#{question.id}\"" if (link_name == "Edit")
  page.execute_script %Q[jQuery("div.cjs_profile_question_#{question.id} .fa-trash").first().parent('a').click();] if (link_name == "Delete")
end

And  /^I click on section with title "([^"]*)"$/ do |section_title|
  secid = Section.find_by(title: section_title).id
  step "I click \"div.cjs-section-container[data-section-id='#{secid}']\""
end

Then /^I reload the page$/ do
  visit page.driver.browser.current_url
end

Then /^I click the first delete icon$/ do
  CucumberWait.retry_until_element_is_visible { all(:xpath, "//a[i/@class='fa fa-trash profile_question_delete_image fa-lg fa-fw m-r-xs']").first.click}
end

Then /^I click the first section\-delete icon$/ do
  CucumberWait.retry_until_element_is_visible { all(:xpath, "//a[i/@class='m-r-0 fa fa-trash fa-lg section_delete_image fa-fw m-r-xs']").first.click}
end

Then /^I change the type of "([^\"]*)" question in "([^\"]*)" to "([^\"]*)"$/ do |question_text, orgname, type|
  org = Organization.where(name: orgname).first
  id = org.profile_questions.find_by(question_text: question_text).id
  step "I select \"#{type}\" from \"profile_question_question_type_#{id}\""
end

Then /^I add choices for "([^\"]*)" question in "([^\"]*)"$/ do |question_text, orgname|
  org = Organization.where(name: orgname).first
  id = org.profile_questions.find_by(question_text: question_text).id
  click_link_or_button "Bulk add"
  step "I fill in \"profile_question_#{id}_new_options\" with \"vatican,pope,rome\""
  page.find(:css, '.modal-dialog input[type=submit]').click
  step "I wait for ajax to complete"
end

Then /^I delete choices "([^\"]*)" for question "([^\"]*)" in "([^\"]*)"$/ do |choices, question_text, organization_name|
  organization = Organization.where(name: organization_name).first
  profile_question = organization.profile_questions.find_by(question_text: question_text)
  question_choices = profile_question.question_choices
  choices.split(" ").each do |choice|
    choice_id = question_choices.find{|q_choice| q_choice.text == choice}.id
    find(:css, "#profile_question_#{profile_question.id}_#{choice_id}_container .cjs_destroy_choice").click
  end
end

Then /^I scroll the div "([^\"]*)"$/ do |id_or_class|
  page.execute_script "jQuery('#{id_or_class}').scrollTop(jQuery('#{id_or_class}')[0].scrollHeight);"
end

And /^I set help text as "([^\"]*)" for name question in organization "([^\"]*)"$/ do |help_text, subdomain|
  organization = get_organization(subdomain)
  organization.name_question.update_attributes!(help_text: help_text)
end