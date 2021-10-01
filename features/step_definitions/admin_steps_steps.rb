And /^the admin is a "([^\"]*)"/ do |m|
  program_albers = Program.find_by(name: "Albers Mentor Program")
  user_1 = program_albers.organization.members.find_by(email: "ram@example.com").users.first
  user_2 = program_albers.organization.members.find_by(email: "rahim@example.com").users.first
  user_3 = program_albers.organization.members.find_by(email: "robert@example.com").users.first
  
  if m=="mentor"
    user_1.add_role(RoleConstants::MENTOR_NAME)
    create_group(:student => user_2 , :mentor => user_1, :program => program_albers)
end
  if m=="student"
    user_1.add_role(RoleConstants::STUDENT_NAME)
    create_group(:student => user_1 , :mentor => user_3, :program => program_albers)
  end
end

Then /^I should see support link$/ do
  within "ul#header_actions" do
    step "I should see \"Support\""
  end
end

Then /^I should not see support link$/ do
  within "ul#header_actions" do
    step "I should not see \"Support\""
  end
end

Then /^I create a sample privacy policy "([^"]*)" for my organization$/ do |statement|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  org.update_attribute :privacy_policy, statement
end

Then /^I should see "([^"]*)" in the newly opened page in "([^"]*)"$/ do |statement, selector|
  within(selector) do
    statement.split(", ") do |statement_text|
      step "I should see \"#{statement_text}\""
    end
  end
end

Then /^I should view threaded reply$/ do
  page.evaluate_script("jQuery('div.cui_thread').is(':visible')")
end

Then /^I should not view threaded reply$/ do
  page.evaluate_script("jQuery('div.cui_thread').is(':hidden')")
end

And /^I fill up to details$/ do
  page.execute_script("jQuery('#receiver').val('Administrator')")
  page.execute_script("jQuery('input#admin_message_receiver_ids').val('2,3')")
  page.execute_script("jQuery('input#admin_message_receivers').val('student example, Good unique name')")
end

And /^I fill up to details for many recipients$/ do
  page.execute_script("jQuery('#receiver').val('Administrator')")
  page.execute_script("jQuery('input#admin_message_receiver_ids').val('2,3,4,5,6,7,8,9,10,11,12')")
  page.execute_script("jQuery('input#admin_message_receivers').val('student example, Good unique name, user name, Mentor Studenter, Kal Raman (Administrator), rahim user, robert user, mkr_student madankumarrajan, student_a example, student_b example, student_c example')")
end


Then /^I click on preview text "([^"]*)"$/ do |text|
  page.execute_script("jQuery('.cjs_preview_active').each(function(i,v){element = jQuery(v); if(element.find('.cui_content_preview').text().strip(" ") == '#{text}') {element.click();} });")
end

Then /^I update the mentoring slot of "([^"]*)"$/ do |email|
  member = Member.find_by(email: email)
  start_time = Date.today.beginning_of_day + 2.days
  member.mentoring_slots.first.update_attributes(:start_time => start_time, :end_time => start_time + 30.minutes)
end

Then /^I apply the mentoring sessions filter$/ do
  page.execute_script("jQuery('input#mentoring_session_attendee').val('Good unique name <robert@example.com>')")
  steps %{
    And I press "Go"
    Then I wait for ajax to complete
    And I should see "mkr_student madankumarrajan"
    Then I should see "Good unique name"
  }
  page.execute_script("jQuery('input#mentoring_session_attendee').val('mentor1 example <mentor_a@example.com>')")
  steps %{
    Then I follow "filter_report"
    And I press "Go" 
    Then I wait for ajax to complete
    Then I should not see "Good unique name"
    And I should see "View all Meetings"
  }
end

Then /^I apply the calendar sessions profile filter$/ do
  question_id = page.evaluate_script(%Q[jQuery(".cjs_question_selector").last().attr("id")])
  operator = page.evaluate_script(%Q[jQuery(".cjs_operator_field").last().attr("id")])

  steps %{
  And I select "Location" from \"#{question_id}\"
  Then I should not see "Add" within "div.cjs_user_profile_row"
  And I select "Contains" from \"#{operator}\"
  Then I should see "#profile_question_choice" hidden
  Then I should see "Add" within "div.cjs_user_profile_row"
  And I follow "Add" within "div.cjs_user_profile_row"
  }

  last_question_id = page.evaluate_script(%Q[jQuery(".cjs_question_selector").last().attr("id")])
  last_operator = page.evaluate_script(%Q[jQuery(".cjs_operator_field").last().attr("id")])
  steps %{
  And I select "Gender" from \"#{last_question_id}\"
  And I select "Not Filled" from \"#{last_operator}\"
  Then I should see "#profile_question_value" hidden
  Then I should see "#profile_question_choice" hidden
  And I follow "Reset"
  }
end

Then /^I assign the mentee to a mentor$/ do
  within "div#mentor_request_#{MentorRequest.last.id}" do
    step "I follow \"Assign\""
  end
  step "I wait for animation to complete"
  within "div#modal_preferred_mentors_for_#{MentorRequest.last.id}" do
    steps %{
      And I should see "Type the name of the mentor to be assigned to Moderated Student"
      And I fill in "group_mentor_#{MentorRequest.last.id}" with "moderated_mentor <moderated_mentor@example.com>"
      And I press "Assign"
    }
  end
  step "I should see \"Moderated Student has been assigned to the mentoring connection\""
end

Then /^I assign mentor to both mentees$/ do
  within "div#mentor_request_#{MentorRequest.last.id}" do
    step "I follow \"Assign\""
  end
  steps %{
    Then I wait for animation to complete
    Then I should see ".cjs_assign_mentoring_model" not hidden
    And I should see "Assign a preferred mentor"
    And I should see "Type the name of the mentor to be assigned"
    And I fill in "group_mentor_#{MentorRequest.last.id}" with "mental mentor <mentor@psg.com>" within "#modal_preferred_mentors_for_#{MentorRequest.last.id}"
    And I press "Assign" within "#modal_preferred_mentors_for_#{MentorRequest.last.id}"
    And I should see "has been assigned to the mentoring connection"
    Then I reload the page
  }
  within "div#mentor_request_#{MentorRequest.last(2)[0].id}" do
    step "I follow \"Assign\""
  end

  steps %{
    Then I wait for animation to complete
    And I should see "Type the name of the mentor to be assigned"
    And I fill in "group_mentor_#{MentorRequest.last(2)[0].id}" with "mental mentor <mentor@psg.com>" within "#modal_preferred_mentors_for_#{MentorRequest.last(2)[0].id}"
    And I press "Assign" within "#modal_preferred_mentors_for_#{MentorRequest.last(2)[0].id}"
    And I press "Create"
  }
end

Then /^I enable public mentoring connection option$/ do
  steps %{
    And I follow "Manage"
    Then I follow "Program Settings"
    And I follow "Connection Settings"
    And I follow "Advanced Options"
    And I choose "program_allow_users_to_mark_connection_public_true"
    Then I press "Save"
  }
end

When /^I delete all the columns$/ do
  program = Program.find_by(name: "Albers Mentor Program")
  program.report_view_columns.for_groups_report.destroy_all
  program.reload
end

Then /^I add locations for members$/ do
  program_albers = Program.find_by(name: "Albers Mentor Program")

  user_1 = program_albers.student_users.first
  loc_ques = program_albers.organization.profile_questions.where(:question_text => 'Location').first
  new_location = Location.where(:country => 'Ukraine').first

  user_1.member.profile_answers.create(:location_id => new_location.id, :profile_question_id => loc_ques.id)
end

Given /^I have a program invitation expired on year "([^\"]*)"$/ do |year|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,'primary')
  program = organization.programs.find_by(root: 'albers')
  program.program_invitations[0].update_attribute(:expires_on, DateTime.new(year.to_i))
end

Then /^I filter on "([^\"]*)" with name "([^\"]*)"$/ do |role_name,filter_user|
  steps %{
    And I click on "#{role_name}" header
    And I fill in "#{filter_user}" with "#{role_name}" role from "primary":"albers" in the filter box
    And I press "Go" inside "#{role_name}" content
  }
end

Then /^I filter on "([^\"]*)" in report with name "([^\"]*)"$/ do |role_name,filter_user|
  steps %{
    And I click on "#{role_name}" header
    And I fill in "#{filter_user}" with "#{role_name}" role from "primary":"albers" in the filter box
    And I press "Go" within "div#other_report_filters_footer"
  }
end

Then /^I select past "([^\"]*)" months date range in "([^\"]*)"$/ do |num_months, id|
  daterange = "#{num_months.to_i.months.ago.strftime("%m/%d/%Y")} - #{Time.now.strftime("%m/%d/%Y")}"
  page.execute_script("jQuery('#{id}').val('#{daterange}')");
end

Then /^I select "([^\"]*)" date in "([^\"]*)"$/ do |date, id|
  page.execute_script("jQuery('#{id}').val('#{date}')");
end

Then /^I reset "([^\"]*)" filter$/ do |filter|
  page.execute_script %Q[jQuery("img[data-click_fn_args=\'#{filter}\']").click();]
end

Then /^I choose "([^\"]*)" from date selector in "([^\"]*)"$/ do |option, selector|
  find("#{selector} .cjs_daterange_picker_presets").find('option', :text => option).select_option
end

Then /^I set current timezone to yesterday$/ do
  Date.stubs(:current).returns(1.day.ago.to_date)
end

Then /^I choose "([^\"]*)" from date selector$/ do |option|
  step "I wait for \"1\" seconds"
  page.find('option', :text => "#{option}").click
end

Then /^the date range should be a "([^\"]*)" for "([^\"]*)"$/ do |range, selector|
  within(:xpath, xpath_for_collapsible_content(selector)) do
    start_date = Date.parse(page.find(".cjs_daterange_picker_start").value)
    end_date = Date.parse(page.find(".cjs_daterange_picker_end").value)
    days_diff = (end_date - start_date).to_i
    if range.eql?("week")
      assert_equal 7, days_diff
    elsif range.eql?("month")
      assert_equal 30, days_diff
    end
  end
end

Then /^I disable ongoing engagement mode for "([^\"]*)":"([^\"]*)"$/ do |subdomain, root|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, subdomain)
  program = organization.programs.find_by(root: root)
  program.update_attributes(engagement_type: Program::EngagementType::CAREER_BASED)
end

Then /^I set total responses for surveys$/ do
  steps %{
    Then I stub "total_responses" for "ProgramSurvey" as "integer" value "2"
    Then I stub "total_responses" for "EngagementSurvey" as "integer" value "2"
    Then I stub "total_responses" for "MeetingFeedbackSurvey" as "integer" value "2"
  }
end

Then /^I open admin notes section$/ do
  page.execute_script("jQuery('#add_note').click();")
end  

Then /^I open advanced options setting section$/ do
  page.execute_script("jQuery('#cjs_matching_ongoing_advanced_options').click();")
end  