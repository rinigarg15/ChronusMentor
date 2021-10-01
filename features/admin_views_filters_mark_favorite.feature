@reindex
Feature: Admin user management

Background: Admin logs in
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And clear mail deliveries
  And I enable "member_tagging" feature as a super user
  #And I reindex model "user"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Albers Mentor Program"

@javascript
Scenario: Meeting Request filters and columns shown only when calendar enabled and at progam level
  Then I follow "Manage"
  Then I follow "User Views"
  And I follow "Update View"
  Then I should not see "Meeting requests received"
  Then I follow the back link
  When I create a new view
  Then I follow "Next »"
  Then I click view
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
 
  Given the current program is "primary":""
  And I follow "Manage"
  Then I follow "Member Views"
  Then I follow "Update View"
  Then I should not see "Meeting requests received"

  And I follow "Manage"
  Then I follow "Albers Mentor Program"
  Then I follow "Manage"
  Then I follow "User Views"
  Then I follow "Update View"
  Then I should see "Meeting requests received"
  Then I follow the back link
  When I create a new view
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  Then I should see "One-time mentoring"
  Then I logout

@javascript
Scenario: Track Based on Active User count Radio Buttons
  Given the current program is "primary":""
  And I follow "Manage"
  Then I follow "Member Views"
  When I create a new view
  And I fill in "admin_view_title" with "Not Active Users"
  Then I follow "Next »"
  Then I click view
  Then I should see "Show"
  Then I should see "All Members"
  Then I press "Advanced"
  Then I click "#s2id_autogen1"
  Then I click on select2 result "Deactivated"
  Then I click "#s2id_autogen1"
  Then I click on select2 result "Unpublished"
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  Then I should not see "userrobert@example.com"
  Then I should see "pending_user@example.com"

@javascript
Scenario: Applying Meeting Request filters and sort
  And I logout
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I follow "User Views"
  Then I should not see "userrobert@example.com"
  When I create a new view
  And I fill in "admin_view_title" with "Meeting Requests View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I select "Received meeting requests" from "new_view_filter_mentors_meeting_requests"
  Then I follow "Next »"
  Then I click view
  Then I click by xpath "(//div[text()='Meeting requests received'])[last()]"
  And I press "Create View"
  Then I should see "The View - Meeting Requests View has been created successfully"
  Then I should see "Meeting requests received"
  Then I should see "userrobert@example.com"
  Then I should see "2"
  Then I filter table by date filter "meeting_requests_received_v1" with "01/12/2020"
  Then I should see "0"
  Then I logout

@javascript @cross_browser
Scenario: Applying Mentoring Request filters and sort
  And I logout
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I follow "Manage"
  Then I follow "User Views"
  Then I should not see "userrobert@example.com"
  When I create a new view
  And I fill in "admin_view_title" with "Mentoring Requests View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I select "Received mentoring requests" from "new_view_filter_mentors_mentoring_requests"
  Then I follow "Next »"
  Then I click view
  Then I click by xpath "(//div[text()='Mentoring requests received'])[last()]"
  And I press "Create View"
  Then I should see "The View - Mentoring Requests View has been created successfully"
  Then I should see "userrobert@example.com"
  Then I scroll until I see "Mentoring requests received"
  Then I should see "Mentoring requests received"
  Then I should not see "15" within "tr.k-alt>td:nth-of-type(9)"
  Then I should see "userrobert@example.com" within "tr.k-alt"
  Then I should see "5" within "tr.k-alt>td:nth-of-type(9)"
  Then I sort table by "mentoring_requests_received_v1"
  Then I should see "robert@example.com" within "tr.k-alt"
  Then I should see "15" within "tr.k-alt>td:nth-of-type(9)"
  Then I should not see "userrobert@example.com" within "tr.k-alt"
  Then I filter table by date filter "mentoring_requests_received_v1" with "01/12/2020"
  Then I should see "0"
  Then I logout

@javascript @reindex @cross_browser
Scenario: Admin adds a new view with last connection filter
  Then I follow "Manage"
  And I follow "User Views"
  
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "Trial"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  And I should see "Last Mentoring Connection closed on"
  And I select "After" from "admin_view[connection_status][last_closed_connection][type]"
  And I fill month back date in "cjs_last_connection_date"
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  
  And I should see "The View - Trial has been created successfully"

  And I should see "student_4@example.com"
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "Trial 1"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  And I should see "Last Mentoring Connection closed on"
  And I select "Before" from "admin_view[connection_status][last_closed_connection][type]"
  And I fill month back date in "cjs_last_connection_date"
  Then I follow "Next »"
  Then I click view
  And I press "Create View"
  
  And I should not see "student_4@example.com"
  And I follow "Update View"  
  Then I should see "Update View"
  Then I should see "Trial 1"
  And I should see "Last Mentoring Connection closed on"
  And I select "Older than" from "admin_view[connection_status][last_closed_connection][type]"
  And I fill in "admin_view[connection_status][last_closed_connection][days]" with "0"
  And I press "Update View"
  
  And I should see "request@example.com"
  And I follow "Go to the next page"
  And I should see text "student_4@example.com" hidden

