Then /^I set the ckeditor content to "([^\"]*)" with id "([^\"]*)"$/ do |content, elem_id|
  sleep(2) # wait until ckeditor loads
  page.evaluate_script(%Q[CKEDITOR.instances['#{elem_id}'].setData("#{content}")])
end

Then /^I set the content to "([^\"]*)" with id "([^\"]*)"$/ do |content, elem_id|
  page.execute_script(%Q[jQuery('##{elem_id}').val('#{content}')])
end

Then /^I set the select with id "([^\"]*)"$/ do |elem_id|
  page.execute_script(%Q[jQuery('##{elem_id}').prop('checked', true)])
end

And /^I Enable Version "([^\"]*)"$/ do |version|
  host = URI(Capybara.default_host).host
  Program::Domain.where(:subdomain => host.split(".", 2)[0], :domain => host.split(".", 2)[1])[0].organization.security_setting.update_attribute(:sanitization_version, version)
end

And /^I set organization backend setting "([^\"]*)" to "([^\"]*)"$/ do |setting, val|
  host = URI(Capybara.default_host).host
  organization = Program::Domain.where(:subdomain => host.split(".", 2)[0], :domain => host.split(".", 2)[1])[0].organization
  settings_chain = setting.split(".").map(&:to_sym)
  final_setting_model = organization
  settings_chain[0...-1].each { |s| final_setting_model = final_setting_model.send(s) }
  final_setting_model.update_attribute(settings_chain[-1], val == "true" ? true : val == "false" ? false : val)
end

Then /^I visit Program Invitations Index page$/ do
  visit program_invitations_path(:root => "albers")
end

Then /^I visit Program Events Index page$/ do
  visit program_events_path(:root => "albers")
end

Then /^I visit Add a new resource$/ do
  visit new_resource_path(:root => "albers")
end

Then /^I visit Add a new page Org Level$/ do
  visit new_page_path
end

Then /^I visit Add a new page Program Level$/ do
  visit new_page_path(:root => "albers")
end

And /^I resend the first Invite with content "([^\"]*)"$/ do |content|
  invite_element_id = page.evaluate_script(%Q[jQuery("#groups tr:first").attr("id")])
  invite_id = invite_element_id.split("_")[1]
  page.execute_script(%Q[jQuery('#resend_#{invite_id}').click()])
#  sleep(2)
  page.evaluate_script("CKEDITOR.instances['program_invitation_message_#{invite_id}'].setData('#{content}')")
  page.execute_script(%Q[jQuery('#edit_program_invitation_#{invite_id}').submit()])
end

Then /^I choose to ignore warning and proceed$/ do
  page.execute_script("jQuery('input[name=cjs_insecure_warnings_approach]:checked').attr('checked', false)")
  page.execute_script("jQuery('input[name=cjs_insecure_warnings_approach]').eq(2).attr('checked', true)")
  step 'I click "a.cjs_insecure_content_proceed_actions"'
end