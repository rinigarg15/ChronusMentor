# encoding: utf-8
Given(/^I navigate to new announcement page$/) do
  steps %{
    And I navigate to announcements page
    And I follow "New Announcement"
  }
end

When (/^I navigate to announcements listing$/) do
  step "I follow \"Back to announcements\""
end

Given(/^I delete all announcements$/) do
  Announcement.delete_all
end

Given(/^"([^\"]*)" creates an announcement with title "([^\"]*)"$/) do |email, title|
  o = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  p = o.programs.find_by(root: "albers")
  user = User.find_by_email_program(email, p)
  Announcement.create!(:admin => user, :program => user.program, :title => title, :body => "hello", :recipient_role_names => p.roles_without_admin_role.collect(&:name), :email_notification => 0)
end

When(/^I navigate to announcements page$/) do
  steps %{
    And I follow "Manage"
    And I follow "Announcements"
  }
end


And /^I fill in "([^\"]*)" with a expiry date 20 days from now$/ do |text_field_id|
  step "I select \"#{formatted_time_in_words(Time.now + 20.days)}\" for \"##{text_field_id}\" from datepicker"
end

And /^I fill in "([^\"]*)" with a date -1 days from now$/ do |text_field_id|
  step "I select \"#{DateTime.localize(1.day.ago, format: :full_display_no_time)}\" for \"##{text_field_id}\" from datepicker"
end

And /^I fill in "([^\"]*)" with a date 20 days from now$/ do |text_field_id|
  step "I select \"#{DateTime.localize(Time.now + 20.days, format: :full_display_no_time)}\" for \"##{text_field_id}\" from datepicker"
end

And /^I click ibox dropdown action inside "([^\"]*)"$/ do |div_class|
  within "div##{div_class}" do
    step "I click \"span.caret\""
  end
end