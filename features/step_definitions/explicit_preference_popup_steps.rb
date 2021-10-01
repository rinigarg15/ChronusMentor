Then /^I click on select2 with selector "([^\"]*)" inside "([^\"]*)"$/ do |selector, container|
  page.execute_script("jQuery('#{container}').find('#{selector}').select2('open');")
end

Then /^I change weight slider inside "([^\"]*)" to "([^\"]*)"$/ do |container, value|
  page.execute_script("jQuery('#{container}').find('.cjs_explicit_preference_weight_selector').slider('value', #{value});")
end

Then /^I click on option selector of last preference$/ do
  explicit_preference_id = ExplicitUserPreference.last.id
  steps %{
    Then I click on select2 with selector ".cjs_explicit_preference_option_selector" inside ".cjs_explicit_preference_#{explicit_preference_id}"
  }
end

Then /^I change weight of last preference to "([^\"]*)"$/ do |value|
  explicit_preference_id = ExplicitUserPreference.last.id
  steps %{
    Then I change weight slider inside ".cjs_explicit_preference_#{explicit_preference_id}" to "#{value}"
  }
end

Then /^I click "([^\"]*)" of last preference$/ do |selector|
  explicit_preference_id = ExplicitUserPreference.last.id
  steps %{
    Then I click "#{selector}" within ".cjs_explicit_preference_#{explicit_preference_id}"
  }
end

Then /^I unselect all options of last preference$/ do
  explicit_preference_id = ExplicitUserPreference.last.id
  steps %{
    Then I click "a.select2-search-choice-close" within ".cjs_explicit_preference_#{explicit_preference_id}"
  }
end

Then /^I should see "([^\"]*)" inside last preference edit container$/ do |text|
  explicit_preference_id = ExplicitUserPreference.last.id
  steps %{
    Then I should see "#{text}" within ".cjs_explicit_preference_#{explicit_preference_id} .cjs_explicit_preference_inline_update"
  }
end

Then /^I should not see "([^\"]*)" inside last preference edit container$/ do |text|
  explicit_preference_id = ExplicitUserPreference.last.id
  steps %{
    Then I should not see "#{text}" within ".cjs_explicit_preference_#{explicit_preference_id} .cjs_explicit_preference_inline_update"
  }
end