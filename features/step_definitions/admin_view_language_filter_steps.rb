Then /^I add language column$/ do
  page.execute_script('jQuery("div.option-element:contains(Language)").eq(0).click()')
end

Then /^I sort on language column$/ do
  page.execute_script('jQuery("a.k-link:contains(Language)").click()')
end

Then /^I clear filter for language$/ do
  page.execute_script("jQuery('th:contains(Language) a.k-grid-filter').click()")
  page.execute_script("jQuery('.k-dropdown-wrap').click()")
  page.execute_script("jQuery('button.k-button:contains(Clear)').click()")
end

Then /^I toggle language selection for "([^"]*)"$/ do |language|
  page.execute_script("jQuery('label:contains(#{language})').click()")
end

Then /^I apply filter for language "([^"]*)"$/ do |title|
  language = Language.find_by(title: title)
  page.execute_script("jQuery('th:contains(Language) a.k-grid-filter').click()")
  page.execute_script("jQuery('form.k-filter-menu input[value=#{language.id}]').click()")
  page.execute_script("jQuery('button.k-button:contains(Filter)').click()")
end