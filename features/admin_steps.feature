@admin_steps @javascript
Feature: Admin invites (mentors,mentees), edits program overview, adds the mentors directly, add adminnotes to a user, add existing user as admin
In order to perform the above steps
As an admin
I want to login and enter the appropriate as required

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Then I set total responses for surveys

@javascript @download
Scenario: Mentor calendar export to csv
  And I clear the downloads folder
  Then I follow "Health Reports" within "nav#sidebarLeft"
  Then I should not see "Mentoring Calendar Report"
  And I login as super user
  And I go to feature listing page in primary:albers program
  And I check "mentoring_connection_meeting"
  And I press "Save"
  And I logout as super user
  Given the current program is "primary":"albers"
  Then I should see "Health Reports" within "#sidebarLeft"
  Then I follow "Health Reports" within "nav#sidebarLeft"
  Then I should see "Mentoring Calendar Report"
  And I follow "Mentoring Calendar Report"
  Then I should see "Scheduled"
  Then I should see "Upcoming"
  Then I should see "Past"
  And I click "#cjs-reports-export-dropdown"
  And I follow "Export as CSV"
  Then I wait for download to complete
  Then the csv header must have the fields "Title,Member(s),Start Time,Duration (hours),Location"
  Then the csv must contain "Arbit Daily Topic" under "Title"
  Then the csv must contain "Good unique name, mkr_student madankumarrajan" under "Member(s)"

@javascript
Scenario: Admin visits Meeting Report
  Then I follow "Health Reports" within "nav#sidebarLeft"
  Then I should not see "Meeting Report"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  When I hover over "my_programs_container"
  And I follow "Albers Mentor Program"
  Then I follow "Health Reports" within "nav#sidebarLeft"
  Then I should see "Meeting Report"
  And I follow "Meeting Report"
  And I should see "Scheduled"
  And I should see "Overdue"
  And I should see "Completed"
  And I should see "Canceled"
  And I should see "Meetings Accepted"
  And I should see "Meetings Pending Status"
  And I should see "Meetings Completed"
  And I should see "Meetings Dropped"
  And I follow the back link
  And I should see "Reports" within "#title_box"

  # Apply User Profile filter
  And I follow "Meeting Report"
  Then I follow "filter_report"
  Then I apply the calendar sessions profile filter

@javascript @cross_browser
Scenario: Admin invites mentors
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"
  And I press "cjs_send_invites"

  Then I should not see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And I choose "role_assign_roles"
  And I check "Mentor"
  And I fill in "recipients" with "mentor1@chronus.com"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "mentor1@chronus.com" having "Hello,  I would like to invite you to join the Albers Mentor Program as a mentor"
  And I logout

  # Mentor opens mail
  Then I have logged in as "mentor1@chronus.com" without asserting signout
  When I open new mail
  And I follow "Click here" in the email
  And I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."
  Then I fill in "member_first_name" with "mentor"
  Then I fill in "member_last_name" with "me"
  And element with id "#member_email" should be disabled
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "Sign up"
  Then I should see the flash "Please fill the highlighted fields with appropriate values to proceed"

@javascript @cross_browser
Scenario: Admin deletes an invite
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I fill in "recipients" with "mentorxyz@iit.com"
  And I choose "role_assign_roles"
  And I check "Mentor"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "mentorxyz@iit.com" having "Hello,  I would like to invite you to join the Albers Mentor Program as a mentor"

  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Track Invitation Status"
  And I should see "Invitations"
  And I should see "mentorxyz@iit.com"
  Then I click ".cjs_program_invitation_checkbox"
  And I click on "cjs_delete_invitations" in Actions
  Then I should see "Are you sure you want to delete these Invitations?"
  And I press "Delete"

  Then I should see "The invitation has been successfully deleted."
  And I should see "Invitations"
  And I should not see "mentorxyz@iit.com"
  Then I logout

  # User tries to accept a deleted invite
  Then I have logged in as "mentorxyz@iit.com" without asserting signout
  When I open new mail
  And I follow "Click here" in the email
  Then I should see "The invitation code you provided is not valid. Please contact the program administrator."

@javascript @cross_browser
Scenario: Admin resends invite
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I fill in "recipients" with "mentor123@iit.com"
  And I choose "role_assign_roles"
  And I check "Mentor"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "mentor123@iit.com" having "Hello,  I would like to invite you to join the Albers Mentor Program as a mentor"

  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Track Invitation Status"
  And I should see "Invitations"
  And I should see "mentor123@iit.com"

  Then I click ".cjs_program_invitation_checkbox"
  And I click on "cjs_resend_invitations" in Actions

  Then I should see "Resending the invitation to the user sends out the invitation emails with a newly-generated, valid invitation link. An invitation will be sent out to mentor123@iit.com"
  And I press "Resend"
  Then I should see "Selected invitation(s) will be resent."
  And I should see "Invitations"
  And I should see "mentor123@iit.com" 
  Then I logout

  # User tries to accept a resent invite
  Then I have logged in as "mentor123@iit.com" without asserting signout
  When I open new mail
  And I follow "Click here" in the email
  Then I should see "Welcome! You have been invited to join Albers Mentor Program as a Mentor."

@javascript
Scenario: Admin invites mentees
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"
  And I choose "role_assign_roles"
  And I check "Student"
  And I fill in "recipients" with "student2@iit.com"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "student2@iit.com" having "Hello,  I would like to invite you to join the Albers Mentor Program as a student."

@javascript
Scenario: Admin invites mentors and mentees
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"
  And I choose "role_assign_roles"
  And I check "Mentor"
  And I check "Student"
  And I fill in "recipients" with "student2@iit.com"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "student2@iit.com" having "Hello,  I would like to invite you to join the Albers Mentor Program as a mentor and student"

@javascript
Scenario: Admin invites admins
  And I follow "Manage"
  And I follow "User Views"
  And I click "a.dropdown-toggle.btn"
  And I follow "Invite Users"
  And I should see "Invitations"
  And I choose "role_assign_roles"
  And I check "Administrator"
  And I fill in "recipients" with "admin2@iit.com"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "admin2@iit.com" having "Hello,  I would like to invite you to join the Albers Mentor Program as an administrator."

@javascript @cross_browser
Scenario: Admin invites user and allow user to choose
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  And I should see "Invitations"
  And I choose "role_allow_roles"
  And I check "Mentor"
  And I check "Student"
  And I fill in "recipients" with "student2@iit.com"
  And I press "cjs_send_invites"
  Then I should see "Invitations will be sent. The 'Invitations Sent' listing under 'Track Invitation Status' will update shortly."
  And a mail should go to "student2@iit.com" having "Hello,  I would like to invite you to join the Albers Mentor Program"

@javacript
Scenario: Admin adds a new page and edits Program Overview
  Then I follow "Manage"
  And I follow "Program Overview"
  Then I should see "There are no pages! Add page"
  And I click ".add_new_page_button"
  Then I should see "The 'Program Overview' pages serve as the welcome pages of your program. Add program specific information and/or general guidelines for members of the program."
  And I fill in "page_title" with "New Page"
  And I fill in CKEditor "program_overview_content" with "New page article "
  And I press "Publish"
  Then I should see "New Page"
  And I follow "Edit"
  Then I fill in "page_title" with "Modified Page"
  And I fill in CKEditor "program_overview_content" with "Modified page article "
  And I press "Update"
  Then I should see "Modified Page"
  And I follow "Delete"
  Then I confirm popup
  Then I should see "There are no pages! Add page"

@javascript
Scenario: Admin visits the survey report pages
  Then I should see "Outcome Reports"
  And I follow "Outcome Reports"
  And I should see "Mentee Role User Experience Survey"
  And I follow "Mentee Role User Experience Survey"
  # Back link test
  And I follow back link
  And I should see "Outcome Reports" within "#title_box"

  And I should see "Mentor Role User Experience Survey"
  And I follow "Mentor Role User Experience Survey"
  # Back link test
  And I follow back link
  And I should see "Outcome Reports" within "#title_box"
  And I should not see "Mentoring Relationship Closure"

  When I enable "mentoring_connections_v2" feature as a super user
  And I follow "Manage"
  And I follow "Outcome Reports"
  Then I should see "Mentoring Relationship Closure"
  And I follow "Mentoring Relationship Closure"
  # Back link test
  And I follow back link
  And I should see "Outcome Reports" within "#title_box"

  And I should see "Mentoring Relationship Health"
  And I follow "Mentoring Relationship Health"
  # Back link test
  And I follow back link
  And I should see "Outcome Reports" within "#title_box"
  
@javascript @p2 @reindex
Scenario: Admin visits the Mentoring calendar report when calendar and mentoring connection meeting feature is enabled
  Given I update the mentoring slot of "robert@example.com"
  And I follow "Health Reports"
  Then I should not see "Mentoring Calendar Report"
  And I login as super user
  And Then I enable "Calendar" feature
  And I go to feature listing page in primary:albers program
  And I check "mentoring_connection_meeting"
  And I press "Save"
  And I logout as super user
  When I hover over "my_programs_container"
  And I follow "Albers Mentor Program"
  And I follow "Health Reports"
  Then I should see "Mentoring Calendar Report"
  And I follow "Mentoring Calendar Report"
  # Back link test
  And I follow the back link
  And I should see "Health Reports" within "#title_box"
  And I follow "Mentoring Calendar Report"
  Then I follow "filter_report"
  Then I apply the mentoring sessions filter

@javascript
Scenario: Admin creates admin notes for users
  When I visit the profile of the first mentor
  Then I open admin notes section
  #Then I follow "Add a personal note" within "div#sidebarRight"
  And I fill in "user_admin_notes" with "Dangerous fellow. Be careful."
  And I press "Save" within "#admin_note_section"
  When I visit the profile of the first mentor
  Then I should see the admin notes "Dangerous fellow. Be careful."

Scenario: Admin mentor can invite mentees, mentors and admins
  And the admin is a "student"
  When I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  Then I should see "Invitations"
  And I choose radio button with label "Assign role(s) to users"
  And I should see "Mentor" within "#role_btn_group"
  And I should see "Student" within "#role_btn_group"
  And I should see "Administrator" within "#role_btn_group"

Scenario: Admin mentee can invite mentees, mentors and admins
  And the admin is a "mentor"
  When I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  Then I should see "Invitations"
  And I choose radio button with label "Assign role(s) to users"
  And I should see "Mentor" within "#role_btn_group"
  And I should see "Student" within "#role_btn_group"
  And I should see "Administrator" within "#role_btn_group"

Scenario: Admin mentor mentee can invite mentees, mentors and admins
  And the admin is a "mentor"
  And the admin is a "student"
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  Then I should see "Invitations"
  And I choose radio button with label "Assign role(s) to users"
  And I should see "Mentor" within "#role_btn_group"
  And I should see "Student" within "#role_btn_group"
  And I should see "Administrator" within "#role_btn_group"

Scenario: Admin logs out
  And I logout
  Given the current program is "primary":"albers"
  Then I should see "There are no pages!"

@javascript @cross_browser
Scenario: Engagement Activity Report - Edit Columns
  Then I follow "Health Reports" within "nav#sidebarLeft"
  Then I should see "Mentoring Connection Activity Report"
  And I follow "Mentoring Connection Activity Report"
  Then I should see "Messages"
  And I should not see "Mentor Messages"
  And I should not see "Completed Tasks"
  And I should not see "Meetings" within "#cjs_groups_report_table_view"
  Then I follow "Edit Columns"
  Then I should see "Select Fields to Display"
  Then I should not see "Mentor Survey Responses"
  Then I should not see "Student Survey Responses"
  Then I should not see "Completed Tasks"
  Then I should see "Total Activities"
  Then I should see "Current Status"
  Then I should not see "Meetings" within "#cjs_edit_columns_form"
  And I click ".ui-icon-arrowthickstop-1-w"
  And I press "Update View"
  Then I should see "You need to select at least one field"
  Then I click ".ui-icon-arrowthickstop-1-e"
  And I press "Update View"
  Then I should see "Mentor Messages"
  Then I should see "Student Messages"
  And I logout

@javascript
Scenario: Engagement Activity Report - Filters and Chart with connections_v2 disabled
  Then I follow "Health Reports" within "nav#sidebarLeft"
  And I follow "Mentoring Connection Activity Report"
  And I verify the presence of charts
  Then I follow "filter_report"
  When I filter on "Mentor" in report with name "mentor"
  And I verify the presence of charts
  And I follow "Month"
  And I verify the presence of charts
  And I follow "Day"
  And I verify the presence of charts
  And I should see "Summary"
  And I should see "3 Ongoing Mentoring Connections in this period"
  And I should see "3 Total activities in this period"
  And I should see "Mentoring Connections"
  And I should see "Mentoring Connections with activity"
  And I should see "Mentoring Connections without any activity"
  And I verify the presence of pie chart
  And I logout

@javascript
Scenario: Engagement Activity Report - connections_v2 enabled
  Then I enable "mentoring_connections_v2" feature as a super user
  Then I follow "Health Reports" within "nav#sidebarLeft"
  And I follow "Mentoring Connection Activity Report"
  And I verify the presence of charts
  And I should see "Summary"
  And I should see "7 Ongoing Mentoring Connections in this period"
  And I should see "9 Total activities in this period"
  And I enable "mentoring_connection_meeting" feature as a super user
  Then I reload the page
  And I should see "Summary"
  And I should see "7 Ongoing Mentoring Connections in this period"
  #And I should see "17 Total activities in this period" #Time based failure count
  And I should see "Mentoring Connections"
  And I should see "Mentoring Connections with activity"
  And I should see "Mentoring Connections without any activity"
  And I verify the presence of pie chart
  And I logout

@javascript @cross_browser
Scenario: Demographic Profile Report - Filtering
  Then I add locations for members
  Then I follow "User Reports" within "nav#sidebarLeft"
  And I follow "Geographic Distribution Report"
  And I should see "India"
  And I should see "Ukraine"
  Then I follow "filter_report"
  And I click "#country_Ukraine"
  And I press "Go"
  Then I follow "filter_report"
  And I click "#role_mentor"
  And I click "#country_India"
  And I press "Go"
  Then I logout

@javascript
Scenario: Admin should see Support in side pane and under profile dropdown
  Then I should see "Support"
  And I click on profile picture and see "Support"
  Then I follow "Home"
  Then I should see "Dashboard"
  Then I logout
