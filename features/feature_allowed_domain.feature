Feature: When super user sets an allowed email domain, only those users must be able to join

Background: Super user sets the allowed email domain

  Given the current program is "primary":""
  When I have logged in as "ram@example.com"
  And I login as super user
  Then I follow "Manage"
  Then I follow "Program Settings"
  Then I follow "Security"
  And I fill in "organization_security_setting_attributes_email_domain" with "chronus.com"
  Then I press "Save"
  And I logout

@javascript
Scenario: User tries to join now with different email domain

  Given the current program is "primary":"albers"
  Then I want to join as "Mentor" with "harrypotter@test.com"
  And I open new mail
  And I follow "Complete Sign Up" in the email
  Then I should see "To join as Mentor, complete and submit the form below."
  Then the disabled "membership_request_email" field should contain "harrypotter@test.com"
  And I fill in "membership_request_first_name" with "Harry"
  And I fill in "membership_request_last_name" with "Potter"
  And I fill in "membership_request_password" with "monkey"
  And I fill in "membership_request_password_confirm" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Submit"
  And I press "Submit"
  Then I should see "There are some problems with your request"
  Then I should see "should be of chronus.com"

@javascript @cross_browser
Scenario: An admin invites user with different domain and he tries to join

  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I choose "role_assign_roles"
  And I check "Student"
  And I fill in "recipients" with "dormant@example.com"
  And I press "cjs_send_invites"
  Then I should see "Invitations won't be sent to email id(s) listed below as they are invalid or correspond to existing users or doesn't fall under allowed domains(chronus.com): dormant@example.com"