Feature: User applying for membership

@enrollment_scenario
@javascript @cross_browser
Scenario: Admin uses sent between filters in the membership requests listing page
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  Given a pending membership request created at "1900" with email "rahim@example.com" and role as "Mentor"
  Given a pending membership request created at "1950" with email "ram@example.com" and role as "Mentor"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I should see "10" selected for items per page
  And I click "div.items_per_page select option[value='40']"
  And I follow "report_date_range"
  And I select "Custom" from reports date range presets
  And I should see "Sent Between"
  And I fill in sent between field with "01/01/1875 - 01/01/1925"
  And I press "Go"
  Then I should see "Showing 1 - 1 of 1"
  And I should see "1900"
  And I should not see "1950"
  And I follow "report_date_range"
  And I fill in sent between field with "01/01/1925 - 01/01/1975"
  And I press "Go"
  Then I should see "Showing 1 - 1 of 1"
  And I should not see "1900"
  And I should see "1950"
  And I follow "filter_report"
  And I choose "role_student"
  And I press "Go"
  Then I should see "There are no membership requests matching your chosen criteria."
  Then I follow "filter_report"
  Then I follow "Reset"
  Then I should not see "1900"
  And I should see "1950"
  And I follow "report_date_range"
  And I fill in sent between field with "01/01/1899 - 01/01/1975"
  And I press "Go"
  Then I should see "1900"
  And I should see "1950"

@enrollment_scenario
@javascript @cross_browser
Scenario: Admin filters and sorts membership requests
  Given the current program is "primary":"albers"
  When I add a membership question in non default section for mentor and student roles in "primary":"albers"
  When I want to join as "Student" with "example@chronus.com"
  Then I click on the signup link sent in email to "example@chronus.com"
  And I fill in all membership questions for "student"
  And I fill the basic information and submit the membership application form
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted"

  Given a pending membership request with email "rahim@example.com" and role as "Mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I should see "10" selected for items per page
  And I click "div.items_per_page select option[value='40']"
  And I should see "Show requests with status" hidden
  And I should see "Show requests with status" not hidden
  Then I see that "Pending" tab is selected
  Then I follow "filter_report"
  Then I should see the radio button "role_all" selected
  And I should see "Show requests with status" hidden
  And I should see "student example"
  Then I click ".close" 
  And I follow "Accepted"
  And I should not see "student example"
  And I should see "There are no membership requests matching your chosen criteria."

  # Sorting
  And I follow "Manage"
  And I follow "Membership Requests"
  And I shift to list view
  And should see "Abc"
  And I sort requests by "First name"
  And should see "Abc"
  Then I sort requests by "First name"
  And should not see "Abc"
  And I follow "2"
  And I should see "Abc" in table "4" row
  And I sort requests by "About Me"
  And I should not see "Test_About Me"
  And I sort requests by "About Me"
  And I should see "Test_About Me" in table "1" row
  And I follow "2"
  And I should not see "Test_About Me"

@enrollment_scenario
@javascript @cross_browser
Scenario: Filters and Sort order must be retained when admin toggles between list view and detailed view
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "Mentor"
  And I have logged in as "ram@example.com"
  Then I add a membership question in non default section for mentor and student roles in "primary":"albers"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I should see "10" selected for items per page
  And I should see "student example"
  Then I see that "Pending" tab is selected
  Then I follow "filter_report"
  And I should see "Applicant's Profile"
  And I select "About Me" from profile filter questions
  And I select "Contains" as profile filter operator
  Then I fill "want to be a mentor" as profile filter answer
  And I press "Go"
  And I should see "There are no membership requests matching your chosen criteria."
  Then I follow "filter_report"
  Then I follow "Reset"
  And I should not see "There are no membership requests matching your chosen criteria."
  And I shift to list view
  And I should see "rahim@example.com"
  Then I see that "Pending" tab is selected
  And I follow "Accepted"
  Then I see that "Accepted" tab is selected
  And I should not see "rahim@example.com"

@javascript
@enrollment_scenario
Scenario: Admin bulk rejects membership requests
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "Mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I follow "Actions"
  And I follow "Reject"
  Then I should see "Please select at least one request"
  And I select all requests in the page
  And I follow "Actions"
  And I follow "Reject"
  Then I should not see "Note"
  And I press "Submit"

  Then I should not see "Users have been notified that the membership request was not accepted."
  Then I should see "You have selected 10 requests."
  Then I should see "An email with the message will be sent to the selected 10 users if you complete this action."
  And I fill in "membership_request_response_text" with "Sorry not accepted"
  And I press "Submit"

  Then I should see "Users have been notified that the membership request was not accepted."
  Then a mail should go to "rahim@example.com" having "Sorry not accepted"

@javascript @cross_browser
@enrollment_scenario
Scenario: Admin bulk accepts membership requests
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I follow "Actions"
  And I follow "Accept"
  Then I should see "Please select at least one request"
  And I select all requests in the page
  And I follow "Actions"
  And I follow "Accept"

  Then I should see "You have selected 10 requests."
  Then I should see "An email invitation with the message will be sent to the selected 10 users if you complete this action."
  Then I should see "Note"
  And I fill in "membership_request_response_text" with "Accepted!"
  And I press "Accept"

  Then I should see "The requests have been accepted."

@javascript
@enrollment_scenario
Scenario: Admin bulk ignores of a membership requests
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I follow "Actions"
  And I follow "Ignore"
  Then I should see "Please select at least one request"
  And I select all requests in the page
  And I follow "Actions"
  And I follow "Ignore"

  Then I should see "You have selected 10 requests."
  Then I should see "Are you sure you want to ignore selected requests? This cannot be undone."
  And I press "Confirm"

  Then I should see "The requests were deleted."

@javascript
@enrollment_scenario
Scenario: Select and unselect membership requests in bulk
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I select all requests in the page
  Then I should see "All 10 Membership requests on this page are selected. Select all 13 Membership requests in this view"
  And I click "#cjs_select_all_handler"

  Then I should see "All 13 Membership requests in this view are selected. Clear selection"
  Then I click ".next_page"
  And I follow "Actions"
  And I follow "Accept"

  Then I should see "You have selected 13 requests. Accepting these requests will assign the roles users have applied for."
  And I follow "Cancel"

  And I click "#ct_membership_request_checkbox_3"
  And I click "#ct_membership_request_checkbox_2"
  And I follow "Actions"
  And I follow "Accept"
  Then I should see "You have selected 11 requests."
  And I follow "Cancel"

  And I click "#ct_membership_request_checkbox_3"
  And I click "#ct_membership_request_checkbox_2"
  And I follow "Actions"
  And I follow "Accept"

  Then I should see "You have selected 13 requests."
  And I follow "Cancel"
  And I select all requests in the page
  And I follow "Actions"
  And I follow "Accept"
  Then I should see "Please select at least one request"

@javascript
@enrollment_scenario
Scenario: Individual send message from membership requests listing
  Given the current program is "primary":"albers"
  Given a pending membership request with email "rahim@example.com" and role as "mentor"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  Then I click on the individual dropdown for the membership request with email "rahim@example.com"
  And I follow "Send Message"
  Then I fill in the subject and content with "Subject" and "Content" respectively
  And I press "Send"
  Then I should see "Your message has been sent"
  Then mail should go to "rahim@example.com" having "Content"
  Then I click on the individual dropdown for the membership request with email "rahim@example.com"
  And I follow "View Sent Messages"
  Then I should see "To" in Applied Filters
  Then I should see "Date Range" in Applied Filters
  Then I should see the sender filled as "student example <rahim@example.com>"
  Then I should see the daterange filled
  Then I logout

@javascript
@enrollment_scenario
Scenario: Bulk send message from membership requests listing
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I select all requests in the view
  And I follow "Actions"
  And I follow "Accept"
  And I press "Accept"
  Given a pending membership request with email "rahim@example.com" and role as "mentor"
  Given a pending membership request with email "robert@example.com" and role as "student"
  And I follow "Manage"
  And I follow "Membership Requests"
  And I shift to list view
  And I select all requests in the page
  And I follow "Actions"
  And I follow "Send Message"
  Then I fill in the subject and content with "Subject" and "Content" respectively
  And I press "Send"
  Then I should see "Your message has been sent"
  Then individual mails should go to "rahim@example.com,robert@example.com" having "Content"
  And I shift to detailed view
  And I follow "Actions"
  And I follow "Send Message"
  Then I fill in the subject and content with "Subject" and "Content" respectively
  And I press "Send"
  Then I should see "Your message has been sent"
  Then individual mails should go to "rahim@example.com,robert@example.com" having "Content"
  Then I click on the individual dropdown for the membership request with email "rahim@example.com"
  And I follow "View Sent Messages"
  Then I should see "To" in Applied Filters
  Then I should see "Date Range" in Applied Filters
  Then I should see the sender filled as "student example <rahim@example.com>"
  Then I should see the daterange filled
  And I follow "Manage"
  And I follow "Membership Requests"
  Then I click on the individual dropdown for the membership request with email "robert@example.com"
  And I follow "View Sent Messages"
  Then I should see "To" in Applied Filters
  Then I should see "Date Range" in Applied Filters
  Then I should see the sender filled as "Good unique name <robert@example.com>"
  Then I should see the daterange filled
  Then I logout

@enrollment_scenario
@javascript @p2
Scenario: User sends a membership request / enrollment with manager type question
  And I perform missed migrations
  Given the current program is "primary":"albers"
  Given the feature "enrollment_page" is enabled for "primary"
  And I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Customize Profile"
  Then I configure manager type question for membership form
  And I logout

  Given the current program is "primary":"albers"
  When I want to join as "Mentor" with "example@chronus.com"
  Then I click on the signup link sent in email to "example@chronus.com"
  And I fill in manager_question of "primary":"albers" with "first_name,last name,manager@example.com"
  And I fill the basic information and submit the membership application form
  Then I should see "Your request has been sent to the program administrators. You will receive an email once the request is accepted"
  Then a mail should go to "manager@example.com" having "This is to inform you that Abc def, one of your direct reports"
  And I have logged in as "moderated_mentor@example.com"
  And I select "Mentor" from "role_names_select"
  And I fill in manager_question of "primary":"albers" with "first_name,last name,manager@example.com"
  And I press "Submit"
  Then a mail should go to "manager@example.com" having "one of your direct reports, has either applied to participate in, or has already joined Albers Mentor Program as a mentor."
  And I logout

@javascript
@enrollment_scenario
Scenario: Membership request not sent with wrong info
  # User sending membership request as mentor
  Given the current program is "primary":"albers"
  Given all membership questions are not mandatory
  When I want to join as "Mentor" with "example@chronus.com"
  Then I click on the signup link sent in email to "example@chronus.com"
  And I fill the basic information with wrong name and submit the membership application form
  Then I should see "There are some problems with your request. Please correct the below error(s) highlighted in red."
  And I should see "contains numeric characters" within ".membership_request_first_name"

@javascript
Scenario: Redirect to Signup Instructions Page after using apply with Chronus Auth
  Given the current program is "primary":"albers"
  And I should see "Join" within "#header_actions"
  When I want to join as "Mentor" with "newmember@chronus.com"
  And I should not see "Join" within "#header_actions"
  And a mail should go to "newmember@chronus.com" having "Thank you for your interest in joining as a mentor in Albers Mentor Program. To finish signing-up, click on the button below."
  Then I click "#resend_signup_mail_link"
  And a mail should go to "newmember@chronus.com" having "Thank you for your interest in joining as a mentor in Albers Mentor Program. To finish signing-up, click on the button below."
  Then I should see "Email with instructions to join the program has been resent."

@javascript
Scenario: User tries to resend after using the invite code
  Given the current program is "primary":"albers"
  And I should see "Join" within "#header_actions"
  When I want to join as "Mentor" with "newmember@chronus.com"
  And I should not see "Join" within "#header_actions"
  And a mail should go to "newmember@chronus.com" having "Thank you for your interest in joining as a mentor in Albers Mentor Program. To finish signing-up, click on the button below."
  Then I use invite code for email "newmember@chronus.com"
  Then I click "#resend_signup_mail_link"
  Then I should see "You have already signed up for the program. Please click here to login."
