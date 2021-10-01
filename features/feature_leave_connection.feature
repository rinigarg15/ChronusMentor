@leave_connections
Feature: Leave Mentoring Connection/Close Mentoring Connection for leave connection in option for end users

@javascript @cross_browser
Scenario: Admin enabling the option for end users to leave connection and the users in one-one closes the connection

     Given the current program is "primary":"albers"
     Given I have logged in as "mkr@example.com"
     And I follow "name & madankumarrajan"
     Then I should not see "Close Mentoring Connection" within "#SidebarRightContainer"
     Then I logout
     When I have logged in as "ram@example.com"
     Then I enable the option for users to leave mentoring connection
     Then I logout
     When I have logged in as "mkr@example.com"
     And I follow "name & madankumarrajan"
     Then I should see "Close Mentoring Connection" within "#SidebarRightContainer"
     Then I follow "Close Mentoring Connection"
     And I fill in "group_termination_reason" with "Test close"
     Then I press "Close Mentoring Connection"
     And individual mails should go to "robert@example.com,mkr@example.com" having "has come to a close"
     Then I logout

 @javascript @cross_browser
 Scenario: End users in group mentoring leaving the connection
  
     Given the current program is "annauniv":"psg"
     When I have logged in as "psg@example.com"
     Then I enable the option for users to leave mentoring connection
     Then I logout
     When I have logged in as "mentor1@psg.com"
     Then I follow "mentora, mentorb, mentorc, psg, p..."
     Then I should see "Leave Mentoring Connection" within "#SidebarRightContainer"
     Then I follow "Leave Mentoring Connection"
     And I fill in "group_termination_reason" with "Test Leave"
     Then I press "Leave Mentoring Connection"
     Then I should see "You have left the Mentoring Connection"
     Then I follow "View Profile"
     Then I should see " 0 Ongoing mentoring connections"
     Then I should see " 0 Past mentoring connections"
     Then I logout
    






