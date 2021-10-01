Then /^I sort by "([^"]*)"$/ do |sort_by|
  page.execute_script %Q[jQuery("th[data-sort-param=\'#{sort_by}\']").first().click();]
end
