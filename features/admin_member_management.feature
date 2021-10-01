Feature: Admin member management

Background: Admin logs in
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"

@javascript 
Scenario: Admin is able to export members in CSV
  Then I follow "Manage"
  And I follow "Member Views"
  #Export to CSV
  Then I check "cjs_admin_view_primary_checkbox"
  # There is no method to use both @javasript and check response-header for file
  # So check just click on 'cjs_export_csv'
  # https://groups.google.com/forum/#!topic/ruby-capybara/xg88j4bvDZM
  And I click on "cjs_export_csv" in Actions

@javascript @cross_browser
Scenario: Admin Bulk Actions
  #Bulk Suspend
  Then I follow "Manage"
  And I follow "Member Views"
  Then I should see "All Members"
  Then I should see "Actions"
  Then I should see "arun"
  Then I add the following users:
    | user |
    | arun@albers.com |
    | assistant@chronus.com |
    | ram@example.com |
 
  Then I follow "Actions"
  Then I follow "Suspend Membership"
  Then I should see "arun albers"
  Then I should see "Assistant User"
  Then I should see "Please note that the members will not be able to participate in any more activities and their membership requests will also be ignored"
  Then I fill in "admin_view_reason" with "You are suspended"
  Then I press "Submit"
  #Org admin cannot be suspended
  Then I should see "Freakin Admin has not been suspended"
  Then I wait for ajax to complete
  #Bulk Reactivate
  Then I add the following users:
    | user |
    | arun@albers.com |
    | assistant@chronus.com |
    | ram@example.com |
  
  Then I follow "Actions"
  Then I follow "Reactivate Membership"
  Then I should see "arun albers"
  Then I should see "Assistant User"
  Then I should see "The membership of the following members will be reactivated"
  Then I press "Submit"
  Then I should see "The selected members have been reactivated"
  Then I wait for ajax to complete
  Then I add the following users:
    | user |
    | arun@albers.com |
    | assistant@chronus.com |
    | ram@example.com |

  Then I remove "ram@example.com" from selection
  Then I follow "Actions"
  Then I follow "Remove Member"
  Then I should see "You are about to remove 2 members from Primary Organization. Did you intend to suspend their membership instead?"
  Then I should see "arun albers"
  Then I should see "Assistant User"
  Then I should see "Removal of members is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from all programs permanently."
  Then I press "Suspend Members"
  Then I wait for ajax to complete
  Then I should see "Please note that the members will not be able to participate in any more activities and their membership requests will also be ignored"
  Then I fill in "admin_view_reason" with "You are suspended"
  Then I press "Submit"
  Then I should see "The selected members have been suspended"
  Then I wait for ajax to complete
  #Bulk Remove
  Then I add the following users:
    | user |
    | arun@albers.com |
    | assistant@chronus.com |
    | ram@example.com |
  
  Then I follow "Actions"
  Then I follow "Remove Member"
  Then I should see "You are about to remove 3 members from Primary Organization."
  Then I should see "Removal of members is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from all programs permanently."
  Then I should see "arun albers"
  Then I should see "Assistant User"
  Then I press "Remove members"
  #Org admin cannot be removed
  Then I should see "Freakin Admin has not been removed"
  Then I wait for ajax to complete
  
  Then I add the following users:
    | user |
    | bdespota@example.com |
    | userram@example.com |
    | mentor_0@example.com |
  
  Then I follow "Actions"
  Then I follow "Remove Member"
  Then I should see "Removal of members is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from all programs permanently."
  Then I press "Remove members"
  Then I should see "The selected users have been removed from Primary Organization"
  Then I logout

