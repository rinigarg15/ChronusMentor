@announcements
Feature: Create/Update Announcements
  In order to inform mentors and students
  As an admin
  I want to post announcements

  Background: Set the program to albers
    Given the current program is "primary":"albers"
  
  @javascript
  Scenario: Admin creates announcement
    When I have logged in as "ram@example.com"
    And I navigate to new announcement page
    And I fill in "announcement_title" with "Announcement Title"
    And I fill in CKEditor "new_announcement_body" with "Test Message <a href='/ck_attachments/1'>Attachment Link</a>"
    And I set the attachment field "announcement[attachment]" to "pic_2.png"
    And I fill in "announcements_expiry" with a expiry date 20 days from now
    And I press "Post"
    Then I should see "Please fill all the required fields. Fields marked * are required"
    And I select "Immediately" from "announcement_email_notification"
    And I press "Post"
    Then I should see "The announcement has been published."
    And I should see "Mentors, Students and Users"
    And I should see "Published"
    And I should see "Expires on"
    And I should see "Announcement Title"
    And I should see "Test Message"
    And I should see "Attachment Link" within "a.cjs_android_download_ckeditor_files"
    And I should see "pic_2.png"
    And I should see "Download"
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I should see "Announcement Title"
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see "Announcement Title"
    And I logout

  @javascript
  Scenario: Admin updates announcement
    When I have logged in as "ram@example.com"
    And I delete all announcements
    And "ram@example.com" creates an announcement with title "Announcement Title"
    When I navigate to announcements page
    Then I should see "Announcement Title"
    Then I follow "Announcement Title"
    And I click ibox dropdown action inside "page_canvas"
    Then I follow "Edit"
    And I fill in "announcement_title" with "Ann Title"
    And I press "Update"
    Then I should see the flash "The announcement has been updated"
    And I should see "Ann Title"
    And I should see "Published"
    And I should see "Expires on"
    When I navigate to announcements page
    Then I should see "Ann Title"
    And I should not see "Announcement Title"

@javascript
  Scenario: Admin views announcements listing
    When I have logged in as "ram@example.com"
    And I navigate to announcements page
    Then I should see "Title"
    Then I should see "For"
    Then I should see "Published"
    Then I should see "Expires on"
    Then I should see "Actions"
    And I logout

  @javascript @cross_browser
  Scenario: MentorMentee views announcements listing
    When I have logged in as "ram@example.com"
    And "ram@example.com" creates an announcement with title "Announcement Title"
    Then I logout

    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I should see "Announcement Title"
    Then I dismiss announcement modal
    When I follow "Announcement Title" within "#recent_activities_get_all"
    Then I should see "Published"
    And I should see "Attachment"
    When I click ".fa.fa-arrow-left"
    Then I should see "Announcements"
    And I should see "Announcement Title"
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I should see "Announcement Title"
    Then I dismiss announcement modal
    When I follow "Read full announcement" within "#recent_activities_get_all"
    Then I should see "Published"
    And I should see "Attachment"
    When I click ".fa.fa-arrow-left"
    Then I should see "Announcements"
    And I should see "Announcement Title"
    And I logout

  @javascript
  Scenario: An announcement has expired
    When I have logged in as "ram@example.com"
    And I delete all announcements
    And "ram@example.com" creates an announcement with title "Announcement Title"
    When I navigate to announcements page
    Then I should see "Announcement Title"
    When I click ".fa.fa-pencil"
    And I fill in "announcements_expiry" with a date -1 days from now
    And I press "Update"
    Then I should see "The announcement has already expired. Do you still want to send email notifications?" within "div.modal-dialog"
    Then I follow "Send"
    Then I should see "The announcement has been updated"
    Then I logout

    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I should not see "div#Announcement"
    When I follow "Read full announcement"
    Then I follow back link
    Then I should not see "Announcement Title"
    Then I logout


  @javascript @cross_browser
  Scenario: Navigate through next and previous links
    When I have logged in as "ram@example.com"
    And I navigate to new announcement page
    And I fill in "announcement_title" with "Announcement Title"
    And I fill in CKEditor "new_announcement_body" with "Test Message <a href='/ck_attachments/1'>Attachment Link</a>"
    And I set the attachment field "announcement[attachment]" to "pic_2.png"
    And I fill in "announcements_expiry" with a expiry date 20 days from now
    And I select "Immediately" from "announcement_email_notification"
    And I press "Post"
    Then I logout

    And I have logged in as "non_request@example.com" with_announcement
    Then I in "60" seconds should see "Announcement Title" within "div#announcement"
    And I should see element "div.announcement_attachment_container"
    Then I should see "pic_2.png" within "div.announcement_attachment_container"
    Then I click ".announcements-slick-next"
    Then I in "60" seconds should see "All come to audi big announce" within "div#announcement"
    And I should not see element "div.announcement_attachment_container"
    #Then I click ".announcements-slick-prev"
    #Then I in "60" seconds should see "Announcement Title" within "div#announcement"
    #Then I should not see "All come to audi big announce" within "div#announcement"
    Then I logout

  @javascript @cross_browser
  Scenario: Hide the alert box for the current session
    And I have logged in as "non_request@example.com" with_announcement
    Then I in "60" seconds should see "All come to audi big announce" within "div#announcement"
    Then I dismiss announcement modal
    Then I should not see "All come to audi big announce"
    Then I logout

  @javascript @p2 @cross_browser
  Scenario: Admin creating announcement specific to role and sending test email
    When I have logged in as "ram@example.com"
    And I navigate to new announcement page
    And I fill in "announcement_title" with "Mentor Announcement Title"
    And I fill in CKEditor "new_announcement_body" with "Test Message"
    And I uncheck "Student"
    And I uncheck "User"
    And I fill in "announcements_expiry" with a date 20 days from now
    And I select "Immediately" from "announcement_email_notification"
    Then I follow "Test Email"
    Then I should see "Test Email"
    And I fill in "announcement_notification_list_for_test_email" with "abcd, \n\n,,"
    Then I press "Send"
    Then I should not see "Test emails have been sent to"
    Then I follow "Test Email"
    Then I should see "Test Email"
    And I fill in "announcement_notification_list_for_test_email" with "ram@example.com"
    Then I press "Submit"
    And a mail should go to "ram@example.com" having "Test Message"
    Then I should see "Test emails have been sent to ram@example.com"
    Then I press "Post"
    Then I should see "The announcement has been published."
    And I should see "Mentors"
    Then I logout
    When I have logged in as "robert@example.com"
    Then I should see "Mentor Announcement Title"
    And I logout
    When I have logged in as "mkr@example.com"
    Then I should not see "Mentor Announcement Title"
    And I logout

  @javascript @cross_browser
  Scenario: Admin creates, updates and publishes draft announcement
    When I have logged in as "ram@example.com"
    And I delete all announcements
    And I navigate to new announcement page
    And I uncheck "Student"
    And I uncheck "User"
    And I uncheck "Mentor"
    And I select "Immediately" from "announcement_email_notification"
    And I press "Save as draft"
    Then no email is sent
    Then I should see "The announcement has been saved."

    Then I should see "(No title)"
    And I should see "Draft"
    And I should see "Last Updated"
    When I click ".fa.fa-arrow-left"
    Then I should see "Drafted Announcements"
    And I should see "There are no published announcements."
    Then I logout

    #Non Admin users should not see drafted announcements
    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I should not see "(No title)"
    And I logout

    #Admin publishes a drafted announcement
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    And I navigate to announcements page
    When I follow "(No title)"
    Then I should see "Edit Announcement"
    And I follow "Discard Draft"
    Then I should see "Are you sure you want to discard this announcement?"
    Then I confirm popup
    And I follow "Create a New Announcement"
    When I press "Post"
    Then I should see "Please fill all the required fields. Fields marked * are required"
    Then I fill in "announcement_title" with "Drafted to Published"
    And I check "Student"
    And I fill in "announcements_expiry" with a date -1 days from now
    And I select "Immediately" from "announcement_email_notification"
    When I press "Post"
    Then I should see "The announcement has already expired. Do you still want to send email notifications?" within "div.modal-dialog"
    Then I follow "Send"
    When I open new mail
    Then I should see "Drafted to Published"
    Then I should see "The announcement has been published."
    And clear mail deliveries
    And I click ibox dropdown action inside "page_canvas"
    Then I follow "Edit"
    And I select "Immediately" from "announcement_email_notification"
    And I press "Update"
    Then I should see "The announcement has already expired. Do you still want to send email notifications?" within "div.modal-dialog"
    Then I follow "Don't send"
    Then no email is sent
    And I click ibox dropdown action inside "page_canvas"
    Then I follow "Edit"
    And I fill in "announcements_expiry" with a expiry date 20 days from now
    And I press "Update"
    Then I should not see "div.modal-dialog"
    And I should not see "(No title)"
    And I should see "Published"
    When I click ".fa.fa-arrow-left"
    Then I should see "Published Announcements"
    And I should see "There are no draft announcements."
    When I click ".fa.fa-trash"
    Then I should see "Are you sure you want to delete this announcement?"
    Then I cancel popup
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I should see "Drafted to Published"
    When I follow "Read full announcement"
    Then I follow back link
    And I should see "Drafted To Published"
    And I logout