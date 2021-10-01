Then /^I enable the option for users to leave mentoring connection$/ do
  steps %{
    Then I follow "Manage"
    And I follow "Program Settings"
    Then I follow "Connection Settings"
  }
  choose("program_allow_users_to_leave_connection_true")
  steps %{
    And I press "Save"
    Then I should see "Your changes have been saved"
  }
end