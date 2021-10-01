# encoding: utf-8
# TL;DR: YOU SHOULD DELETE THIS FILE
#
# This file was generated by Cucumber-Rails and is only here to get you a head start
# These step definitions are thin wrappers around the Capybara/Webrat API that lets you
# visit pages, interact with widgets and make assertions about page content.
#
# If you use these step definitions as basis for your features you will quickly end up
# with features that are:
#
# * Hard to maintain
# * Verbose to read
#
# A much better approach is to write your own higher level step definitions, following
# the advice in the following blog posts:
#
# * http://benmabey.com/2008/05/19/imperative-vs-declarative-scenarios-in-user-stories.html
# * http://dannorth.net/2011/01/31/whose-domain-is-it-anyway/
# * http://elabs.se/blog/15-you-re-cuking-it-wrong
#


require 'uri'
require 'cgi'
require File.expand_path(File.join(File.dirname(__FILE__), "..", "support", "paths"))
require File.expand_path(File.join(File.dirname(__FILE__), "..", "support", "selectors"))

module WithinHelpers
  def with_scope(locator)
    locator ? within(*selector_for(locator) , :match => :prefer_exact) { yield } : yield
  end
  # Rails 3.2.13 bug (json 1.7.7). Temporary, until JSON will be fixed.
  def clear_utf_symbols(string)
    string.gsub(/[»«]/, '')
  end
end
World(WithinHelpers)

# Single-line step scoper
When /^(.*) within (.*[^:])$/ do |step_definition, parent|
  with_scope(parent) { step step_definition }
end

# Multi-line step scoper
When /^(.*) within (.*[^:]):$/ do |step, parent, table_or_string|
  with_scope(parent) { When "#{step}:", table_or_string }
end

Given /^(?:|I )am on (.+)$/ do |page_name|
  visit path_to(page_name)
end

When /^(?:|I )go to (.+)$/ do |page_name|
  visit path_to(page_name)
end

When /^I go back$/ do
  visit page.evaluate_script('document.referrer')
end

Then /^I click on input by value "([^\"]*)"$/ do |text_value|
  page.find("input[value=\"#{text_value}\"]").click
end

When /^(?:|I )press "([^\"]*)"$/ do |button|
  # clear_utf_symbols - Rails 3.2.13 bug (json 1.7.7). Temporary, until JSON will be fixed.
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  CucumberWait.retry_until_element_is_visible { click_button(clear_utf_symbols(button), :match => :prefer_exact, :visible => true) }
end

When /^(?:|I )follow "([^\"]*)"$/ do |link|
  # clear_utf_symbols - Rails 3.2.13 bug (json 1.7.7). Temporary, until JSON will be fixed.
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
    modal = first("#remoteModal")
    if modal.present? && first(".close-link-announcements").present?
      steps %{
        Then I close remote modal
        Then I wait for "1" seconds
      }
    end
  end
    CucumberWait.retry_until_element_is_visible { click_link(clear_utf_symbols(link), :match => :prefer_exact, :visible => true) }
end

When /^(?:|I )should see "([^\"]*)" attribute for link "([^\"]*)" matches with "([^\"]*)"$/ do |attribute, text, match_string|
  assert_match match_string, find_link((clear_utf_symbols(text)), :match => :first)[attribute.to_sym]
end

When /^(?:|I )should see "([^\"]*)" attribute for link with css "([^\"]*)" matches with "([^\"]*)"$/ do |attribute, text, match_string|
  assert_match match_string, page.find(:css, (clear_utf_symbols(text)))[attribute.to_sym]
end

When /^(?:|I )fill in "([^"]*)" with "([^"]*)"$/ do |field, value|
  wait_for_animation
  Capybara.save_page("#{FILE_SAVE_PATH}/#{@scenario_id}_#{@count}.html")
  if Capybara.current_driver == Capybara.javascript_driver
    Capybara.save_screenshot("#{FILE_SAVE_PATH}/#{@scenario_id}_#{@count}.png")
  end
  @count = @count+1
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  wait_for_animation
  CucumberWait.retry_until_element_is_visible { fill_in(field, :with => value, :match => :prefer_exact, :visible => true) }
end

When /^(?:|I )fill in by css "([^"]*)" with "([^"]*)"$/ do |field, value|
  wait_for_animation
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  wait_for_animation
  CucumberWait.retry_until_element_is_visible { find("##{field}", :match => :prefer_exact, :visible => true).set(value) }
end

When /^(?:|I )lookup for "([^"]*)" in "([^"]*)"$/ do |value, field|
  step %{I fill in "#{field}" with "#{value}"}
  step %{I press enter in "#{field}"}
end

When /^(?:|I )click "([^"]*)" tab in dropdown menu$/ do |link|
  page.execute_script %Q[jQuery('#sub_title_navig').find('ul.dropdown-menu').show();]
  step %{I click on the ibox dropdown action}
  step %{I follow "#{link}"}
end

When /^(?:|I )fill in CKEditor "([^"]*)" with "([^"]*)"$/ do |field, value|
  content = value.to_json
  browser = page.driver.browser
  step "I wait for \"2\" seconds"
  if browser.respond_to?(:execute_script)
    browser.execute_script %{
      CKEDITOR.instances["#{field}"].setData(#{content});
      jQuery("textarea##{field}").first().text(#{content});
    }
  else
    CucumberWait.retry_until_element_is_visible { fill_in(field, :with => value) }
  end
end

When /^I fill in a number field "([^"]*)" with "([^"]*)"$/ do |selector, value|
  content = value.to_json
  page.driver.browser.execute_script %{
    jQuery("#{selector}").first().val(#{content});
  }
end

When /^(?:|I )fill in "([^"]*)" with file "([^"]*)"$/ do |field, filename|
  file_path = Rails.root.to_s + "/test/fixtures/#{filename}"
  if ENV['BS_RUN'] == 'true'
   remote_file_detection(file_path)
  end  
  page.attach_file(field, file_path, visible: false)
end

# Use this to fill in an entire form with data from a table. Example:
#
#   When I fill in the following:
#     | Account Number | 5002       |
#     | Expiry date    | 2009-11-01 |
#     | Note           | Nice guy   |
#     | Wants Email?   |            |
#
# TODO: Add support for checkbox, select og option
# based on naming conventions.
#
When /^(?:|I )fill in the following:$/ do |fields|
  fields.rows_hash.each do |name, value|
    step %{I fill in "#{name}" with "#{value}"}
  end
end

When /^(?:|I )select "([^"]*)" from "([^"]*)"$/ do |value, field|
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  select(value, :from => field,:match=>:prefer_exact, :visible => true)
end

When /^(?:|I )unselect "([^"]*)" from "([^"]*)"$/ do |value, field|
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  #CucumberWait.retry_until_element_is_visible { unselect(field, :match => :prefer_exact, :visible => true) }
  remove_from_select2(value)
end


When /^(?:|I )check "([^"]*)"$/ do |field|
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  CucumberWait.retry_until_element_is_visible { check(field, :match => :prefer_exact, :visible => true) }
end

When /^(?:|I )uncheck "([^"]*)"$/ do |field|
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  CucumberWait.retry_until_element_is_visible { uncheck(field, :match => :prefer_exact, :visible => true) }
end

When /^(?:|I )choose "([^"]*)"$/ do |field|
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  CucumberWait.retry_until_element_is_visible { choose(field, :match => :prefer_exact, :visible => true) }
end

When /^(?:|I )attach the file "([^"]*)" to "([^"]*)"$/ do |path, field|
  attach_file(field, File.expand_path(path))
end

Then /^(?:|I )should see "([^"]*)"$/ do |text|
  wait_for_animation
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  text = clear_utf_symbols(text) # clear_utf_symbols - Rails 3.2.13 bug (json 1.7.7). Temporary, until JSON will be fixed.
  if page.respond_to? :should
    page.should have_content(text, wait: 60)
  else
    assert page.has_content?(text)
  end
end

Then /^I in "([^"]*)" seconds should see "([^"]*)"$/ do |wait_time, text|
  text = clear_utf_symbols(text)
  wait_time = wait_time.to_i
  page.should have_content(text, wait: wait_time)
end

Then /^(?:|I )should see \/([^\/]*)\/$/ do |regexp|
  regexp = Regexp.new(regexp)
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  if page.respond_to? :should
    page.should have_xpath('//*', :text => regexp)
  else
    assert page.has_xpath?('//*', :text => regexp)
  end
end

Then /^I set the focus to the main window$/ do
  page.driver.browser.switch_to.window (page.driver.browser.window_handles.first)
end

Then /^(?:|I )should not see "([^"]*)"$/ do |text|
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  if page.respond_to? :should
    #page.should have_no_content(text)
    assert_no_text(:visible, text)
  else
    #assert page.has_no_content?(text)
    assert_no_text(:visible, text)
  end
end

Then /^(?:|I )should not see \/([^\/]*)\/$/ do |regexp|
  regexp = Regexp.new(regexp)
  if (ENV['AXE_RUN'] == 'true')
    @skip_afterstep_hook = true
  end
  if page.respond_to? :should
    page.should have_no_xpath('//*', :text => regexp)
  else
    assert page.has_no_xpath?('//*', :text => regexp)
  end
end

Then /^the( disabled)? "([^"]*)" field(?: within (.*))? should contain "([^"]*)"$/ do |field_disabled, field, parent, value|
  with_scope(parent) do
    field = find_field(field, disabled: (!field_disabled.nil?))
    field_value = (field.tag_name == 'textarea') ? field.text : field.value
    if field_value.respond_to? :should
      field_value.should =~ /#{value}/
    else
      assert_match(/#{value}/, field_value)
    end
  end
end

Then /^the "([^"]*)" field(?: within (.*))? should not contain "([^"]*)"$/ do |field, parent, value|
  with_scope(parent) do
    field = find_field(field)
    field_value = (field.tag_name == 'textarea') ? field.text : field.value
    if field_value.respond_to? :should_not
      field_value.should_not =~ /#{value}/
    else
      assert_no_match(/#{value}/, field_value)
    end
  end
end

Then /^the "([^"]*)" checkbox(?: within (.*))? should be checked$/ do |label, parent|
  with_scope(parent) do
    field_checked = find_field(label)['checked']
    if field_checked.respond_to? :should
      field_checked.should be_true
    else
      assert field_checked
    end
  end
end

Then /^I scroll and click the element "([^\"]*)" below my visibility$/ do |field|
  page.driver.execute_script("arguments[0].scrollIntoView(true)", first("#{field}").native)
  step "I click \"#{field}\""
end

Then /^the "([^"]*)" checkbox(?: within (.*))? should not be checked$/ do |label, parent|
  with_scope(parent) do
    field_checked = find_field(label)['unchecked']
    if field_checked.respond_to? :should
      field_checked.should be_false
    else
      assert !field_checked
    end
  end
end

Then /^(?:|I )should be on (.+)$/ do |page_name|
  current_path = URI.parse(current_url).path
  if current_path.respond_to? :should
    current_path.should == path_to(page_name)
  else
    assert_equal path_to(page_name), current_path
  end
end

Then /^(?:|I )should have the following query string:$/ do |expected_pairs|
  query = URI.parse(current_url).query
  actual_params = query ? CGI.parse(query) : {}
  expected_params = {}
  expected_pairs.rows_hash.each_pair{|k,v| expected_params[k] = v.split(',')}

  if actual_params.respond_to? :should
    actual_params.should == expected_params
  else
    assert_equal expected_params, actual_params
  end
end

Then /^show me the page$/ do
  save_and_open_page
end

# Added by Mrudhukar(Chronus Mentor)
When /^I confirm popup$/ do
  CucumberWait.retry_until_element_is_visible { find(:css, 'div.sweet-alert.showSweetAlert.visible div.sa-confirm-button-container>.confirm').click }
end

When /^I cancel popup$/ do
  CucumberWait.retry_until_element_is_visible { find(:css, 'div.sweet-alert.showSweetAlert.visible div.sa-button-container>.cancel').click }
end

Then /^I cancel modal$/ do
  CucumberWait.retry_until_element_is_visible { find(:css, '.modal.in .btn.btn-white', :text => 'Cancel').click }
end

Then /^I confirm modal$/ do
  CucumberWait.retry_until_element_is_visible { page.execute_script %Q[jQuery(".modal.in .btn.btn-primary[type=submit]").click();] }
end

Then /^I close modal$/ do
    CucumberWait.retry_until_element_is_visible { find(:css, '.modal.fade.in .close.cjs-web-modal-cancel').click }
end

Then /^I ok alert$/ do
  page.execute_script %Q[jQuery('div.ui-dialog-buttonpane button.ui-button').click();]
end

When /^I follow link "([^\"]*)"$/ do |element|
  page.execute_script %Q[jQuery('#{element} a')[0].click();]
end

When /^I follow the link "([^\"]*)"$/ do |element|
  page.execute_script %Q[jQuery('#{element} a').click();]
end

Then /^I trigger change event on "([^\"]*)"$/ do |element|
  if (ENV['BS_RUN'] == 'true')
    page.execute_script %Q[jQuery("##{element}").focus()];
    page.execute_script %Q[jQuery("##{element}").trigger('change')];
  end
end

Then /^I trigger change event on "([^\"]*)" without browserstack$/ do |element|
  page.execute_script %Q[jQuery("##{element}").trigger('change')];
end

When /^I click "([^\"]*)"$/ do |arg1|
  if Capybara.current_driver == Capybara.javascript_driver
    page.driver.browser.switch_to.window (page.driver.browser.window_handles.last)
  end
  CucumberWait.retry_until_element_is_visible { find(:css, arg1, :match => :first, :visible => true).click }
end

Then /^I click the button with selector "([^\"]*)"$/ do |id|
    page.execute_script("jQuery('#{id}').click()");
end

Then /^"([^\"]*)" should( not)? be disabled$/ do |label, negate|
  field_disabled = find_field(label)['disabled']
  if field_disabled.respond_to? :should
    field_disabled.should be_true
  else
    assert field_disabled
  end
end

Then /^"([^\"]*)" should not be visible$/ do |id|
  assert page.evaluate_script("jQuery('#{id}').is(':hidden')")
end

Then /^"([^\"]*)" should be visible$/ do |id|
  assert_false page.evaluate_script("jQuery('#{id}').is(':hidden')")
end

Then /^I should see image "([^\"]*)"$/ do |image|
  assert_equal 1, page.evaluate_script(%{jQuery("img[src*='#{image}']").length})
end

Then /^I should see icon "([^\"]*)"$/ do |icon|
  assert_equal 1, page.evaluate_script(%{jQuery("i[class*='#{icon}']").length})
end

And /^I select "([^\"]*)" for "([^\"]*)" from datepicker$/ do |date, element|
  page.execute_script("jQuery('#{element}').data('kendoDatePicker').value('#{date}')")
  page.execute_script("jQuery('#{element}').data('kendoDatePicker').trigger('change')")
end

And /^I fill in the date range picker with "([^"]*)" and "([^"]*)"$/ do |start_date, end_date|
  steps %{
    And I select "#{start_date}" for ".cjs_daterange_picker_start" from datepicker
    And I select "#{end_date}" for ".cjs_daterange_picker_end" from datepicker
  }
end

Then /^I wait for ajax to complete$/ do
  Capybara.default_max_wait_time = 30
  wait_for_ajax
  wait_for_animation
  Capybara.default_max_wait_time = 20
end

Then /^I wait for upload to complete$/ do
  Capybara.default_max_wait_time = 100
  wait_for_ajax
  wait_for_animation
  Capybara.default_max_wait_time = 20
end

Then /^I wait for download to complete$/ do
  wait_for_download
end

And /^I click by xpath "([^\"]*)"$/ do |selector|
  find(:xpath, selector, visible: true, match: :first).click
end

When /^I click on select2 result "([^\"]*)"$/ do |text|
  page.find(".select2-drop-active").find(".select2-result-label", text: text).click
end

Then /^I close all open select2 dropdowns$/ do
  page.execute_script("jQuery('.select2-container').each(function(){jQuery(this).select2('close');})")
end

And /^I fill xpath "([^\"]*)" with "([^\"]*)"$/ do |xpath,value|
  find(:xpath,xpath,match: :first).set(value)
end

Then /^page should not have css "([^\"]*)"$/ do |id|
  #assert !page.has_css?("##{id}")
  assert_false page.all("##{id}").any?
end

Then /^I choose radio button with label "([^\"]*)"$/ do |label|
  page.find('label', :text => "#{label}").click
end

Then /^I choose radio button with id "([^\"]*)"$/ do |id|
  page.execute_script("jQuery('input##{id}').click()");
end

When /^I press_enter for xpath "([^\"]*)"$/ do |xpath|
  find(:xpath,xpath,match: :first).native.send_keys(:return)
end

Then /^I wait for animations? to complete$/ do
  wait_for_animation
end

Then /^I scroll to bottom of the page$/ do
  page.execute_script "window.scrollBy(0, 10000)"
end

Then /^I scroll to the top of the page$/ do
  page.execute_script "window.scrollBy(0,-10000)"
end

Then /^I scroll vertically by "([^\"]*)"$/ do |y_axis|
  page.execute_script "window.scrollBy(0, #{y_axis.to_i})"
end

Then /^I scroll to the element "([^\"]*)"$/ do |jquery_selector|
  page.execute_script("jQuery('#{jquery_selector}')[0].scrollIntoView()")
end

Then /^I close select2 dropdown$/ do
  page.execute_script("jQuery('#select2-drop-mask').click()");
end

Then /I navigate to match_configs_path page/ do
  visit match_configs_path(:root => "albers")
end

And /^I close the select2 dropdown$/ do
  page.execute_script(%Q[jQuery("#select2-drop").hide()])
  page.execute_script(%Q[jQuery("#select2-drop-mask").hide()])
end

private

def wait_for_ajax
  Timeout.timeout(Capybara.default_max_wait_time) do
    loop until finished_all_ajax_requests?
  end
end

def finished_all_ajax_requests?
  page.evaluate_script('window.jQuery && jQuery.active').try(:zero?)
end

def downloads
  if ENV['TDDIUM']
    Dir[ DOWNLOAD_PATH+"/*"]
  else
    Dir[DOWNLOAD_PATH.join('*')]
  end
end

def wait_for_download
  Timeout.timeout(30) do
    sleep 1 until downloaded?
  end
end

def downloaded?
  downloads.any? && !downloading?
end

def downloading?
  downloads.grep(/\.pdf\.part$/).any? || downloads.grep(/\.xls\.part$/).any? || downloads.grep(/\.part/).any?
end

def finished_all_animations?
  fadein_length = page.evaluate_script('window.jQuery!= undefined && jQuery(".fade.in").length')
  if fadein_length && (fadein_length > 0)
    fadein_opacity = page.evaluate_script('window.jQuery!= undefined && jQuery(".fade.in:not(.modal-backdrop)").css("opacity")') 
    fadein_opacity == "1" || fadein_opacity == "0.9"
  else
    true
  end
end


def wait_for_animation
  if Capybara.current_driver == Capybara.javascript_driver
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.1 until finished_all_animations?
    end
  else
    true
  end
end