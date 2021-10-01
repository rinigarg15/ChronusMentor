Given /^coaching_goals is enabled for "([^\"]*)":"([^\"]*)"$/ do |arg1, arg2|
  o = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,arg1)
  prog = o.programs.find_by(root: arg2)
  prog.enable_feature(FeatureName::COACHING_GOALS)
end

And /^I fill in "([^\"]*)" with a date 30 days from now$/ do |text_field_id|
  page.execute_script("jQuery(\"#{text_field_id}\").val(\"#{formatted_time_in_words((Time.now + 30.days))}\")")
end

Then /^I set progress value to "([^\"]*)"$/ do |value|
  page.execute_script("jQuery('#progress_slider').val('#{value}');")
end

