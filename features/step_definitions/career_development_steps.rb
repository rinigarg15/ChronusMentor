Then /^I should see programs "([^\"]*)" in order inside kendo table$/ do |programs|
  programs = programs.split(",")
  programs.each_with_index do |program, index|
    if index != programs.size - 1
      xpath = "//div/b/a[contains(text(), '#{program.strip}')]/../../following-sibling::*/b/a"
      assert_equal programs[index+1].strip, find(:xpath, xpath).text 
    end
  end
end

Then /^I should find programs "([^\"]*)" in order in element "([^\"]*)"$/ do |programs, element|
  programs = programs.split(",").map{|program| program.strip}
  assert page.has_css?(element)
  assert_equal programs, page.all(element).collect{|c| c.text}
end


Then /^I create a career development portal for "([^\"]*)"$/ do |organization|
  organization = Organization.where(name: organization).first
  create_career_dev_portal(organization: organization)
end

Then /^I see "([^\"]*)" as user info for "([^\"]*)"$/ do |user_info, user_email|
  member_id = Member.find_by(email: user_email).id
  step "I should see \"#{user_info}\" within \".cui_program_event_member_#{member_id}\""
end

Then /^I select member with email "([^\"]*)" in all members page$/ do |user_email|
  member_id = Member.find_by(email: user_email).id
  step "I check \"ct_admin_view_checkbox_#{member_id}\""
end