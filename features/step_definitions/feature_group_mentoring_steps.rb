require File.dirname(__FILE__) + '/../../app/helpers/application_helper'
include ApplicationHelper
include ActionView::Helpers::DateHelper

When /^I show preference for this mentor by saying "([^\"]*)"$/ do |msg|
  steps %{
    And I fill in "user_favorite_note" with "#{msg}"
    And I press "Save"
  }
end

When /I select the mentor "([^\"]*)" as a choice/ do |mentor_name|
  within "#choice_list" do
    step "I select \"#{mentor_name}\" from \"preferred_mentor_ids[]\""
  end
end

When /^I fill in the group_mentor with "([^\"]*)"$/ do |arg1|
  step "I fill in \"group_mentor_#{MentorRequest.last.id}\" with \"#{arg1}\""
end

Then /^I configure messaging in the connection template$/ do
  prog = Program.find_by(name: "psg")
  m = MentoringModel.find_by_program_id("#{prog.id}")
  m.allow_messaging = true
  m.save!
end  

When /^I add another student to the group$/ do
  prog = Program.find_by(name: "psg")
  g = Group.last
  student2 = User.find_by_email_program("stud2@psg.com", prog)
  g.students << student2
end

When /^I visit the mentoring connection of mentor "([^\"]*)"$/ do |email|
  cu = Member.find_by(email: email)
  u = cu.users.order("id ASC").first
  gid = u.groups.first.name
  page.execute_script('jQuery("div#subtabs_my_mentoring_connections").show();')
  step "I follow \"#{gid}\""
end

Given /^that a group expires in "([^\"]*)" days$/ do |n|
  n = n.to_i
  g = Group.first
  g.update_attribute(:expiry_time, n.days.from_now)
  if n > 0
    assert !g.expired?
  else
    assert g.expired?
  end
end

Given /^that its not yet closed$/ do
  assert Group.first.active?
end

Given /^that its inactive$/ do
  g = Group.first
  g.update_attribute(:status, Group::Status::INACTIVE)
  assert g.inactive?
end

Then /^the group must be closed$/ do
  assert Group.first.closed?
end

Then /^the group must be active$/ do
  assert Group.first.active?
end

Then /^the group must be inactive$/ do
  assert Group.first.inactive?
end

Then /^an expiry notification mail should go to members$/ do
  email_ids = Group.first.members.collect(&:email).join(",")
  subject = "your mentoring connection, name & madankumarrajan, has come to a close"
  step "individual mails should go to \"#{email_ids}\" having \"#{subject}\""
end

Given /^that the fourth group is terminated due to expiry$/ do
  g = Group.all[3]
  g.actor = g.program.admin_users.first
  g.update_attribute(:status, Group::Status::ACTIVE)
  assert g.active?
  Timecop.travel(3.days.ago)
  g.update_attribute(:expiry_time, 2.days.from_now)
  Timecop.return
  assert g.expired?
  assert g.active?
  Group.terminate_expired_connections
  assert g.reload.closed?
end

Then /^the connections listing should be "([^\"]*)" connections$/ do |type|
  if type == "my"
    assert assigns(:is_my_connections_view)
    assert_false assigns(:is_global_connections_view)
    assert_false assigns(:groups).nil?
  elsif type == "show"
    assert_nil assigns(:is_my_connections_view)
    assert_nil assigns(:is_global_connections_view)
    assert_nil assigns(:groups)
    assert_false assigns(:group).nil?
  elsif type == "manage"
    assert_false assigns(:is_my_connections_view)
    assert_false assigns(:is_global_connections_view)
    assert_false assigns(:groups).nil?
  elsif type == "global"
    assert_false assigns(:is_my_connections_view)
    assert assigns(:is_global_connections_view)
    assert_false assigns(:groups).nil?
  end
end

Then /^I fill in first "([^\"]*)" with a date 10 days from now$/ do |text_field_id|
  page.execute_script("jQuery(\"##{text_field_id}_#{Group.first.id}\").val(\"#{formatted_time_in_words((Time.now + 10.days), no_time: true)}\")")
end

Then /^I should first see a mail$/ do
  time_var = distance_of_time_in_words(formatted_time_in_words((Time.now + 20.days),:no_time => true),Time.now)
  string = "The mentoring connection was recently changed. This mentoring connection ends in "+time_var
  step "I should see \"#{string}\""
end

Then /^I fill in fourth "([^\"]*)" with a date 20 days from now$/ do |text_field_id|
  page.execute_script("jQuery(\"##{text_field_id}_#{Group.all[3].id}\").val(\"#{formatted_time_in_words((Time.now + 20.days),:no_time => true)}\")")
end

Then /^I should first see a reactivation mail$/ do
  time_var = distance_of_time_in_words(formatted_time_in_words((Time.now.end_of_day + 20.days)),Time.now)
  string = "The mentoring connection was recently reactivated. This mentoring connection ends in "+time_var
  step "I should see \"#{string}\""
end

Then /^I fill in first "([^\"]*)" with an invalid date$/ do |text_field_id|
  page.execute_script("jQuery(\"##{text_field_id}_#{Group.first.id}\").val(\"#{formatted_time_in_words(Time.now - 20.days)}\");")
end

Then /^I fill in first "([^\"]*)" with a old date$/ do |text_field_id|
  page.execute_script("jQuery(\"##{text_field_id}_#{Group.first.id}\").val(\"December 31, 1999\");")
end

Given /^I fill in first "([^\"]*)" with "([^\"]*)"$/ do |field, text|
  step "I fill in \"#{field}_#{Group.first.id}\" with \"#{text}\""
end

Given /^I fill in fourth "([^\"]*)" with "([^\"]*)"$/ do |field, text|
  step "I fill in \"#{field}_#{Group.all[3].id}\" with \"#{text}\""
end

Then /^I fill in fourth "([^\"]*)" with an invalid date$/ do |text_field_id|
  page.execute_script("jQuery(\"##{text_field_id}_#{Group.all[3].id}\").val(\"#{formatted_time_in_words(Time.now - 20.days)}\");")
end

Then /^I fill in fourth "([^\"]*)" with a old date$/ do |text_field_id|
  page.execute_script("jQuery(\"##{text_field_id}_#{Group.all[3].id}\").val(\"December 31, 1999\");")
end

Given /^I press first "([^\"]*)" button$/ do |button|
  step "I press \"#{button}_#{Group.first.id}\""
end

Given /^I press fourth "([^\"]*)" button$/ do |button|
  step "I press \"#{button}_#{Group.all[3].id}\""
end

Then /^running cron task expire connections should not trigger emails$/ do
  assert_no_difference('ActionMailer::Base.deliveries.size') do
    Group.terminate_expired_connections
  end
end

Given /^the cron task expire connections runs$/ do
  Group.terminate_expired_connections
end

And /I prepone expiry time for closed group "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |group_name, subdomain, root|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, subdomain)
  program = organization.programs.find_by(root: root)
  program.groups.closed.find_by(name: group_name).update_columns(expiry_time: 2.days.ago)
end