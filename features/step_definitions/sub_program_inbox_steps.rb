When /^I set subject to "([^\"]*)" and content to "([^\"]*)"$/ do |arg1, arg2|
  steps %{
    And I fill in "message_subject" with "#{arg1}"
    And I fill in "message_content" with "#{arg2}"
  }
end
