Feature: Admin Changes Program Membership Settings

@javascript @cross_browser
Scenario: Admin changes program membership settings
  Given the current program is "primary":"albers"
  Then I follow "Join"
  Then I should not see "Mentor and Student"
  When I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Membership"
  Then the "join_directly_mentor" checkbox_id should not be checked
  Then the "join_directly_user" checkbox_id should not be checked
  Then the "membership_request_mentor" checkbox_id should be checked
  And the "invitation_mentor" checkbox_id should be checked
  Then the "student_can_invite_mentor" checkbox_id should not be checked
  Then the "user_can_invite_mentor" checkbox_id should not be checked
  Then the "mentor_can_invite_user" checkbox_id should not be checked
  Then the "mentor_can_invite_mentor" checkbox_id should be checked
  And I should see "Allow user to apply or join for more than one role"
  When I uncheck "mentor_can_invite_mentor"
  Then the "invitation_mentor" checkbox_id should not be checked
  When I check "invitation_mentor"
  When I check "user_can_invite_mentor"
  When I check "mentor_can_invite_user"
  Then the "student_can_invite_mentor" checkbox_id should be checked
  And the "mentor_can_invite_mentor" checkbox_id should be checked
  Then I scroll to the top of the page
  When I choose "join_directly_mentor"
  Then the "membership_request_mentor" checkbox_id should not be checked
  Then "#program_show_multiple_role_option" should not be visible
  And I choose "join_directly_user"
  And I press "Save"
  Then I should see "Your changes have been saved"
  Then I choose "membership_request_mentor"
  And the "join_directly_mentor" checkbox_id should not be checked
  Then "#program_show_multiple_role_option" should be visible
  And I choose "program_show_multiple_role_option_true"
  And I press "Save"
  Then I should see "Your changes have been saved"
  Then the "join_directly_mentor" checkbox_id should not be checked
  Then the "join_directly_user" checkbox_id should be checked
  Then the "membership_request_mentor" checkbox_id should be checked
  And the "invitation_mentor" checkbox_id should be checked
  Then the "student_can_invite_mentor" checkbox_id should be checked
  Then the "mentor_can_invite_mentor" checkbox_id should be checked
  Then the "user_can_invite_mentor" checkbox_id should be checked
  Then the "mentor_can_invite_user" checkbox_id should be checked
  Then I logout
  Given the current program is "primary":"albers"
  And I follow "Join"
  Then I should see "Mentor and Student"

@javascript
Scenario: Signup options based on membership request mode
  Given "primary" organization supports additional authentication mode
  And I make "mentor" role as "join_directly" in "primary":"albers"
  And I make "student" role as "join_directly_only_with_sso" in "primary":"albers"

  Given the current program is "primary":"albers"
  When I follow "Join"
  And I choose "roles_mentor"
  Then I should see "Email"
  And I should see "External Login"

  When I choose "roles_student"
  Then I should not see "Email"
  And I should see "External Login"

@javascript
Scenario: Admin Chooses different settings for mentor and mentee roles
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I should see "Membership Requests"
  And I make "mentor" role as "join_directly" in "primary":"albers"
  And I make "student" role as "join_directly_only_with_sso" in "primary":"albers"
  And I follow "Home"
  And I follow "Manage"
  Then I should see "Membership Requests"
  And I accept the pending membership requests for "albers"
  And I follow "Home"
  And I follow "Manage"
  Then I should see "Membership Requests"
  Then I follow "Membership Requests"
  Then I should see "There are no membership requests matching your chosen criteria. "
  And I logout

@javascript
Scenario: Admin logs in and disables the feature
  Given the current program is "primary":"albers"
  And I maximize the window
  And I should see "Join"
  And I should see "Join" in "mobile_header_links"
  And I follow "Join"
  Then I should see "Join As"

  # Admin logs in and makes sure membership_Requests is available at all places
  When I follow "Sign In"
  And I fill in "Email" with "ram@example.com"
  And I fill in "Password" with "monkey"
  And I press "Login"
  Then I should see "title" attribute for profile picture matches with "Freakin Admin (Administrator)"
  Then I dismiss management report tour
  And I follow "Manage"
  Then I should see "Membership Requests"
  And I follow "Membership Requests"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Membership"
  Then I should see "Apply to Join"
  Then I uncheck "apply_to_join_mentor"
  And I uncheck "apply_to_join_student"
  And I press "Save"
  Then I should see "Your changes have been saved"
  Then I logout

  Then I should not see "Join"
  And I should not see "Join" in "mobile_header_links"