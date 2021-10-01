When /^I fill the term for "([^"]*)" with "([^"]*)"$/ do |term_name, value|
  term_div = page.find("div.cui_edit_name", text: term_name)
  within(term_div) do
    step "I fill in \"Base Term\" with \"#{value}\""
  end
end

Then /^the term for "([^"]*)" should be "([^"]*)"$/ do |term_name, value|
  page.find("div.cui_edit_name", text: term_name).find("input[value='#{value}']")
end
