Given /^the current program admin has enabled allow_mentor_to_configure_availability_slots in calendar_settings$/ do
  p = Program.find_by(root: "albers")
  unless p.calendar_setting.present?
    p.create_calendar_setting
  end
  p.calendar_setting.update_attribute(:allow_mentor_to_configure_availability_slots, true)
end

Given /^the current program admin has connection_limit_permission NONE$/ do
  p = Program.find_by(root: "albers")
  p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::NONE)
end

Given /^the current program admin has connection_limit_permission ONLY_INCREASE$/ do
  p = Program.find_by(root: "albers")
  p.update_attribute(:connection_limit_permission, Program::ConnectionLimit::ONLY_INCREASE)
end

And /^I should not see max_connections_limit$/ do
  assert_false page.evaluate_script(%Q[jQuery('input#max_connections_limit').length > 0]), "User connections limit should not present"
end

And /^I should see max_connections_limit$/ do
  assert page.evaluate_script(%Q[jQuery('input#max_connections_limit').length > 0]), "User connections limit should not present"
end

And /^I should not see max_capacity settings$/ do
  p = Program.find_by(root: "albers")
  assert_false page.evaluate_script(%Q[jQuery('#max_meeting_slots_#{p.id}').length > 0]), "User capacity slots should not present"
end

And /^I should see max_capacity settings$/ do
  p = Program.find_by(root: "albers")
  assert page.evaluate_script(%Q[jQuery('#max_meeting_slots_#{p.id}').length > 0]), "User capacity slots should present"
end

And /^I fill in Frequesny Slots with "([^\"]*)"$/ do |value|
  p = Program.find_by(root: "albers")
  assert page.evaluate_script(%Q[jQuery('#max_meeting_slots_#{p.id}').length > 0])
  page.execute_script(%Q[jQuery('#max_meeting_slots_#{p.id}').val(#{value.to_json})])
end

And /^I should see new mentoring slot$/ do 
  assert page.evaluate_script(%Q[jQuery('#new_mentoring_slot').is(':visible')]), "User availability slot block should present"
end

And /^I should not see new mentoring slot$/ do 
  assert_false page.evaluate_script(%Q[jQuery('#new_mentoring_slot').is(':visible')]), "User availability slot should not present"
end

And /^I choose "([^\"]*)" value in "([^\"]*)"s radiobutton "([^\"]*)"$/ do |value, object_name, field_name|
  choose("#{object_name}_#{field_name}_#{value}")
end
