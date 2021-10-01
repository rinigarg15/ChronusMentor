Then /^I should see "([^\"]*)" users listed$/ do |n|
  within "#results_pane" do
    assert page.has_css?('.list_item', :count => n.to_i)
  end
end

And /^the text field "([^\"]*)" in "([^\"]*)" should have value "([^\"]*)"$/ do |id, inside, val|
  within inside do
    page.has_field?(id, :with => val)
  end
end

And /^I press browser back$/ do
  page.evaluate_script('window.history.back()')
end

And /^the div "([^\"]*)" should have the link with title "([^\"]*)"$/ do |div_id, link_title|
  within div_id do
    page.has_link?(link_title)
  end
end

And /^the div "([^\"]*)" should not have the link with title "([^\"]*)"$/ do |div_id, link_title|
  within div_id do
    page.has_no_link?(link_title)
  end
end