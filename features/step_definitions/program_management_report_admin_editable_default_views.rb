And /^I check if the filters are editable$/ do
  steps %{
    And I should see "Roles & Status"
    And I should see "Active"
    And I should see "Deactivated"
    Then I check "admin_view_roles_and_status_state_active"
    Then I check "admin_view_roles_and_status_signup_state_added_not_signed_up_users"
    And I click on the section with header "Matching & Engagement status"
    And I should see "Matching & Engagement status"
    And I click on the section with header "Matching & Engagement status"
    And I should see "Mentor Availability"
    And I should see "Profile"
    And I click on the section with header "Profile"
    And I should see "Profile Questions"
    And I should see "Profile Completeness Score"
    And I should see "Timeline"
    And I click on the section with header "Timeline"
  }
end

And /^I check if the filters are editable for mentee view$/ do
  steps %{
    And I should see "Roles & Status"
    And I should see "Active"
    And I should see "Deactivated"
    Then I check "admin_view_roles_and_status_state_active"
    Then I check "admin_view_roles_and_status_signup_state_added_not_signed_up_users"
    And I click on the section with header "Matching & Engagement status"
    And I should see "Matching & Engagement status"
    And I click on the section with header "Matching & Engagement status"
    And I should see "Profile"
    And I click on the section with header "Profile"
    And I should see "Profile Questions"
    And I should see "Profile Completeness Score"
    And I should see "Timeline"
    And I click on the section with header "Timeline"
  }
end

And /^I check if the filters are uneditable$/ do
  steps %{
    And I should see "Roles"
    And I should not see "Roles & Status"
    And I should not see "User Status"
    And I should not see "Matching & Engagement status"
  }
end