require File.dirname(__FILE__) + '/../../app/helpers/meetings_helper'
include MeetingsHelper

# encoding: utf-8
Given /^valid and appropriate date time settings$/ do
  travel_time = Time.now.utc.beginning_of_day + 8.hours
  current_day = Date::DAYNAMES[Date.today.wday]
  if ["Saturday"].include?(current_day)
    travel_time -= 2.days
  end
  Timecop.travel(travel_time)  
end

When /^I stub chronus s3 utils$/ do
  ChronusS3Utils::S3Helper.stubs(:transfer).returns('https://s3.amazonaws.com/chronus-mentor-assets/global-assets/files/20140321091645_sample_event.ics')
end

When /^I enable calendar feature$/ do
  steps %{
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I enable "calendar" feature as a super user
    And I logout
  }
end

When /^I disable calendar feature$/ do
  steps %{
    When I have logged in as "ram@example.com"
    When I hover over "my_programs_container"
    When I select "Primary Organization" from the program selector
    And I disable the feature "calendar" as a super user
    And I logout
  }
end

And /^I destroy all meetings for member with email "([^\"]*)"$/ do |email|
  m = Member.find_by(email: email)
  m.meetings.destroy_all
end

And /I create a mentoring slot from "([^\"]*)" to "([^\"]*)" for "([^\"]*)"/ do |st, en, email|
  st= (Time.now.utc + 1.day).strftime("%Y-%m-%d") + " "+ st
  en= (Time.now.utc + 1.day).strftime("%Y-%m-%d") + " "+ en
  m = Member.find_by(email: email)
  if m.mentoring_slots.blank?
    m.mentoring_slots.new(:start_time => st, :end_time => en, :location => "HSB", :repeats => 0).save!
  else
    m.mentoring_slots.first.update_attributes(:start_time => st, :end_time => en, :location => "HSB", :repeats => 0)
  end
  m.meetings.destroy_all
end

And /^I create a mentoring slot from "([^\"]*)" to "([^\"]*)" after "([^\"]*)" days for "([^\"]*)"$/ do |st, en, days, email|
  st= (Time.now.utc + days.to_i.day).strftime("%Y-%m-%d") + " "+ st
  en= (Time.now.utc + days.to_i.day).strftime("%Y-%m-%d") + " "+ en
  m = Member.find_by(email: email)
  if m.mentoring_slots.blank?
    m.mentoring_slots.new(:start_time => st, :end_time => en, :location => "HSB", :repeats => 0).save!
  else
    m.mentoring_slots.first.update_attributes(:start_time => st, :end_time => en, :location => "HSB", :repeats => 0)
  end
  m.meetings.destroy_all
end

#Capybara steps
Then /I click on the event created/ do
  step "I click \".fc-event\""
end

Then /^I click on the event with text "([^\"]*)"$/ do |text|
  page.execute_script(%Q[jQuery(".fc-event:contains('#{text}')").trigger('click')])
end

Then /^I close the qtip popup$/ do
  page.evaluate_script("closeQtip();")
end

Then /I click to edit event/ do
  step "I follow \"Edit\""
end

Then /I click to delete event/ do
  steps %{
    And I follow "Delete"
    And I confirm popup
  }
end

Given /^there is a past meeting I attended outside of a group$/ do
  m1 = Member.find_by(email: "robert@example.com")
  m2 = Member.find_by(email: "rahim@example.com")
  albers_prog = Program.find_by(root: "albers")

  m = Meeting.create!(:topic => "Outside Group",
  :start_time => 4.hours.ago, :end_time => 2.hours.ago,
  :description => "Sample Desc", :group_id => nil,
  :members => [m1, m2],
  :owner_id => m2.id , :program_id => albers_prog.id,
  :requesting_student => m2.user_in_program(albers_prog),
  :mentee_id => m2.id,
  :requesting_mentor => m1.user_in_program(albers_prog),
  :mentor_created_meeting => false)
  m.meeting_request.update_status!(m1.user_in_program(albers_prog), AbstractRequest::Status::ACCEPTED)
end

Given /^there is a upcoming meeting outside of a group$/ do
  m1 = Member.find_by(email: "robert@example.com")
  m2 = Member.find_by(email: "mkr@example.com")
  albers_prog = Program.find_by(root: "albers")  
  m = Meeting.create!(:topic => "Outside Group",
  :start_time => (Time.now + 1.hour), :end_time => (Time.now + 2.hours),
  :description => "Sample Desc", :group_id => nil,
  :members => [m1, m2],
  :owner_id => m2.id , :program_id => albers_prog.id,
  :requesting_student => m2.user_in_program(albers_prog),
  :mentee_id => m2.id,
  :requesting_mentor => m1.user_in_program(albers_prog),
  :mentor_created_meeting => false)
end

Given /^there is an accepted upcoming meeting outside of a group$/ do
  m1 = Member.find_by(email: "robert@example.com")
  m2 = Member.find_by(email: "mkr@example.com")
  albers_prog = Program.find_by(root: "albers")  
  m = Meeting.create!(:topic => "Outside Group",
  :start_time => (Time.now + 1.hour), :end_time => (Time.now + 2.hours),
  :description => "Sample Desc", :group_id => nil,
  :members => [m1, m2],
  :owner_id => m2.id , :program_id => albers_prog.id,
  :requesting_student => m2.user_in_program(albers_prog),
  :mentee_id => m2.id,
  :requesting_mentor => m1.user_in_program(albers_prog),
  :mentor_created_meeting => false)
  m.meeting_request.update_status!(m1.user_in_program(albers_prog), AbstractRequest::Status::ACCEPTED)
end

Then(/^I accept upcoming meeting outside if a group$/) do
  m1 = Member.find_by(email: "robert@example.com")
  albers_prog = Program.find_by(root: "albers")
  meeting = Meeting.find_by(topic: "Outside Group")
  meeting.meeting_request.update_status!(m1.user_in_program(albers_prog), AbstractRequest::Status::ACCEPTED)
end

Given /^there is a past meeting I attended inside of a group$/ do
  m1 = Member.find_by(email: "robert@example.com")
  m2 = Member.find_by(email: "mkr@example.com")
  albers_prog = Program.find_by(root: "albers")
  group = albers_prog.groups.first
  m = Meeting.create!(:topic => "Inside Group",
    :start_time => 4.hours.ago, :end_time => 2.hours.ago,
    :description => "Sample Desc", :group_id => group.id,
    :members => [m1, m2],
    :owner_id => m1.id , :program_id => albers_prog.id)
end

And /^I rsvp the meeting$/ do
  steps %{
    And I follow "Yes"
    Then I should see "The RSVP has been updated"
    And I follow "No"
    And I confirm popup
  }
end 

Then /^I enable the settings for mentor to connect without availability slots$/ do
  steps %{
    And I have logged in as "ram@example.com"
    And I login as super user
    When I follow "Albers Mentor Program"
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I check "program_calendar_setting_allow_mentor_to_describe_meeting_preference"
    And I check "program_calendar_setting_allow_mentor_to_configure_availability_slots"
    And I select "60 minutes" from "program_calendar_setting_slot_time_in_minutes"
    And I press "Save"
    And I logout
  }
end

And /^I set the message for connecting without availability slots and set the maximum slots$/ do
  program = Program.find_by(root: "albers")
  steps %{
    And I click on profile picture and click "Edit Profile"
    Then I follow "Settings"
    Then I click on the section with header "One-time Mentoring"
    Then I should see "One-time Mentoring"
    And I choose "member_will_set_availability_slots_false"
    And I fill in "member[availability_not_set_message]" with "Please contact me directly"
    And I fill in "max_meeting_slots_#{program.id}" with "4"
    And I press "Save" within "#settings_section_onetime"
  }
end

Then /^I send two non\-calendar meeting requests and withdraw one request$/ do
  steps %{
    And I follow "Actions"
    And I follow "Request Meeting"
    Then I should see "Meet with robert user"
    Then I should see "Enter Topic & Description"
    Then I should see "Propose Meeting Times"
    Then I should not see "Select Meeting Times"
    Then I should see "Topic *"
    Then I should see "Description *"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
    Then I should see "Description"
    Then I wait for "2" seconds
    }
    page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].focus()");
    page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].click()");
    steps %{
    Then I should see "robert user's Availability"
    Then I should see "Propose Times (UTC)"
    Then I follow "Enter Topic & Description"
    And I fill in "new_meeting_description" with "Test Withdrawal"
    Then I should not see "robert user's Availability"
    Then I should see "Description"
    Then I wait for "2" seconds
    }
    page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].focus()");
    page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].click()");
    steps %{
    Then I should see "robert user's Availability"
    And I fill in "mentee_general_availability_message" with "mentee general availability message"
    Then I follow "Request Meeting"
    Then I should see "Your request for a meeting with robert user has been successfully sent. You will be notified when robert user responds to your request. You can look for other mentors who are available and reach out to them from here."
    And I follow "Home" within "nav#sidebarLeft"
 
    And I click ".pending_requests_notification_icon"
    And I follow "Meeting Requests"
    And I should see "Withdraw Request"
    Then I follow "Withdraw Request"
    Then I choose "Withdrawn" within "div#sidebarRight"
    Then I should see "Test Withdrawal"
    When I navigate to "userrobert@example.com" profile in "albers"
    And I follow "Actions"
    And I follow "Request Meeting"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Kindly help needed in rails"
    Then I should see "Description"
    Then I wait for "2" seconds
  }
  page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].focus()");
  page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].click()");
  steps %{
    And I fill in "mentee_general_availability_message" with "mentee general availability message"
    Then I follow "Request Meeting"
    Then I should see "Your request for a meeting with robert user has been successfully sent. You will be notified when robert user responds to your request. You can look for other mentors who are available and reach out to them from here."
  }
end

Then /^I send a non\-calendar meeting request to mentor with name "([^\"]*)"$/ do |mentor_name|
  steps %{
    And I follow "Actions"
    And I follow "Request Meeting"
    Then I should see "Topic"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Kindly help needed in ruby"
    Then I should see "Description"
    Then I wait for "2" seconds
  }
  page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].focus()");
  page.execute_script("jQuery.find('.cjs_show_timing_tab')[0].click()");
  steps %{
    And I fill in "mentee_general_availability_message" with "mentee general availability message"
    Then I follow "Request Meeting"
    Then I should see "Your request for a meeting with #{mentor_name} has been successfully sent. You will be notified when #{mentor_name} responds to your request. You can look for other mentors who are available and reach out to them from here."
  }
end

Then /^I send a calendar meeting request$/ do
  steps %{
    And I follow "Actions"
    And I follow "Request Meeting"
    Then I should see "Meet with Good unique name"
    Then I should see "Enter Topic & Description"
    Then I should see "Select Meeting Times"
    Then I should see "Topic *"
    Then I should see "Description *"
    And I fill in "new_meeting_title" with "Calendar Meeting"
    And I fill in "new_meeting_description" with "Let us meet and have a general meeting"
    Then I follow "Proceed to Select Times"
    Then I should not see "Description *"
    Then I should see "Good unique name's Availability (UTC)"
    Then I should see "HSB"
    Then I should see "View Good unique's Calendar"
    Then I should see "Propose other times"
    Then I should see "01:00 PM"
    Then I should see "02:00 PM"
    Then I follow "Choose" within ".cjs_availability_slot_list"
    Then I should see "( Change Slot )"
    Then I press "Request Meeting"
    Then I should see "Your request for a meeting with Good unique name has been successfully sent. You will be notified when Good unique name responds to your request. You can look for other mentors who are available and reach out to them from here."
  }
end

Then /^I try to request meeting when the maximum slots setting of the mentor is reached$/ do
  steps %{
    When I navigate to "userrobert@example.com" profile in "albers"
    And I follow "Actions"
    And I should see disabled "Request Meeting"
    Then I hover over link with text "Request Meeting" within "#mentor_profile"
    And I should see "robert user has already reached the limit for the number of meetings and is not available for meetings"
  }
end


Then /^I decline the other meeting request$/ do
  step "I choose \"Pending\" within \"div#sidebarRight\""
  steps %{
    And I follow "Decline request"
    Then I fill in "meeting_request[response_text]" with "Sorry I wont be able to make it "
    Then I choose "Not the right match"
    And I press "Decline"
    Then I choose "Declined" within "div#sidebarRight"
    And I should see "Kindly help needed in ruby"
  }
end


When /^I accept the calendar meeting request$/ do
  steps %{
    Then I should see "Requests"
    Then I wait for "2" seconds
    And I click ".pending_requests_notification_icon"
    And I follow "Meeting Requests"
    And I follow "Accept this time"
    Then I close modal
    And I follow "Home"
    And I click ".pending_requests_notification_icon"
    And I follow "Meeting Requests"
    Then I choose "Accepted" within "div#sidebarRight"
    Then I should see "Calendar Meeting"
  }
end

Then /^Admin update expiry date of group named "([^\"]*)" to a year from now$/ do |group_name|
  date = 1.year.from_now.strftime("%B %d, %Y")
  step "Admin update expiry date of group named \"#{group_name}\" to \"#{date}\""
end

And /^I should see "([^\"]*)" as total count and "([^\"]*)" as subcount for meeting requests$/ do |requests_count, meeting_count|
  within ".cjs_footer_total_requests" do
    step "I should see \"#{requests_count}\""
  end
  step "I click \".cjs_footer_total_requests\""
  within ".cjs_footer_upcoming_meetings" do
    step "I should see \"#{meeting_count}\""
  end
  step "I close modal"
end

And /^I mark occurrence number "([^\"]*)" as "([^\"]*)" from "([^\"]*)"$/ do |occurrence, response, place|
  meeting = Meeting.last
  occurrence = meeting.occurrences[occurrence.to_i]
  html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
  decline_text = (place == "Side Pane") ? "Decline" : "Decline Meeting"
  if((place == "Side Pane" || place == "Side Pane mobile"))
    occurrence_date = DateTime.localize(occurrence, format: :full_display)
  else
    occurrence_date = DateTime.localize(occurrence, format: :full_display_no_time_with_day_short)
  end
  step "I should see \"#{occurrence_date}\""
  if(place == "Side Pane mobile")
    step "I change to mobile view"
  end
  if(response == "Yes")
    if((place == "Side Pane" || place == "Side Pane mobile"))
      meeting_div = (place == "Side Pane mobile") ? "#side_pane_meetings_mobile div.#{html_meeting_id}" : "#side_pane_meetings div.#{html_meeting_id}"
      steps %{
          And I should not see "Attending" within "#{meeting_div}"
          Then I follow "Yes" within "#{meeting_div}"
          And I should see "Attending" within "#{meeting_div}"
        }
    else
      within "#upcoming_meetings ##{html_meeting_id}" do
        steps %{
          And I should not see "Attending(Change)"
          And I follow "Yes"
          And I should see "Attending(Change)"
        }
      end
    end
  else
    if((place == "Side Pane" || place == "Side Pane mobile"))
      meeting_div = (place == "Side Pane mobile") ? "#side_pane_meetings_mobile div.#{html_meeting_id}" : "#side_pane_meetings div.#{html_meeting_id}"
      sidepane_div = (place == "Side Pane mobile") ? "#side_pane_meetings_mobile" : "#side_pane_meetings"
      steps %{
        Then I follow "No" within "#{meeting_div}"
        And I follow "#{decline_text}"
        And I should not see "#{occurrence_date}" within "#{sidepane_div}"
        And I should not see "Not Attending(Change)" within "#{sidepane_div}"
      }
    else
      within "#upcoming_meetings ##{html_meeting_id}" do
        step "I should not see \"Not Attending(Change)\""
        step "I follow \"No\""
      end
      step "I follow \"Decline Meeting\""
      step "I should see \"#{occurrence_date}\""
      step "I should see \"Not Attending(Change)\" within \"#upcoming_meetings ##{html_meeting_id}\"" 
    end
  end
end

And /I remove occurrence number "([^\"]*)" with "([^\"]*)" option/ do |occurrence, option|
  meeting = Meeting.last
  occurrence = meeting.occurrences[occurrence.to_i]
  html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
  occurrence_date = DateTime.localize(occurrence, format: :full_display_no_time_with_day_short)

  step "I should see \"#{occurrence_date}\""
  within "##{html_meeting_id}" do
    steps %{
      And I click ".dropdown-toggle"
      And I follow "Delete"
    }
  end
  steps %{
    And I follow "#{option}"
    And I confirm popup
    And I should not see "#{occurrence_date}"
  }
end

And /^I validate accept message popup data for meeting with topic "([^\"]*)", count as "([^\"]*)" and limit as "([^\"]*)"$/ do |topic, count, limit|
  meeting = Meeting.find_by(topic: topic)
  start_date = DateTime.localize(meeting.start_time, format: :month_year)
  if (count.to_i==1)
    text = (limit.to_i==0)? "For "+start_date.to_s+", you have "+count.to_s+" meeting scheduled and cannot accept requests for more. Change" : "For "+start_date.to_s+", you have "+count.to_s+" meetings scheduled and cannot accept requests for more. Change"
  else
    text = (limit.to_i==0)? "For "+start_date.to_s+", you have "+count.to_s+" meetings scheduled and cannot accept requests for more. Change" : "For "+start_date.to_s+", you have "+count.to_s+" meetings scheduled and cannot accept requests for more. Change"
  end
  steps %{
    And I should see "You are successfully connected"
    And I should see "Change"
    And I should see "#{text}"
  }
end

And /^I accept meeting request with topic "([^\"]*)"$/ do |topic|
  meeting_request_id =  Meeting.find_by(topic: topic).meeting_request_id
  within ".meeting_request_#{meeting_request_id}" do
    step "I should see \"#{topic}\""
    step "I follow \"Accept this time\""
  end
end

And /^I create a Meeting Request having topic "([^\"]*)" with "([^\"]*)" in program "([^\"]*)" for "([^\"]*)"$/ do |topic, mentor, program, date|
  if((date.include? "day") || (date.include? "days"))
    date = date.split(' ')
    date = date[0].to_i.days.from_now  
  elsif((date.include? "month") || (date.include? "months"))
    date = date.split(' ')
    date = date[0].to_i.months.from_now
  else
    date = date.split(' ')
    date = date[0].to_i.years.from_now
  end
  date = DateTime.localize(date, format: :full_display_no_time)
  steps %{
    Then I should see "Mentors"
    Then I follow "Mentors"
    When I navigate to "#{mentor}" profile in "#{program}"
    Then I follow "Actions"
    And I follow "Request Meeting"
    And I fill in "new_meeting_title" with "#{topic}"
    And I fill in "new_meeting_description" with "Meeting Request"
    And I follow "Proceed to Propose Times"
    Then I wait for "2" seconds
    And I click ".cjs_edit_slot"
    And I select "#{date}" for "#cjs_meeting_slot_1_date" from datepicker
    And I follow "Save"
    Then I wait for "1" seconds
    And I follow "Request Meeting"
  }
end

Then /^I change to mobile view$/ do
  if Capybara.current_driver == :selenium
    window = Capybara.current_session.driver.browser.manage.window
    window.resize_to(700, 700)
  end
end

Then /^I change to desktop view$/ do
  if Capybara.current_driver == :selenium
    window = Capybara.current_session.driver.browser.manage.window
    window.resize_to(1600, 900)
  end
end

And /^I go_to Meeting Show Page$/ do
  meeting = Meeting.last
  occurrence = meeting.occurrences[0]
  occurrence_date = DateTime.localize(occurrence, format: :full_display_no_time_with_day_short)
  step "I should see \"#{occurrence_date}\""
end

And /^I reschedule occurrence number "([^\"]*)"$/ do |occurrence|
  meeting = Meeting.last
  occurrence = meeting.occurrences[occurrence.to_i]
  html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
  occurrence_date = DateTime.localize(occurrence, format: :full_display_no_time_with_day_short)
  step "I should see \"#{occurrence_date}\""
  within "##{html_meeting_id}" do
    steps %{
      And I click ".cjs_rsvp_accepted"
      }
  end
  step "I click button \".modal.fade.in .btn.btn-primary.Rsvp_accepted_reschedule\" inside a modal"
  step "I wait for ajax to complete"
end

And /^I edit occurrence number "([^\"]*)"$/ do |occurrence|
  meeting = Meeting.last
  occurrence = meeting.occurrences[occurrence.to_i]
  html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
  occurrence_date = DateTime.localize(occurrence, format: :full_display_no_time_with_day_short)
  step "I should see \"#{occurrence_date}\""
  within "##{html_meeting_id}" do
    steps %{
      And I click ".dropdown-toggle"
      And I follow "Edit"
    }
  end
  step "I wait for ajax to complete"
end

Then /^I save the edited meeting with "([^\"]*)" option$/ do |option|
  within "#edit_meeting .form-actions" do
    step "I click \".btn\""
  end
  steps %{
    And I click "#{option}"
    Then I wait for ajax to complete
  }
end

Then /^I validate data for edited things and destroy meeting$/ do
  meeting = Meeting.last
  occurrence = meeting.occurrences.first
  html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
  steps %{
    Then I should see "04:00 am UTC (30 min)" within "##{html_meeting_id}"
    Then I should see "U.S.A" within "##{html_meeting_id}"
  }
  occurrence = meeting.occurrences.second
  unless occurrence.nil?
    html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
    steps %{
      Then I should see "04:00 am UTC (30 min)" within "##{html_meeting_id}"
      Then I should see "U.S.A" within "##{html_meeting_id}"
    }
  end
  meeting.destroy
end

And /^I Reschedule meeting with topic "([^\"]*)"$/ do |topic|
  step "I follow \"#{topic}\""
  step "I follow \"Change\""
  step "I click button \".modal.fade.in .btn.btn-primary.Rsvp_accepted_reschedule\" inside a modal"
end

Then /^I RSVP the recurrent meetings$/ do
  meeting = Meeting.find_by(topic: "Recurrent Daily Meeting").id 
  occurance_list = Meeting.find_by(topic: "Recurrent Daily Meeting").occurrences
  firstmeet = occurance_list[0].start_time.to_time.to_i
  secondmeet = occurance_list[1].start_time.to_time.to_i
  thirdmeet = occurance_list[2].start_time.to_time.to_i

  within "#meeting_#{meeting}_#{firstmeet}" do 
    steps %{
      And I follow "Yes"
      Then I should see "Attending(Change)"
    }
  end

  within "#meeting_#{meeting}_#{secondmeet}" do
    step "I follow \"No\""
  end

  step "I set the focus to the main window"
  step "I close modal"

  within "#meeting_#{meeting}_#{secondmeet}" do
    step "I should see \"Yes\""
    step "I follow \"No\""
    step "I wait for ajax to complete"
  end
  
  step "I click button \".modal.fade.in .btn.btn-white.Rsvp_accepted_decline\" inside a modal"

  within "#meeting_#{meeting}_#{secondmeet}" do
    step "I should see \"Not Attending(Change)\""
  end

  within "#meeting_#{meeting}_#{thirdmeet}" do
    step "I should see \"Yes\""
  end
end

Then /^I click button "([^\"]*)" inside a modal$/ do |button|
  step "I wait for \"2\" seconds"
  CucumberWait.retry_until_element_is_visible{find(:css, button).click}
end 

Given /^there are no meeting requests$/ do
  MeetingRequest.destroy_all
end

Then /Admin update expiry date of group named "([^\"]*)" to "([^\"]*)"/ do |name, expiry_date|
  group = Group.find_by(name: name)
  group.update_attribute(:expiry_time, Time.parse(expiry_date).utc.end_of_day)
end

Then(/^I fill in datepicker with id "(.*?)" with current date$/) do |element_id|
  date = Time.now.strftime("%B %d, %Y")
  steps %{
    And I select "#{date}" for "##{element_id}" from datepicker
  }
end

And /^I allow mentors in the program to configure availability slots/ do
  steps %{
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Matching Settings"
    And I check "program_calendar_setting_allow_mentor_to_configure_availability_slots"
    And I press "Save"
  }
end

Then /^I select a date (\d+) years from now for "(.*?)" from datepicker$/  do |years, date_field_id|
  year = years.to_i
  step "I select \"#{DateTime.localize(Time.now + year.years, format: :full_display_no_time)}\" for \"##{date_field_id}\" from datepicker"
end

Then /^I should see a date (\d+) years from now$/ do |years|
  year = years.to_i
  date = DateTime.localize(Time.now + year.years, format: :full_display_no_time)
  steps %{
    And I should see "date"
  }
end

Given /^mentors in "([^\"]*)":"([^\"]*)" are allowed to configure availability slots$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  calendar_setting = program.calendar_setting
  calendar_setting.allow_mentor_to_configure_availability_slots = true
  calendar_setting.save!
end

Given /^mentors in "([^\"]*)":"([^\"]*)" are not allowed to configure availability slots$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  calendar_setting = program.calendar_setting
  calendar_setting.allow_mentor_to_configure_availability_slots = false
  calendar_setting.save!
end

Given /^mentors in "([^\"]*)":"([^\"]*)" are allowed to describe meeting preference$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  calendar_setting = program.calendar_setting
  calendar_setting.allow_mentor_to_describe_meeting_preference = true
  calendar_setting.save!
end

Given /^mentors in "([^\"]*)":"([^\"]*)" are allowed to configure only availability slots$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  calendar_setting = program.calendar_setting
  calendar_setting.allow_mentor_to_describe_meeting_preference = false
  calendar_setting.allow_mentor_to_configure_availability_slots = true
  calendar_setting.save!
end

Then(/^I reset rsvp responses for the last meeting$/) do
  meeting = Meeting.last
  meeting.member_meetings.update_all(attending: MemberMeeting::ATTENDING::NO_RESPONSE)
end

And /^I change the description of the last created meeting to empty$/ do
  Meeting.last.update_column(:description, "")
end

Then(/^member with email "(.*?)" should not see no available timeslot message$/) do |email|
  steps %{
    Then I should not see "You don't have any available time slots. Please provide your availability."
  }
end

Then(/^member with email "(.*?)" should see no available timeslot message$/) do |email|
  steps %{
    Then I should see "You don't have any available time slots. Please provide your availability."
  }
end

Then /^I should see "([^\"]*)" with in the meeting with topic "([^\"]*)" and occurrence "([^\"]*)"$/ do |text, topic, occurrence|
  meeting = Meeting.find_by(topic: topic)
  occurrence = meeting.occurrences[occurrence.to_i]
  html_meeting_id = "meeting_#{meeting.id}_#{occurrence.to_i}"
  within "##{html_meeting_id}" do
    steps %{
      Then I should see "#{text}"
    }
  end
end