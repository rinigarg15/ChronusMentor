Then /^I close the meeting request by notifying the sender and recipient$/ do
  steps %{
    And I follow "Close Request"
    And I fill in "bulk_actions_reason" with "admin close request"
    And I check "sender"
    And I check "recipient"
    And I press "Close Request"
  }
end

Then /^I bulk close the meeting requests$/ do
  steps %{
    And I check "cjs_primary_checkbox"
    And I follow "Actions"
    And I follow "Close Requests"
    And I fill in "bulk_actions_reason" with "admin close request"
    And I check "sender"
    And I check "recipient"
    And I press "Close Requests"
  }
end