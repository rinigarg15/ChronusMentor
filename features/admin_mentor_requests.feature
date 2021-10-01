@javascript @refresh_mentoring_requests_es_Index
Feature: Manage mentor requests by an Admin
  Background:
    Given the current program is "primary":"albers"
    Given there is one to many in "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I follow "Manage"
    Then I follow "Mentoring Requests"
    And I select "Sort by oldest" from "sort_by"

Scenario: Bulk messages to senders
    And I follow "Actions"
    And I follow "Send Message to Senders"
    Then I should see "Please select at least one request"
    And I click "#ct_mentor_request_checkbox_2"
    And I follow "Actions"
    And I follow "Send Message to Senders"
    And I fill in "admin_message_subject" with "Subject senders"
    And I fill in CKEditor "admin_message_content" with "Content senders"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout
    # Sender got the message
    Given "1" last "message" exist
    When I have logged in as "student_0@example.com"
    And I follow "Messages"
    Then I should see "Subject senders - Content senders"
    And I logout

Scenario: Bulk messages to recipients
    And I follow "Actions"
    And I follow "Send Message to Recipients"
    Then I should see "Please select at least one request"
    And I click "#cjs_primary_checkbox"
    And I follow "Actions"
    And I follow "Send Message to Recipients"
    And I fill in "admin_message_subject" with "Subject recipients"
    And I fill in CKEditor "admin_message_content" with "Content recipients"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout
    # Recipient got the message
    Given "1" last "message" exist
    When I have logged in as "robert@example.com"
    And I follow "Messages"
    Then I should see "Subject recipients - Content recipients"
    And I logout

@cross_browser
Scenario: Individual message to sender
    Given I follow "Actions" within ".actions_box"
    And I follow "Send Message to Sender"
    And I fill in "admin_message_subject" with "Individual subject"
    And I fill in CKEditor "admin_message_content" with "Individual content"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout
    # Sender got the message
    Given "1" last "message" exist
    When I have logged in as "student_0@example.com"
    And I follow "Messages"
    Then I should see "Individual subject - Individual content"
    And I logout
    
@cross_browser
Scenario: Individual message to recipient
    And I click on class "cjs_send_message_to_recipient" in Actions
    And I fill in "admin_message_subject" with "Individual subject"
    And I fill in CKEditor "admin_message_content" with "Individual content"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout
    # Sender got the message
    Given "1" last "message" exist
    When I have logged in as "robert@example.com"
    And I follow "Messages"
    Then I should see "Individual subject - Individual content"
    And I logout

Scenario: Bulk messages to all senders
    And I click "#cjs_primary_checkbox"
    Then I should see "All 10 requests for mentoring on this page are selected. Select all 15 requests for mentoring in this view "
    And I click "#cjs_select_all_handler"
    
    Then I should see "All 15 requests for mentoring in this view are selected. Clear selection"
    Then the "ct_mentor_request_checkbox_2" checkbox_id should be checked
    Then I click ".next_page"
    Then the "ct_mentor_request_checkbox_17" checkbox_id should be checked
    Then the "ct_mentor_request_checkbox_18" checkbox_id should be checked
    And I follow "Actions"
    And I follow "Send Message to Senders"
    Then I should see " student_a example, student_b example, student_c example, student_d example, student_e example and 6 more users"
    And I fill in "admin_message_subject" with "Subject senders"
    And I fill in CKEditor "admin_message_content" with "Content senders"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout
    # Sender got the message
    Given "1" last "message" exist
    When I have logged in as "student_0@example.com"
    And I follow "Messages"
    Then I should see "Subject senders - Content senders"
    And I logout

  Scenario: Bulk messages to all receiver
    And I click "#cjs_primary_checkbox"
    Then I should see "All 10 requests for mentoring on this page are selected. Select all 15 requests for mentoring in this view"
    And I click "#cjs_select_all_handler"
    And I follow "Actions"
    And I follow "Send Message to Recipients"
    Then I should see " Good unique name, robert user "
    And I fill in "admin_message_subject" with "Subject recipients"
    And I fill in CKEditor "admin_message_content" with "Content recipients"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout    
    # Recipient got the message
    Given "1" last "message" exist
    When I have logged in as "userrobert@example.com"
    And I follow "Messages"
    Then I should see "Subject recipients - Content recipients"
    And I logout

  Scenario: Clear all selection
    And I click "#cjs_primary_checkbox"
    Then I should see "All 10 requests for mentoring on this page are selected. Select all 15 requests for mentoring in this view"
    And I click "#cjs_select_all_handler"
    And I follow "Actions"
    And I follow "Send Message to Recipients"
    Then I should see " Good unique name, robert user "
    And I follow "Cancel"
    And I click "#cjs_clear_all_handler"
    And I follow "Actions"
    And I follow "Send Message to Senders"
    Then I should see "Please select at least one request"
    And I logout
    

@not_run_on_bs
Scenario: Bulk Close Mentor Request
# IE browser issue with Trident checkbox selection
    And I follow "Actions"
    And I follow "Close Requests"
    Then I should see "Please select at least one request"
    And I click "#cjs_primary_checkbox"
    Then I should see "All 10 requests for mentoring on this page are selected. Select all 15 requests for mentoring in this view"
    And I click "#cjs_primary_checkbox"
    And I click "#ct_mentor_request_checkbox_2"
    And I follow "Actions"
    And I follow "Close Requests"
    And I fill in "bulk_actions_reason" with "Just Close it"
    And I check "sender"
    And I press "Close Request"
    Then I should see "The selected request has been closed"
    And I wait for "MentorRequest" Elastic Search Reindex
    Then I follow "Closed"
    And I should see "student_a example"
    Then I should see "Closed By"
    Then I should see "Closed At"
    And I should see "Just Close it"
    Then I follow "Pending"
    And I click "#cjs_primary_checkbox"
    Then I should see "All 10 requests for mentoring on this page are selected. Select all 14 requests for mentoring in this view"
    And I logout
    # Closed Requests should be visible to the sender/receiver in closed filter
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    And I click ".pending_requests_notification_icon"
    Then I follow "Mentoring Requests"
    Then I should not see "student_a example"
    Then I click "#list_closed"
    Then I should see "student_a example"
    And I logout
    Given the current program is "primary":"albers"
    When I have logged in as "student_0@example.com"
    And I click ".pending_requests_notification_icon"
    Then I follow "Mentoring Requests"
    Then I should not see "Good unique name"
    Then I click "#list_closed"
    Then I should see "Good unique name"
    Then I should not see "Closed By"
    Then I should see "Closed At"
    And I logout

Scenario: Close Request without reason
    Then I click "#mentor_request_2 .actions_box .dropdown-toggle"
    Then I click "#mentor_request_2 .cjs_close_request"
      
    Then I press "Close Request"
    And I wait for "MentorRequest" Elastic Search Reindex
    Then I follow "Closed"
    Then I should see "Not specified"

Scenario: Close Request is not provided for Moderated Programs
    Given the current program is "primary":"modprog"
    Then I follow "Manage"
    Then I follow "Mentoring Requests"
    And I should not see "Closed"
    Then I follow "Actions"
    And I should not see "Close Requests"
    And I logout