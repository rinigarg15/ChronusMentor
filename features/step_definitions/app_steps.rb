# encoding: utf-8
require 'rake'
require 'rake/testtask'
require 'rdoc/task'

#########
# Initializations
#########

Then /^I maximize the window$/ do
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  if (ENV['BS_RUN'] == 'true')
   Capybara.current_session.driver.browser.manage.window.resize_to(2048, 1536)
  else
   Capybara.current_session.driver.browser.manage.window.resize_to(1920, 1200)
  end
end

Then /^I switch to latest window$/ do
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
end

Then /^I close the new window and switch to main window$/ do
  page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  page.driver.browser.close
  page.driver.browser.switch_to.window (page.driver.browser.window_handles.first)
end

Given /^the current program is "([^\"]*)":"([^\"]*)"$/ do |arg1, arg2|
  # Reset the program root carried from previous request/response cycle.
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  split = arg1.split(".")
  prog_root = arg2

  if split.size == 1
    subdomain = arg1
    domain = DEFAULT_HOST_NAME
  else
    subdomain = split.first
    domain = split[1..2].join('.')
  end

  if Capybara.current_driver == Capybara.javascript_driver
    step "I maximize the window"
  end
  
  SUBDOMAIN = subdomain
  Capybara.default_host = "http://#{subdomain}.#{domain}"
  Capybara.app_host = "http://#{subdomain}.#{domain}:#{Capybara.server_port}"
  PROGRAM_ROOT = prog_root
  unless prog_root.blank?
    visit about_path(root: prog_root)
  else
    visit about_path(organization_level: true)
  end
end

Given /default host/ do
  #The mattr_accessor variable is not getting reset properly after every scenario within a cucumber. So clearing it manually here.
  TranslationsService.program = nil
  Capybara.default_host = "http://#{DEFAULT_SUBDOMAIN}.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}"
  Capybara.app_host = "http://#{DEFAULT_SUBDOMAIN}.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}"
  visit "http://#{DEFAULT_SUBDOMAIN}.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}/"
end

Given /default demo host/ do
  Capybara.default_host = "http://#{DEFAULT_DEMO_SUBDOMAIN}.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}"
  Capybara.app_host = "http://#{DEFAULT_DEMO_SUBDOMAIN}.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}"
  visit "http://#{DEFAULT_DEMO_SUBDOMAIN}.#{DEFAULT_HOST_NAME}:#{Capybara.server_port}/"
end

And /^I visit default_demo_host$/ do ||
  step "default demo host"
end

Given /^there is one to many in "([^\"]*)":"([^\"]*)"$/ do |subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  allow_one_to_many_mentoring_for_program(program)
end

Given /^the current time is "([^"]*)"$/ do |time|
  rollbacktime = time.to_time
  Timecop.travel(rollbacktime)
end

Given /^the feature "([^\"]*)" is disabled for "([^\"]*)"$/ do |feature_name, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  org.enable_feature(feature_name, false)
end

Given /^the feature "([^\"]*)" is enabled for "([^\"]*)"$/ do |feature_name, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  org.enable_feature(feature_name, true)
end

Given /^the notification setting "([^\"]*)" is set to "([^\"]*)" for program "([^\"]*)"$/ do |setting, value, root|
  program = Program.find_by(root: root)
  program.notification_setting.update_attribute(setting, value)
end

#Tddium is not reindexing properly so reindexing the model manually
Then  /^I reindex model "([^\"]*)"$/ do |model_name|
  model = model_name.constantize
  includes_list = ElasticsearchConstants::INDEX_INCLUDES_HASH[model.name]
  model.delete_indexes if model.__elasticsearch__.index_exists?
  model.force_create_ex_index
  model.includes(includes_list).eimport
  model.refresh_es_index
end

#########
# Navigation
#########

Then /I select "([^\"]*)" from the program selector/ do |select_name|
  within ".navbar-header" do
    steps %{
      And I click ".my_programs_listing_link"
      And I follow "#{select_name}"
    }
  end
end

Then /^I should see the tab "([^\"]*)"$/ do |tab_name|
  within "ul.metismenu" do
      # The regex for text is to handle the tabs with subtabs,
      # in which case, the tab name is followed by html entities.
    step "I should see \"#{tab_name}\""
  end
end

Then /^I should not see the tab "([^\"]*)"$/ do |tab_name|
  within "ul.metismenu" do
    step "I should not see \"#{tab_name}\""
  end
end

Then /^I should see the tab "([^\"]*)" selected$/ do |tab_name|
  within (first(:css, "li.active")) do
    step "I should see \"#{tab_name}\""
  end
end

Then /^I should not see the tab "([^\"]*)" selected$/ do |tab_name|
  within (first("li.active")) do
    step "I should not see \"#{tab_name}\""
  end
end

Then /^I follow "([^\"]*)" tab$/ do |tab|
  within "ul.metismenu" do
    step "I follow \"#{tab}\""
  end
end

Then /^I follow "([^\"]*)" subtab in "([^\"]*)" tab$/ do |subtab_name, tab_name|
  within "ul.metismenu" do
    steps %{
      And I follow "#{tab_name}"
      Then I should see "#{subtab_name}"
      And I follow "#{subtab_name}"
    }
  end
end

Then /^I follow "([^\"]*)" subtab inside opened navigation header$/ do |subtab_name|
  within "ul.metismenu" do
    steps %{
      Then I should see "#{subtab_name}"
      And I follow "#{subtab_name}"
    }
  end
end

Then /^I follow "([^\"]*)" manage icon$/ do |tab|
  within "#manage" do
    step "I follow \"#{tab}\""
  end
end

Then /^I follow back link$/ do
  step "I click \"a.back_link.hidden-xs.hidden-sm\""
end

When /I find a mentor for situation "([^\"]*)"$/ do |situation_title|
  row_selector = "#situations_listing div:contains(\'#{situation_title}\') a:contains('Find a Mentor')"
  assert page.evaluate_script(%Q[jQuery("#{row_selector}").length > 0])
  link_val = page.evaluate_script(%Q[jQuery("#{row_selector}").attr("href")])
  page.execute_script(%Q[jQuery("#{row_selector}").attr("href", "#{link_val}&items_per_page=100")])
  page.execute_script(%Q[jQuery("#{row_selector}")[0].click()])
end

Then /^I sign in as "([^\"]*)"$/ do |email|
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  steps %{
    And I fill in by css "email" with "#{email}"
    And I fill in by css "password" with "monkey" 
    And I press "Login"
  }
end

When /^I have logged in as "([^\"]*)"( with_tour)?$/ do |login, with_tour|
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  steps %{
    And I follow "Login"
    Then I sign in as "#{login}"
    Then I should see "Sign out"
  }
  el = first("#management-report-tour-modal")
  if el.present? && with_tour.nil?
    step "I follow \"Dismiss\""
  end
end

When /^I have logged in as "([^\"]*)" without asserting signout$/ do |login|
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  steps %{
    And I follow "Login"
    Then I sign in as "#{login}"
  }
end

#Use this login step for Non-javascript scenarios
When /^I have logged in as "([^\"]*)" in headless mode$/ do |login|
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  steps %{
    And I follow "Login"
    Then I sign in as "#{login}"
    Then I wait for "1" seconds
  }
end

When /^I have logged in as "([^\"]*)" with_announcement$/ do |login|
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  steps %{
    And I follow "Login"
    Then I sign in as "#{login}"
    Then I wait for "1" seconds
  }
end

Then /^I dismiss announcement modal$/ do
  steps %{
    And I wait for "2" seconds
    Then I wait for ajax to complete
  }
  modal = first("#remoteModal")
  if modal.present? && first(".close-link-announcements").present?
    steps %{
      Then I close remote modal
      Then I wait for "1" seconds
    }
  end
end

Then /^I dismiss management report tour$/ do
  if first("#management-report-tour-modal").present?
    step "I follow \"Dismiss\""
  end
end

Then /^I dismiss campaign management report tour$/ do
  if first("#campaign-management-tour-modal").present?
    step "I follow \"Dismiss\""
  end
end

Given /^I clear the time zone cookie$/ do
 page.execute_script("jQuery.cookie(TimeZoneFlash.tzfConstants.tzfEnableHide, null, { path: '/' });")
end

When (/^I logout$/) do
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  step "I wait for ajax to complete"
  step "I close all modals"
  if first(".cjs_signout_link").present?
    step "I scroll the div \".sidebar-collapse\""
    step "I click \".cjs_signout_link\" within \"#sidebarLeft\""
  elsif first(".profile_header_image").present?
    page.execute_script %Q[jQuery(".profile_header_image").click();]
    step "I follow \"Sign out\" within \".cjs-profile-actions\""
  else
    #Nothing since the page is already logged out
    browser = Capybara.current_session.driver.browser
    if browser.respond_to?(:clear_cookies)
    # Rack::MockSession
      browser.clear_cookies
    elsif browser.respond_to?(:manage) and browser.manage.respond_to?(:delete_all_cookies)
    # Selenium::WebDriver
      browser.manage.delete_all_cookies
    else
      # Do Nothing
    end
  end
end

When /^I close all modals$/ do
  modal = first("#remoteModal")
  if modal.present?
    steps %{
      Then I close remote modal
      Then I wait for "2" seconds
    }
  end
  if first("div.modal").present?
    steps %{
      Then I close modal
      Then I wait for "2" seconds
    }
  end
end

Then /I should see the program title "([^\"]*)"$/ do |title|
  within "a.my_programs_listing_link" do
    step "I should see \"#{title}\""
  end
end

Then /^I navigate to "([^\"]*)" profile in "([^\"]*)"$/ do |email, root|
  m = Member.find_by(email: email)
  visit member_path(m ,root: root)
end

When /^I visit the profile of "([^\"]*)"$/ do |email|
  step "I navigate to \"#{email}\" profile in \"albers\""
end

When /^I visit the profile of the first mentor$/ do
  p = Program.find_by(root: "albers")
  mentor = p.mentor_users.first
  visit member_path(mentor.member, root: p.root)
end

Given(/^I navigate to Administrators page$/) do
  steps %{
    And I follow "Manage"
    And I follow "Administrators"
  }
end

Then /^I log out$/ do
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  step "I close all modals"
  step "I follow \"Sign out\""
end

When /^I login as super user$/ do
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  visit super_login_path()
  steps %{
    Then I should see "Passphrase"
    And I fill in "passphrase" with "#{APP_CONFIG[:super_console_pass_phrase]}"
    And I press "Login"
  }
end

When /^I visit solution packs listing$/ do
  visit 'solution_packs' 
end

When /^I logout as super user$/ do
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  if first(".cjs_signout_link").present?
    page.driver.execute_script("arguments[0].scrollIntoView(true)", first(".cjs_signout_link").native)
  end
  step "I follow \"Super User (sign out)\""
end

When /^I search for "([^\"]*)"$/ do |search_query|
  within ".search_container" do
    steps %{
      And I fill in "query" with "#{search_query}"
      And I press "submit_search"
    }
  end
end

Then /^I should see "([^\"]*)" in the search results$/ do |arg1|
  assert_select "#search_view", text: /#{arg1}/
end

Then /^I should not see "([^\"]*)" in the search results$/ do |arg1|
  assert_select "#search_view", text: /#{arg1}/, count: 0
end

Then /^I should see "([^\"]*)" hidden$/ do |arg1|
  page.evaluate_script(%Q[jQuery("#{arg1}").is(':hidden');])
end

Then /^I should see text "([^\"]*)" hidden$/ do |arg1|
  page.evaluate_script(%Q[jQuery(":contains(#{arg1})").is(':hidden');])
end

Then /^I should see "([^\"]*)" not hidden$/ do |arg1|
  page.execute_script(%Q[jQuery("#{arg1}").is(':visible');])
end

And /^I hide the date range picker$/ do
  page.execute_script %Q[jQuery("ui-datepicker-div").hide();]
end

Then /^I should be redirected to super login page$/ do
  assert_equal "/sl", current_path
end

#########
# Actions
#########

Then /^I enable "([^\"]*)" feature as a super user$/ do |feature_name|
  #And "I login as super user"
  #And "I follow \"Manage\""
  #And "I follow \"Program Settings\""
  #And "I follow \"Features\""
  #And "I check \"#{feature_name}\""
  #And "I press \"Save\""
  #And "I logout as super user"
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,SUBDOMAIN)
  if PROGRAM_ROOT.blank?
    org.enable_feature(feature_name, true)
    if feature_name.eql?"mentoring_connections_v2"
      org.enable_feature("mentoring_goals", false)
      org.enable_feature("mentoring_connection_meeting", true)
    end
  else
    program = org.programs.find_by(root: PROGRAM_ROOT)
    program.enable_feature(feature_name, true)
  end
end

Then /^I disable the feature "([^\"]*)"$/ do |feature_name|
  # The features are at organization level. So, need to go to organization home page
  #And "I follow \"Primary Organization\""
  #And "I follow \"Manage\""
  #And "I follow \"Program Settings\""
  #And "I follow \"Features\""
  #And "I uncheck \"#{feature_name}\""
  #And "I press \"Save\""
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,SUBDOMAIN)
  org.enable_feature(feature_name, false)
end

Then /^I disable the feature "([^\"]*)" as a super user$/ do |feature_name|
  #And "I login as super user"
  #And "I follow \"Manage\""
  #nd "I follow \"Program Settings\""
  #And "I follow \"Features\""
  #And "I uncheck \"#{feature_name}\""
  #And "I press \"Save\""
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,SUBDOMAIN)
  unless PROGRAM_ROOT.blank?
    program = org.programs.find_by(root: PROGRAM_ROOT)
    program.enable_feature(feature_name, false)
  else
    org.enable_feature(feature_name, false)
  end
end

Then /^the feature "([^\"]*)" should be "([^\"]*)" for "([^\"]*)"$/ do |feature_name, status, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  if status == "enabled"
    assert org.has_feature?(feature_name)
  elsif status == "disabled"
    assert_false org.has_feature?(feature_name)
  end
end

Then /I should see header my profile link/ do
  assert page.has_css?("#my_profile")
end

#########
# Email
#########
Then /^mail should go to "([^\"]*)" having "([^\"]*)"$/ do |email_list, content|
  mail = ActionMailer::Base.deliveries.last
  email_list.split(",").each do |email|
    assert mail.to.include? email
  end
  assert_match(/#{content}/, get_text_part_from(mail).gsub("\n", " "))
end

Then /^individual mails should go to "([^\"]*)" having "([^\"]*)"$/ do |email_list, content|
  count = email_list.split(",").length
  mails = ActionMailer::Base.deliveries.last(count)
  receivers = mails.collect(&:to).flatten
  assert_equal count, receivers.length
  assert_equal email_list.split(",").sort, receivers.sort
  mails.each do |mail|
    assert_match content, get_text_part_from(mail).gsub("\n", " ")
  end
end

# Check if a mail is sent to the given email id.
Then /^a mail should go to "([^\"]*)" having "([^\"]*)"$/ do |email, content|
  mail = ActionMailer::Base.deliveries.last
  assert_equal email, mail.to.first
  assert_match(/#{content}/, get_text_part_from(mail).gsub("\n", " "))
end

Then /^mails should go to "([^\"]*)" and "([^\"]*)" having "([^\"]*)"$/ do |email1, email2, content|
  mail = ActionMailer::Base.deliveries.last
  assert_equal email1, mail.to.first
  assert_match(/#{content}/, get_text_part_from(mail).gsub("\n", " "))
  mail = ActionMailer::Base.deliveries.last(2)[0]
  assert_equal email2, mail.to.first
  assert_match(/#{content}/, get_text_part_from(mail).gsub("\n", " "))
end

When(/I open new mail/) do
  open_last_email
end

When /^I open mail of "([^\"]*)"$/ do |email|
  open_email(email)
end

Then /^mail should have "([^\"]*)" attachment with name "([^\"]*)"$/ do |filetype, filename|
  mail = ActionMailer::Base.deliveries.last
  attachment = mail.attachments.first
  assert_match(/#{filename}/, attachment.filename)
  assert_match(/#{filetype}/, attachment.content_type)
end

And /^first attachment should have content "([^\"]*)"$/ do |text|
  mail = ActionMailer::Base.deliveries.last
  attachment = mail.attachments.first
  assert_match(/#{text}/, attachment.body.raw_source)
end

#########
# User declaration
#########

Given(/^"([^\"]*)" is not an administrator in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert_false User.find_by_email_program(email, program).is_admin?
end

Then(/^"([^\"]*)" should be an administrator in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert User.find_by_email_program(email, program).is_admin?
end

Then(/^"([^\"]*)" should not be an administrator in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert_false User.find_by_email_program(email, program).is_admin?
end

Given(/^"([^\"]*)" is an active user in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert User.find_by_email_program(email, program).active?
end

Given(/^"([^\"]*)" is not a student in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert_false User.find_by_email_program(email, program).is_student?
end

Given(/^"([^\"]*)" is not a mentor in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert_false User.find_by_email_program(email, program).is_mentor?
end

Then(/^check "([^\"]*)" is a student in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert User.find_by_email_program(email, program).is_student?
end

Then(/^check "([^\"]*)" is a mentor in "([^\"]*)":"([^\"]*)"$/) do |email, sub, root|
  program = get_program(root, sub)
  assert User.find_by_email_program(email, program).is_mentor?
end

Given /^There are no meeting requests for "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |email, sub, root|
  program = get_program(root, sub)
  user = User.find_by_email_program(email, program)
  user.sent_meeting_requests.destroy_all
  user.received_meeting_requests.destroy_all
end

Given /^There are no mentor requests for "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |email, sub, root|
  program = get_program(root, sub)
  user = User.find_by_email_program(email, program)
  user.sent_mentor_requests.destroy_all
  user.received_mentor_requests.destroy_all
end

Given /^There are no program events in "([^\"]*)":"([^\"]*)"$/ do |sub, root|
  program = get_program(root, sub)
  program.program_events.destroy_all
end


#########
# Page assertions
#########

Then /^I should see the flash "([^\"]*)"$/ do |arg1|
  within("div#toast-container") do
    step "I should see \"#{arg1}\""
  end
end

Then /^I should see "([^\"]*)" flash "([^\"]*)"$/ do |msg_type, text|
  within("div#toast-container.toast-#{msg_type}") do
    step "I should see \"#{text}\""
  end
end

Then /^I should not see any flash message$/ do
  assert_false page.evaluate_script("jQuery('div#toast-container').is(':visible')")
end

Then /^I should see the admin notes "([^\"]*)"$/ do |text|
  within("#admin_note blockquote") do
    step "I should see \"#{text}\""
  end
end

Then /^I should see the page title "([^\"]*)"$/ do |title|
  within "#page_heading" do
    step "I should see \"#{title}\""
  end
end

#Then /^I should see the page banner "([^\"]*)"$/ do |title|
#  within "h1#prog_name" do
#    And "I should see \"#{title}\""
#  end
#end

Then /^program selector should be present$/ do
  assert_select "#my_programs_container"
end

# Manage page items in categories
Then /^I shlould see "([^\"]*)" under "([^\"]*)" category$/ do |item_text, category_text|
  within 'div.pane' do
    within 'div.pane_header' do
      step "I should see \"#{category_text}\""
      within 'div.pane_content div.manage_box div.icon a span' do
        step "I should see \"#{item_text}\""
      end
    end
  end
end

And /^I navigate to "([^\"]*)" from manage page$/ do |link_name|
  steps %{
    And I follow "Manage"
    And I follow "#{link_name}"
  }
end

#########
# Debugging
#########

# Prints the html output
Then /print the response/ do
  puts page.body.to_s
end

Then /^debugger$/ do
  byebug
  1
end

Then /^(?:I )?stop and wait$/ do
  value = STDIN.getc
  byebug if value == "b"
end


#########
# Miscellaneous
#########

And /^"([^\"]*)" role "([^\"]*)" is called as "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |role_name, term_column, term_human_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  role_term = program.roles.find_by(name: role_name).customized_term
  role_term.send("#{term_column}=", term_human_name)
  role_term.save!
end

And /^"([^\"]*)" "([^\"]*)" is called as "([^\"]*)" in "([^\"]*)"$/ do |term_name, term_column, term_human_name, subdomain|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  term = org.customized_terms.find_by(term_type: term_name)
  term.send("#{term_column}=", term_human_name)
  term.save!
end

And /^"([^\"]*)" "([^\"]*)" is called as "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |term_name, term_column, term_human_name, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  term = program.customized_terms.find_by(term_type: term_name)
  term.send("#{term_column}=", term_human_name)
  term.save!
end

Given /^there are no activities$/ do
  RecentActivity.destroy_all
end

#########
# Notifications
#########

Given /^the notifications setting of "([^\"]*)" is "([^\"]*)"$/ do |email, setting|
  p = Program.find_by(root: "albers")
  u = User.find_by_email_program(email, p)
  u.program_notification_setting = str2setting(setting)
  u.save!

  assert_equal(str2setting(setting), u.reload.program_notification_setting)
end

Given /^"([^\"]*)" has a few pending notifications$/ do |email|
  p = Program.find_by(root: "albers")
  u = User.find_by_email_program(email, p)

  PendingNotification.create!(
    program: p,
    ref_obj_creator: u,
    action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
    ref_obj: Announcement.first
  )

  assert_not_equal(0, u.reload.pending_notifications.count)
end

Given /^I change the notification setting(?:( in accounts settings page))? to "([^\"]*)"$/ do |is_account_setting_page, arg1|
  program = Program.find_by(root: "albers")
  choose "user_program_notification_setting_#{str2setting(arg1)}_#{program.id}"
  if is_account_setting_page
    step "I press \"Save\""
  else
    within('#notifications_section') do
      step "I press \"Save\""
    end
  end
end

Given /^I change the mentoring mode setting to "([^\"]*)"$/ do |arg1|
  choose "user_mentoring_mode_#{metoringmodestr2setting(arg1)}"
  within('#settings_section_general') do
    step "I press \"Save\""
  end
end

Given /^I edit the notification setting to "([^\"]*)"$/ do |arg1|
  program = Program.find_by(root: "albers")
  choose "user_program_notification_setting_#{str2setting(arg1)}_#{program.id}"
  within('.program_settings') do
    step "I press \"Save Settings\""
  end
end

Given /^I "([^"]*)" change the notification setting to "([^"]*)" and dismiss alert box$/ do |member_email, setting|
  member = Member.find_by(email: member_email)
  program = Program.find_by(root: "albers")
  user = member.user_in_program(program)
  user.notification_setting = str2setting(setting)
  user.save!
end

Then /^existing pending notifications of "([^\"]*)" should be deleted$/ do |arg1|
  p = Program.find_by(root: "albers")
  user = User.find_by_email_program(arg1, p)
  assert_equal(0, user.pending_notifications.size)
end


#########
# Announcements
#########

Given /^creating a new mentor announcement should trigger a mail to "([^\"]*)" with content "([^\"]*)"$/ do |arg1, content|
  ActionMailer::Base.deliveries.clear
  assert_equal(0, ActionMailer::Base.deliveries.size)
  p = assigns(:current_program)
  create_announcement(program: p, admin: p.admin_users.first, email_notification: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY,
    recipient_role_names: [RoleConstants::MENTOR_NAME], body: content)
  all_mails = ActionMailer::Base.deliveries

  my_mail = all_mails.select { |m| m.to == [arg1] }.first
  assert_match(/#{content}/, my_mail.body)
end

Then /^creating a new "([^\"]*)" announcement should not trigger a mail to "([^\"]*)"$/ do |role, arg1|
  ActionMailer::Base.deliveries.clear
  assert_equal(0, ActionMailer::Base.deliveries.size)
  p = Program.find_by(root: "albers")
  to = { 'mentor' => RoleConstants::MENTOR_NAME, 'mentee' => RoleConstants::STUDENT_NAME}[role]
  create_announcement(program: p, admin: p.admin_users.first, email_notification: UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY,
    recipient_role_names: [to])
  all_mails = ActionMailer::Base.deliveries

  assert all_mails.select { |m| m.to == [arg1] }.empty?
end

#########
# Attachments
#########

When /^I set the attachment field "([^\"]*)" to "([^\"]*)"$/ do |field, new_attachment_name|
  file_path = Rails.root.to_s + "/test/fixtures/files/#{new_attachment_name}"
  if ENV['BS_RUN'] == 'true'
    remote_file_detection(file_path)
  end
  page.attach_file(field, file_path, visible: false)
end

When /^I set the attachment field with "([^\"]*)" to "([^\"]*)"$/ do |selector, new_attachment_name|
  file = fixture_file_upload(File.join('files', new_attachment_name))
  FileUploader.expects(:get_file_path).with(kind_of(Integer), kind_of(Integer), kind_of(String), has_entry(file_name: new_attachment_name)).returns(file).at_least(0)
  FileUploader.expects(:get_file_path).with(kind_of(Integer), kind_of(String), kind_of(String), has_entry(file_name: new_attachment_name)).returns(file).at_least(0)
  FileUploader.expects(:get_file_path).with(kind_of(Integer), kind_of(Integer), kind_of(String), has_entry(file_name: "")).returns(nil).at_least(0)
  field = page.evaluate_script(%Q[jQuery("#{selector}").attr("name")])
  file_path = Rails.root.to_s + "/test/fixtures/files/#{new_attachment_name}"
  if ENV['BS_RUN'] == 'true'
   remote_file_detection(file_path)
  end
  page.attach_file(field, file_path, visible: false)
end

Then /^I set the "([^\"]*)" for the "([^\"]*)" with name "([^\"]*)" to "([^\"]*)"$/ do |field, program_or_organization, name, new_attachment_name|
  program_or_organization = program_or_organization.constantize.find_by(name: name)
  program_asset = ProgramAsset.find_or_create_by(program_id: program_or_organization.id)
  program_asset.send("#{field}=", File.open(Rails.root.to_s + "/test/fixtures/files/#{new_attachment_name}", "rb"))
  program_asset.save!
end

#########
# Notification
#########

Then /^a student sending a mentor request to "([^\"]*)" "([^\"]*)" an email$/ do |arg1, arg2|
  should_send = (arg2 == 'should trigger')
  ActionMailer::Base.deliveries.clear
  p = Program.find_by(root: "albers")
  u = User.find_by_email_program(arg1, p)
  assert_emails should_send ? 1 : 0 do
    MentorRequest.create!(
      student: p.student_users.first,
      mentor: u,
      program: p,
      message: "Hi"
    )
  end

  if should_send
    mail = ActionMailer::Base.deliveries.last
    assert_equal [arg1], mail.to
  end
end


#########
# Programs
#########

Given /^that "([^\"]*)" is not set for the program "([^\"]*)":"([^\"]*)"$/ do |setting, subdomain, prog_root|
  program = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain).programs.find_by(root: prog_root)
  ActiveRecord::Base.connection.execute("UPDATE programs SET #{setting} = NULL WHERE programs.id = #{program.id}")
  program.reload
end

When /^I fill in location_question of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, loc_name|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  loc_ques_id = organization.profile_questions.select{|ques| ques.location?}.first.id
  step "I fill in \"profile_answers_#{loc_ques_id}\" with \"#{loc_name}\""
end

When /^I fill in education_question of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, education|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  edu_ques_id = organization.profile_questions.select{|ques| ques.education?}.first.id
  edu_array = education.split(',')
  steps %{
    And I fill in "profile_answers[#{edu_ques_id}][new_education_attributes][][school_name]" with "#{edu_array[0]}"
    And I fill in "profile_answers[#{edu_ques_id}][new_education_attributes][][degree]" with "#{edu_array[1]}"
    And I fill in "profile_answers[#{edu_ques_id}][new_education_attributes][][major]" with "#{edu_array[2]}"
  }
end

When /^I fill in education_question of "([^"]*)":"([^"]*)" of section "([^"]*)" with "([^"]*)" for (\d+) index of "([^"]*)"$/ do |subdomain, prog_root, section_title, education, instance, name_attribute|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  section = organization.sections.find_by(title: section_title)
  edu_ques_id = organization.profile_questions.where(section_id: section.id).select{|ques| ques.education?}.first.id
  edu_array = education.split(',')
  steps %{
    And I fill in "profile_answers[#{edu_ques_id}][#{name_attribute}][][#{instance}][school_name]" with "#{edu_array[0]}"
    And I fill in "profile_answers[#{edu_ques_id}][#{name_attribute}][][#{instance}][degree]" with "#{edu_array[1]}"
    And I fill in "profile_answers[#{edu_ques_id}][#{name_attribute}][][#{instance}][major]" with "#{edu_array[2]}"
  }
end

When /^I overwrite education_question of "([^"]*)":"([^"]*)" of section "([^"]*)" of user "([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, section_title, email, education|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  section = organization.sections.find_by(title: section_title)
  member = organization.members.find_by(email: email)
  edu_ques_id = organization.profile_questions.where(section_id: section.id).select{|ques| ques.education?}.first.id
  edu_id = member.profile_answers.where(profile_question_id: edu_ques_id).first.educations.first.id
  edu_array = education.split(',')
  steps %{
    And I fill in "profile_answers[#{edu_ques_id}][existing_education_attributes][#{edu_id}][school_name]" with "#{edu_array[0]}"
    And I fill in "profile_answers[#{edu_ques_id}][existing_education_attributes][#{edu_id}][degree]" with "#{edu_array[1]}"
    And I fill in "profile_answers[#{edu_ques_id}][existing_education_attributes][#{edu_id}][major]" with "#{edu_array[2]}"
  }
end

When /^I fill in experience_question of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, experience|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  exp_ques_id = organization.profile_questions.select{|ques| ques.experience?}.first.id
  exp_array = experience.split(',')
  steps %{
    And I fill in "profile_answers[#{exp_ques_id}][new_experience_attributes][][company]" with "#{exp_array[0]}"
    And I fill in "profile_answers[#{exp_ques_id}][new_experience_attributes][][job_title]" with "#{exp_array[1]}"
  }
end

When /^I fill in last experience_question of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, experience|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  exp_ques_id = organization.profile_questions.select{|ques| ques.experience?}.last.id
  exp_array = experience.split(',')
  steps %{
    And I fill in "profile_answers[#{exp_ques_id}][new_experience_attributes][][company]" with "#{exp_array[0]}"
    And I fill in "profile_answers[#{exp_ques_id}][new_experience_attributes][][job_title]" with "#{exp_array[1]}"
  }
end

When /^I fill in experience_question of "([^"]*)":"([^"]*)" of section "([^"]*)" with "([^"]*)" for (\d+) index of "([^"]*)"$/ do |subdomain, prog_root, section_title, experience, instance, name_attribute|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  section = organization.sections.find_by(title: section_title)
  exp_ques_id = organization.profile_questions.where(section_id: section.id).select{|ques| ques.experience?}.first.id
  exp_array = experience.split(',')
  steps %{
    And I fill in "profile_answers[#{exp_ques_id}][#{name_attribute}][][#{instance}][company]" with "#{exp_array[0]}"
    And I fill in "profile_answers[#{exp_ques_id}][#{name_attribute}][][#{instance}][job_title]" with "#{exp_array[1]}"
  }
end

When /^I fill in publication_question of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, publication|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  publication_ques_id = organization.profile_questions.select{|ques| ques.publication?}.first.id
  publication_array = publication.split(',')
  find("#edit_publication_#{publication_ques_id} .title").set("#{publication_array[0]}")
  find("#edit_publication_#{publication_ques_id} .publisher").set("#{publication_array[1]}")
  find("#edit_publication_#{publication_ques_id} .authors").set("#{publication_array[2]}")

end

When /^I fill in publication_question of "([^"]*)":"([^"]*)" with title "([^"]*)" and date "([^"]*)"$/ do |subdomain, prog_root, title, date|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  publication_ques_id = organization.profile_questions.select{|ques| ques.publication?}.first.id
  date_array = date.split(',')
  find("#edit_publication_#{publication_ques_id} .title").set("#{title}")
  select(date_array[0], from: find("#edit_publication_#{publication_ques_id} .publication_day")[:name]) if date_array[0].present?
  select(date_array[1], from: find("#edit_publication_#{publication_ques_id} .publication_month")[:name]) if date_array[1].present?
  select(date_array[2], from: find("#edit_publication_#{publication_ques_id} .publication_year")[:name]) if date_array[2].present?
end

When /^I fill in manager_question of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |subdomain, prog_root, manager|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  manager_ques_id = organization.profile_questions.select{|ques| ques.manager?}.first.id
  manager_array = manager.split(',')
  steps %{
    And I fill in "profile_answers_#{manager_ques_id}_new_manager_attributes__first_name" with "#{manager_array[0]}"
    And I fill in "profile_answers_#{manager_ques_id}_new_manager_attributes__last_name" with "#{manager_array[1]}"
    And I fill in "profile_answers_#{manager_ques_id}_new_manager_attributes__email" with "#{manager_array[2]}"
  }
end

And /^I search/ do
  page.execute_script(%Q[jQuery(".search_container").first().submit();])
  step "I should see \"Search results for mental\""
end

Then /I view my profile/ do
  step "I click on profile picture and click \"View Profile\""
end

Given /^I hover over "([^"]*)"$/ do |arg1|
  page.execute_script(%Q[jQuery("##{arg1}").first().mouseover();])
end

Given /^I hover over class "([^"]*)"$/ do |arg1|
  page.execute_script(%Q[jQuery(".#{arg1}").first().mouseover();])
end

Then /^I hover over class "([^\"]*)" with text "([^\"]*)" and should see tooltip$/ do |class_name, text|
  page.execute_script(%Q[jQuery(".#{class_name}:contains('#{text}')").mouseover();])
  within ".tooltip" do
    step "I should see \"#{text}\""
  end
end

Given /^I hover over visible class "([^"]*)"$/ do |arg1|
  page.execute_script(%Q[jQuery(".#{arg1}:visible").first().mouseover();])
end

When /^I hover and click AdminTourIcon/ do
  steps %{
    When I hover over "cjs-admin-take-tour"
    Then I should see "Click here for a quick tour"
    And I click "#cjs-admin-take-tour"
  }
end

And /^I hover over "([^\"]*)" and should see "([^\"]*)"$/ do|id,text|
  steps %{
    When I hover over "#{id}"
    Then I should see "#{text}"
  }
end

Then /^I hover over link with title "([^\"]*)"$/ do |link_title|
  page.execute_script(%Q[jQuery("a[title = '#{link_title}']").first().mouseover();])
end

Then /^I hover over link with text "([^\"]*)"$/ do |link_title|
  page.execute_script(%Q[jQuery("a:contains(\'#{link_title}\')").first().mouseover();])
end

Then /^I hover over link with text "([^\"]*)" in the side pane$/ do |link_title|
  page.execute_script(%Q[jQuery("#sidebarRight").find("a:contains(\'#{link_title}\')").first().mouseover();])
end

Then /^I hover over "([^\"]*)" action within "([^\"]*)"$/ do |action, selector|
  within(selector) do
    step "I hover over link with text \"#{action}\""
  end
end

And /^I click on profile picture and click "([^\"]*)"$/ do |action|
  steps %{
    Then I click on profile picture
    And I follow "#{action}" within ".cjs-profile-actions"
  }
end

And /^I click on profile picture$/ do
  page.execute_script %Q[jQuery(".profile_header_image").click();]
end

And /^I click on profile picture and see "([^\"]*)"$/ do |action|
  steps %{
    Then I click on profile picture
    And I should see "#{action}" within ".cjs-profile-actions"
  }
end

When /^(?:|I )should see "([^\"]*)" attribute for profile picture matches with "([^\"]*)"$/ do |attribute, match_string|
  xpath = "//a[contains(@class,'profile_header_image')]/descendant::*[contains(@class,'img-circle')]"
  assert_match match_string, page.find(:xpath, xpath)[attribute.to_sym]
end

Then /^I hover over signature widget$/ do
  page.execute_script(%Q[jQuery("span:contains('widget_signature')").first().mouseover();])
end

Then /^I scroll down by "([^\"]*)"$/ do |pixels|
  page.execute_script(%Q[window.scrollBy(0,#{pixels});])
end

Given /^I click on "([^"]*)" for the group "([^"]*)"$/ do |link_id, group_id|
  page.execute_script %Q[jQuery("##{group_id} div.btn-group").find('ul.dropdown-menu').first().show();]
  page.execute_script %Q[jQuery("##{link_id}").click();]
end

Given /^I follow "([^"]*)" for the group "([^"]*)"$/ do |link_text, group_id|
  page.execute_script %Q[jQuery("##{group_id} div.btn-group").find('ul.dropdown-menu').first().show();]
  step "I follow \"#{link_text}\""
end

When /^(?:|I )follow "([^"]*)" under dropdown$/ do |link|
  within('div.btn-group') do
    page.execute_script("jQuery('div.btn-group').find('ul.dropdown-menu').first().show()")
    step "I follow \"#{link}\""
  end
end

Given /^withdraw mentor request feature enabled for "([^"]*)"$/ do |root_name|
  program = Program.find_by(root: root_name)
  program.update_attribute('allow_mentee_withdraw_mentor_request', true)
end

And /I have a connection associated with bulk match/ do
  p = Program.find_by(root: "albers")
  g = p.groups.first
  g.bulk_match = p.bulk_matches.first
  g.save!
end

Then /^I follow "([^\"]*)" in the bulk actions$/ do |action|
  within "div.bulk_actions_bar" do
    steps %{
      And I follow "Actions"
      And I follow "#{action}"
    }
  end
end

Then /^I follow "([^\"]*)" in moderate posts$/ do |action|
  within "#SidebarRightHomeContent" do
    within "div.btn-group" do
      steps %{
        And I click ".dropdown-toggle"
        And I follow "#{action}"
      }
    end
  end
end

Then /^I should not see element with id "([^"]*)"$/ do |id|
  assert_false page.all("##{id}").any?
end

Then /^I should( not)? see element "([^"]*)"$/ do |negate, element|
  if negate
    assert_false page.all("#{element}").any?
  else
    assert page.all("#{element}").any?
  end
end

Then /^"([^\"]*)" not confirmed terms and conditions$/ do |member|
  m = Member.find_by(email: member)
  assert !!m, "member with email=#{member} should exists"
  m.update_attribute(:terms_and_conditions_accepted, nil)
end

When /^I visit "([^\"]*)" T&C page$/ do |member|
  m = Member.find_by(email: member)
  assert !!m, "member with email=#{member} should exists"
  visit "/registrations/terms_and_conditions_warning"
end

When(/I should get a xls file/) do
  assert page.response_headers['Content-Type'].should == 'application/excel'
end

When(/I should get a csv file/) do

  assert page.response_headers['Content-Type'].should == "text/csv; charset=iso-8859-1; header=present", :driver => :webkit
end

Then /^I should see "([^"]*)" selected from "([^"]*)"$/ do |value, attribute|
  assert_equal value, find("#{attribute} option[selected]").text
end

And /^I suspend "([^\"]*)"$/ do |email|
  member = Member.where(email: email).first
  member.users.each do |user|
    user.suspend_from_program!(user.program.admin_users.first, "Not really good")
  end
end

And /^I set mentoring mode of "([^\"]*)" to ongoing$/ do |email|
  member = Member.where(email: email).first
  member.users.each do |user|
    user.mentoring_mode = User::MentoringMode::ONGOING
    user.save!
    program = user.program
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    program.allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    program.save!
  end
end

And /^I set mentoring mode of "([^\"]*)" to one time$/ do |email|
  member = Member.where(email: email).first
  member.users.each do |user|
    user.mentoring_mode = User::MentoringMode::ONE_TIME
    user.save!
    program = user.program
    program.enable_feature(FeatureName::CALENDAR, true)
    program.allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    program.save!
  end
end


Given /^I click on "([^\"]*)" in Actions$/ do |action|
  page.execute_script %Q[jQuery("div#page_canvas div.btn-group").find('ul.dropdown-menu').first().show();]
  page.execute_script %Q[jQuery("##{action}").first().click();]
end

Given /^I click on the individual offer "([^\"]*)" in Actions$/ do |action|
  offer_id = MentorOffer.last.id
  page.execute_script("jQuery('div#mentor_offer_#{offer_id} div.btn-group').find('ul.dropdown-menu').first().show();")
  step "I follow \"Send Message to Sender\""
end

Given /^I click on class "([^\"]*)" in Actions$/ do |action|
  page.execute_script %Q[jQuery("div#page_canvas div.btn-group").find('ul.dropdown-menu').first().show();]
  page.execute_script %Q[jQuery(".#{action}").first().click();]
end

Then /^I hide the Actions$/ do
  page.execute_script %Q[jQuery("div#page_canvas div.btn-group").find('ul.dropdown-menu').first().hide();]
end


When /^I follow "([^\"]*)" for email "([^\"]*)"$/ do |link, email|
  user_id = Member.find_by(email: email).users.first.id
  step "I follow \"#{link}_#{user_id}\""
end

And /^I should( not)? see "([^\"]*)" under Select a mentor$/ do |negate,name|
  within('.selector') do
    expectation = negate ? "should not" : "should"
    step "I #{expectation} see \"#{name}\""
  end
end

When /^I enter autocomplete with "([^\"]*)"$/ do |entered_text|
  steps %{
    When I click "#s2id_user_tag_list > .select2-choices"
    And I click on select2 result "#{entered_text}"
  }
end

When /^I enter "([^\"]*)" in "([^\"]*)" autocomplete it with "([^\"]*)"$/ do |entered_text,id_selector,chosen_text|
  steps %{
    And I fill in "#{id_selector}" with "#{entered_text}"
    Then I wait for ajax to complete
    Then I should see "#{chosen_text}"
  }
  page.execute_script("jQuery('.auto_complete li:contains(\"#{chosen_text}\")').trigger('mouseenter').click()")
end

Given /^I fill in "([^"]*)" field of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |role_name, organization_subdomain, program_root, content|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  dom_selector = "#group_members_role_id_#{role.id}"
  page.execute_script("jQuery('#{dom_selector}').first().val('#{content}')")
end

Given /^I enable "([^\"]*)" feature that was removed from UI as super user of "([^\"]*)":"([^\"]*)"$/ do |feature_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  program.enable_feature(feature_name, true)
  if feature_name == "offer_mentoring"
    program.update_attribute(:mentor_offer_needs_acceptance, true)
  end
end

And /^I disable calendar feature that was removed from UI as super user of "([^\"]*)":"([^\"]*)"$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  program.enable_feature(FeatureName::CALENDAR, false)
end

Then /^I should see "([^\"]*)" selected$/ do |option|
  assert page.evaluate_script("jQuery(\"#{option}\").is(':checked')")
end

Then /^I hover over my profile$/ do
  step "I hover over \"my_profile\""
end

And /^I should not see page actions$/ do
  #assert !page.has_css?("#title_actions")
  assert_false page.all("#title_actions").any?
end

When /^I click on the hamburger icon$/ do
  step "I click by xpath \"//a[contains(@class, 'navbar-minimalize')]\""
end

Then /^I click on the "([^\"]*)" icon$/ do |icon_name|
  page.execute_script %Q[jQuery("[class*=\'#{icon_name}\']").first().click();]
end

Then /^I click on the image "([^\"]*)"$/ do |img_name|
  page.execute_script %Q[jQuery("img[alt=\'#{img_name}\']").first().click();]
end

Then /^I click on the image with src "([^\"]*)"$/ do |img_src|
  find("img[src=\'#{img_src}\']", match: :prefer_exact).hover.click
end

Then /^I should see the image with src "(.*?)"$/ do |img_src|
  find("img[src=\'#{img_src}\']", match: :prefer_exact)
end

When /^I refresh the page$/ do
  refresh_page
end

Then /^I hover over "([^"]*)" icon$/ do |icon_name|
  step "I hover over class \"fa-#{icon_name}\""
end

Then /^I list all the programs$/ do
  step "I dismiss announcement modal"
  step "I click \".my_programs_listing_link\""
end

Then /^I wait for remote Modal to be hidden$/ do
  assert page.has_css?("#remoteModal", visible: false)
end

Then /^I should scroll by "([^\"]*)"$/ do |value|
  value = value.to_i
  page.execute_script "window.scrollBy(0, #{value})"
end

Then /^I wait for "([^\"]*)" seconds?$/ do |arg1|
  sleep arg1.to_i
end

Then /^I choose "([^\"]*)" in autocomplete$/ do |arg1|
  page.execute_script("jQuery('.auto_complete li:contains(\"#{arg1}\")').trigger('mouseenter').click()")
end 

Then /^I stub "(.*?)" for "(.*?)" as "(.*?)" value "(.*?)"$/ do |field, model, convert_to_type, value|
  method_map = { integer: :to_i, boolean: :to_boolean }
  convert_to_type = method_map[convert_to_type.strip.to_sym]
  model.constantize.any_instance.stubs(field.to_sym).returns(convert_to_type ? value.send(convert_to_type) : value)
end

Then /^admin update role permission "(.*?)" for "(.*?)" to "(.*?)" for program with name "(.*?)"$/ do |permission_name, role1_name, value, program_name|
  program = Program.find_by(name: program_name)
  role1 = program.roles.where(name: role1_name).first
  permission = Permission.where(name: permission_name).first
  role_permission = role1.role_permissions.where(permission_id: permission.id).first
  role_permission.destroy if role_permission.present? if (value == "false")
end

private

def str2setting(str)
  case str
  when "all"; UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
  when "aggregate"; UserConstants::DigestV2Setting::ProgramUpdates::DAILY
  end
end

def metoringmodestr2setting(str)
  case str
  when "ongoing"; User::MentoringMode::ONGOING
  when "one_time"; User::MentoringMode::ONE_TIME
  when "both"; User::MentoringMode::ONE_TIME_AND_ONGOING
  end
end

def current_program
  controller.instance_eval("current_program")
end

def get_program(prog_root, subdomain, domain = DEFAULT_HOST_NAME)
  org = get_organization(subdomain, domain)
  org.programs.find_by(root: prog_root)
end

def get_organization(subdomain, domain = DEFAULT_HOST_NAME)
   Program::Domain.get_organization(domain, subdomain)
end

def refresh_page
  case Capybara::current_driver
  when :selenium
    visit page.driver.browser.current_url
  when :racktest
    visit [ current_path, page.driver.last_request.env['QUERY_STRING'] ].reject(&:blank?).join('?')
  when :culerity
    page.driver.browser.refresh
  else
    raise "unsupported driver, use rack::test or selenium/webdriver"
  end
end

def remote_file_detection(file_path)
   driver = page.driver.browser
   driver.file_detector = lambda do |file_path|
     str = file_path.first.to_s
     str if File.exist?(str)
   end
end
