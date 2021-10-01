# encoding: utf-8
Feature: to test the group mentoring
  In order to test group mentoring
  As an admin
  I want to be able to establish connection between two students and a mentor

  Background:
    Given the current program is "annauniv":"psg"

  @javascript @cross_browser
  Scenario: Two students establish a connection with the mentor

    # login as the student and Request Ongoing Mentoring
    Given there are no activities
    When I have logged in as "stud1@psg.com"
    And I fill in "query" with "mental"
    And I search
    And I follow "Connect" within "#search_results"
    And I follow "Add to preferred mentors"
    Then I should see "You have 1 preferred mentor."
    Then I follow "Mentors"
    Then I should see "Request Mentoring Connection" within "#title_actions"
    Then I follow "Request Mentoring Connection" within "#title_actions"
    Then I should see "mental mentor"
    And I fill in "mentor_request_message" with "he is good"
    Then I press "Send request"
    Then I should see "Your request has been sent to administrator"
    Then I logout

    # Login as an admin and establish the above requested connection
    When I have logged in as "psg@example.com"
    Then I configure messaging in the connection template
    And I follow "Manage"
    And I follow "Mentoring Requests"
    Given I follow "Assign" for the group "results_pane"
    And I fill in the group_mentor with "psg_mentor <mentor@psg.com>"
    And I press "Assign"
    Then I should see "has been assigned"

    # Admin adds another student directly to the group
    Then I add another student to the group
    Then I logout

    #student logs in and posts on discussion forum
    When I have logged in as "stud2@psg.com"
    And I visit the mentoring connection of mentor "mentor@psg.com"
    And I follow "New Message"
    And I fill in "scrap[subject]" with "Discussion"
    And I fill in "scrap[content]" with "Am creating a discussion"
    And I press "Send Message"
    Then individual mails should go to "stud1@psg.com,mentor@psg.com" having "Am creating a discussion"

  @javascript @cross_browser
  Scenario: Expired connections should be terminated
    # For the email body to be set to response text, there should be a request.
    # So, here we are making a dummy request to prepare for email, this also serves as login
    Given the current program is "primary":"albers"
    When I have logged in as "mkr@example.com"

    Given that a group expires in "-1" days

    And that its not yet closed
    And the cron task expire connections runs
    Then the group must be closed
    Then an expiry notification mail should go to members

    # Closed connections should not be changed by cron
    Then running cron task expire connections should not trigger emails
    Then the group must be closed

    # Student visits the mentoring connection
    When I follow "Home"
    # TODO: Since we are not delta indexing groups, the automatically closed group wont be listed in the closed section.
    # So, commenting out the following step.
    And I follow "Closed"
    And I follow "Ongoing (0)"
    And I follow "name & madankumarrajan"
    Then I should see "The mentoring connection has ended"

  @javascript @cross_browser
  Scenario: About to expire connections should not be terminated
    # For the email body to be set to response text, there should be a request.
    # So, here we are making a dummy request to prepare for email, this also serves as login
    Given the current program is "primary":"albers"
    When I have logged in as "mkr@example.com"

    Given that a group expires in "1" days
    And that its not yet closed

    Then running cron task expire connections should not trigger emails
    Then the group must be active

    # Student visits the mentoring connection
    And I follow "name & madankumarrajan"
    Then I should see "The mentoring connection comes to an end in"

  @javascript @cross_browser
  Scenario: Inactive connections should not be terminated
    # For the email body to be set to response text, there should be a request.
    # So, here we are making a dummy request to prepare for email, this also serves as login
    Given the current program is "primary":"albers"
    When I have logged in as "mkr@example.com"

    Given that a group expires in "1" days
    And that its inactive

    Then running cron task expire connections should not trigger emails
    Then the group must be inactive

    # Student visits the mentoring connection
    And I follow "name & madankumarrajan"
    Then I should see "The mentoring connection comes to an end in"

  @javascript
  Scenario: Admin changes the expiry date of a group
  # First log in as admin
    Given the current program is "primary":"albers"
    Given I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    
    # admin resets the expiry date of the group
    And I click on "set_expiry_date_1" for the group "group_1"
    Then I should see "Cancel"
    And I fill in "set_expiry_date_reason_1" with "A reason"
    And I fill in first "set_new_expiry_date" with a date 10 days from now
    Then I should see "Set Expiration Date"
    And I press "Set Expiration Date"
    Then I should see "New expiration date for the mentoring connection has been set"
    And I logout

  @javascript @cross_browser
  Scenario: Admin changes the expiry date of a group to invalid date
  # First log in as admin
    Given the current program is "primary":"albers"
    Given I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I click on "set_expiry_date_1" for the group "group_1"
    # admin resets the expiry date of the group
    And I fill in "set_expiry_date_reason_1" with "A reason"
    And I fill in first "set_new_expiry_date" with an invalid date
    And I press "Set Expiration Date"
    Then I should see "Please enter a valid date"
    And I fill in first "set_new_expiry_date" with a old date
    And I press first "change_expiry_date_button" button
    Then I should see "Please enter a date in the future"
    And I logout    

@javascript @cross_browser
  Scenario: Admin reactivates expired connection
    Given the current program is "primary":"albers"

    Given that the fourth group is terminated due to expiry

    When I have logged in as "student_4@example.com"
    Then I follow "My Mentoring Connections"
    And I follow "Closed"
    And I follow "Visit Mentoring Connection"
    Then I should see "The mentoring connection has ended."
    Then I logout

    # Then login as admin to extend the connection
    Given the current program is "primary":"albers"
    Then I have logged in as "ram@example.com"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I follow "Closed"
    # admin terminates the group
    And I click on "reactivate_link_4" for the group "group_4"
    Then I should see "Reactivate Mentoring Connection - mentor & example"
    And I fill in "group_reactivation_reason_4" with "A reason"
    And I fill in fourth "set_new_expiry_date" with a date 20 days from now

    And I press "Reactivate"
    Then I should see "The mentoring connection has been reactivated"
    Then I logout

    When I open new mail
    Then I should see "We have reactivated your mentoring connection" in the email text part body
    And I follow "mentor &amp; example" in the email
    And I fill in "email" with "student_4@example.com"
    And I fill in "password" with "monkey"
    Then I press "Login"
    Then I wait for ajax to complete
    Then I should first see a reactivation mail

  @javascript
  Scenario: Admin reactivates expired connection to invalid date
    Given the current program is "primary":"albers"

    Given that the fourth group is terminated due to expiry

    When I have logged in as "student_4@example.com"
    Then I follow "My Mentoring Connections"
    And I follow "Closed"
    And I follow "Visit Mentoring Connection"
    Then I should see "The mentoring connection has ended."
    Then I logout

    # Then login as admin to extend the connection
    Then I have logged in as "ram@example.com"
    And I select "Albers Mentor Program" from the program selector
    And I follow "Manage"
    And I follow "Mentoring Connections"
    And I follow "Closed"
    # admin terminates the group
    And I click on "reactivate_link_4" for the group "group_4"
    And I fill in "group_reactivation_reason_4" with "Test Reason"
    And I fill in fourth "set_new_expiry_date" with an invalid date
    And I press "Reactivate"
    Then I should see "Please enter a valid date"
    And I fill in fourth "set_new_expiry_date" with a old date
    And I press "Reactivate"
    Then I should see "Please enter a date in the future"
    Then I logout    

@not_run_on_tddium @javascript 
  Scenario: Mentor creates a group and private goals for mentee
    When I have logged in as "mentor1@psg.com"
    Then I follow "mentora, mentorb, mentorc, psg, p..."
    Then I follow "Plan"
    Then I should see "Add New Goal"
    And I click "#add_new_goal"
    And I create a group goal "new group goal" for "mentor1@psg.com"
   
    And I click "#add_new_goal"
    And I create a private goal "stud1 goal" for "stud1@psg.com"
    
    And I click "#add_new_goal"
    And I create a private goal "stud2 goal" for "stud2@psg.com"
   
    And I click "#add_new_goal"
    And I create a private goal "stud3 goal" for "stud3@psg.com"
    
    Then I should see the goal "new group goal" for "All"
    Then I should see the goal "stud1 goal" for "For studa psg"
    Then I should see the goal "stud2 goal" for "For studb psg"
    Then I should see the goal "stud3 goal" for "For studc psg"
    And I logout
    # Another mentor logs in
    When I have logged in as "mentor2@psg.com"
    Then I follow "mentora, mentorb, mentorc, psg, p..."
    Then I follow "Plan"
    Then I should see the goal "new group goal" for "All"
    Then I should see the goal "stud1 goal" for "For studa psg"
    And I follow "Show more"
    Then I should see the goal "stud2 goal" for "For studb psg"
    Then I should see the goal "stud3 goal" for "For studc psg"
    And I logout

    # Student 1 logs in
    When I have logged in as "stud1@psg.com"
    Then I follow "mentora, mentorb, mentorc, psg, p..."
    Then I follow "Plan"
    Then I should see the goal "new group goal" for "All"
    And I should see the goal "stud1 goal" for "For studa psg"
    And I should not see "stud2 goal"
    And I should not see "stud3 goal"
    And I logout

    # Student 2 logs in
    When I have logged in as "stud2@psg.com"
    Then I follow "mentora, mentorb, mentorc, psg, p..."
    Then I follow "Plan"
    Then I should see the goal "new group goal" for "All"
    And I should see the goal "stud2 goal" for "For studb psg"
    And I should not see "stud1 goal"
    And I should not see "stud3 goal"
    And I logout

  @javascript
  Scenario: Users should not see edit link for closed groups in mentoring area.
    Given the current program is "primary":"albers"
    When I have logged in as "student_2@example.com"
    Then I follow "My Mentoring Connections"
    Then I follow "mentor & example"
    Then I follow "Plan"
    And I follow "Edit"
    Then I should see "Mentoring Connection Name"
    Then I logout

    Given the current program is "primary":"albers"
    Given that the fourth group is terminated due to expiry
    When I have logged in as "student_4@example.com"
    Then I follow "My Mentoring Connections"
    And I follow "Closed"
    And I follow "Visit Mentoring Connection"
    Then I should not see page actions
    Then I logout

  @javascript
  Scenario: Users should be able to see back link in groups show page
    Given the current program is "primary":"albers"
    When I have logged in as "student_2@example.com"
    Then I follow "My Mentoring Connections"
    Then I follow "mentor & example"
    Then I follow "Plan"
    And I follow back link
    Then I should see "mentor & example"
    And I should see "user & example"
