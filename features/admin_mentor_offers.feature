@javascript
Feature: Manage mentor offers by an Admin
  Background:
    Given the current program is "primary":"albers"
    Given there is one to many in "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I login as super user
    Then I follow "Manage"
    And I follow "Program Settings"
    And I follow "Connection Settings"
    And Then I enable "offer_mentoring" feature
    And I create mentor offers
    Then I follow "Manage"
    Then I follow "Mentoring Offers"

@cross_browser
Scenario: Bulk messages to senders
    And I follow "Actions"
    And I follow "Send Message to Senders"
    Then I should see "Please select at least one offer"
    And I click last mentor offer
    And I follow "Actions"
    And I follow "Send Message to Senders"
    And I fill in "admin_message_subject" with "Subject senders"
    And I fill in CKEditor "admin_message_content" with "Content senders"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout
    
@cross_browser
Scenario: Bulk messages to recipients
    And I follow "Actions"
    And I follow "Send Message to Recipients"
    Then I should see "Please select at least one offer"
    And I click "#cjs_primary_checkbox"
    And I follow "Actions"
    And I follow "Send Message to Recipients"
    Then I should see "Send Message"
    And I fill in "admin_message_subject" with "Subject recipients"
    And I fill in CKEditor "admin_message_content" with "Content recipients"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout

Scenario: Individual message to sender

    Then I click on the individual offer "cjs_send_message_to_sender" in Actions
    And I fill in "admin_message_subject" with "Individual subject"
    And I fill in CKEditor "admin_message_content" with "Individual content"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout

Scenario: Individual message to recipient
    Then I should see "Sort by most recent"
    Then I select "Sort by oldest" from "sort_by"
    And I click on class "cjs_send_message_to_recipient" in Actions
    And I fill in "admin_message_subject" with "Individual subject"
    And I fill in CKEditor "admin_message_content" with "Individual content"
    And I press "Send"
    Then I should see "Your message has been sent"
    And I logout

Scenario: Export Mentor offers as CSV
    When I follow "Manage"
    And I follow "Mentoring Offers"
    And I select all requests in the page
    And I follow "Actions"
    And I follow "Export as CSV"
    Then I wait for download to complete
    And the mentor offers report should be downloaded
