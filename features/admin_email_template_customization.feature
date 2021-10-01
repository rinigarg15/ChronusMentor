Feature: Customize Email Templates
  In order change the email templates
  As an admin
  I want to customize email templates

  Background: Admin logs in
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"
    And I login as super user

  @javascript
  Scenario: Styles Widget should not be visible in editor
    And I login as super user
    And I follow "Manage"
    When I follow "System Emails"
    When I select the "Community" category
    And I follow "Customize"
    Then I hover over signature widget
    And I should see "Program signature"
    Then I should not see "{{widget_styles}}"
    When I press "Save"
    Then I should not see "{{widget_styles}}"

  @javascript @cross_browser
  Scenario: Email Template Change Status
    # Admin changes the status of an email template
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "System Emails"
    Then I should see the page title "System Emails"
    And I should see the tab "Manage" selected

    When I select the "General Administration" category
    And the email template "AnnouncementNotification" cannot be disabled
    And I press "Save"
    Then I should see the flash "The email has been successfully updated"
    Then I close the flash

    And I follow "Manage"
    And I follow "System Emails"
    When I select the "Community" category
    When I "disable" the email template "ArticleCommentNotification"
    Then the email template "ArticleCommentNotification" should be "disabled"
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I follow "Advice"
    When I follow "Articles"
    Then I should see articles listed

    When I follow "Australia Kangaroo extinction"
    When I post a new comment "Hi howdy"
    Then "0" email should be triggered
    And I logout

    Given the current program is "primary":""
    When I have logged in as "ram@example.com"
    And I login as super user
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "Community" category
    Then the email template "ArticleCommentNotification" should be "disabled"
    When I "enable" the email template "ArticleCommentNotification"
    Then the email template "ArticleCommentNotification" should be "enabled"
    And I logout

    Given the current program is "primary":"albers"
    When I have logged in as "rahim@example.com"
    Then I follow "Advice"
    When I follow "Articles"
    Then I should see articles listed

    When I follow "Australia Kangaroo extinction"
    # The article has 3 watchers. So, 3 emails will be delivered
    When I post a new comment "Wassup in life"
    Then "3" email should be triggered

  @javascript
  Scenario: Disabling a feature should not show related emails
    Then the feature "articles" should be "enabled" for "primary"
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "System Emails"
    When I select the "Community" category
    Then I should see "New comment notification to followers of an article"

    #The admin disbales the article feature
    Then I disable the feature "articles" as a super user
    # Email lsiting page is at program level. So, need to go to the program page.
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "System Emails"
    When I select the "Community" category
    Then I should not see "New comment notification to followers of an article"

  @javascript @p2
  Scenario: Email Preview
    # Admin changes the status of an email template
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    And I follow "Click here"
    Then I should see "The test email has been sent successfully to your email address"
    Then a mail should go to "ram@example.com" having "You have a message"

  @javascript @cross_browser
  Scenario: Go to email page and press save then the template object shouldn't have subject/source
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    And I choose "mailer_template_enabled_false"
    And I press "Save"
    And I see that the subject and source are both nil in the template object
    And I choose "mailer_template_enabled_true"
    And I press "Save"
    And I see that the subject and source are both nil in the template object
    And I logout

    @javascript @cross_browser
    Scenario: Go to email page, edit subject and press save then the template object should have both source and subject
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    Then I fill in "mailer_template_subject" with "XYZ"
    Then I trigger change event on "mailer_template_subject"
    And I press "Save"
    And I see that only the source is not nil in the template object
    And I logout

  @javascript
  Scenario: Go to email page, edit subject and press save then the template object should have both source and subject
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    Then I fill in CKEditor "mailer_template_source" with "XYZ"
    And I press "Save"
    Then I should see "XYZ" in the ckeditor "mailer_template_source"
    And I see that only the subject is not nil in the template object
    And I logout

  @javascript
  Scenario: Verifying rollout popup actions from index page
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    Then I fill in CKEditor "mailer_template_source" with "XYZ"
    And I press "Save"
    And I enable rollout for organization "primary"
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    
    Then I should see "A new content update is now available! This update includes new and improved subject lines and content for your program emails. Would you like to move to the new content?"
    Then I should see "XYZ" 
    Then I follow "Keep current content"
    Then I should see "XYZ" in the ckeditor "mailer_template_source"
    Then I should not see "A new content update is now available! This update includes new and improved subject lines and content for your program emails. Would you like to move to the new content?"
    Then I delete all rollout entries
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
   
    Then I should see "A new content update is now available! This update includes new and improved subject lines and content for your program emails. Would you like to move to the new content?"
    Then I click ".cui-rollout-popup-header .close"
    Then I should see "XYZ" in the ckeditor "mailer_template_source"
    Then I should not see "A new content update is now available! This update includes new and improved subject lines and content for your program emails. Would you like to move to the new content?"
    Then I delete all rollout entries
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    
    Then I should see "A new content update is now available! This update includes new and improved subject lines and content for your program emails. Would you like to move to the new content?"
    Then I follow "Update content"
    Then I should not see "XYZ"
    Then I should not see "A new content update is now available! This update includes new and improved subject lines and content for your program emails. Would you like to move to the new content?"

  @javascript @cross_browser
  Scenario: Verifying rollout popup actions from show page
    And I follow "Manage"
    And I follow "System Emails"
    When I select the "General Administration" category
    And I follow "Customize"
    Then I should not see "At any time, you can switch to the default content provided by the system. Preview the new content."
    Then I fill in CKEditor "mailer_template_source" with "XYZ"
    And I press "Save"
    Then I close the flash
    Then I should see "XYZ" in the ckeditor "mailer_template_source"
    Then I should see "At any time, you can switch to the default content provided by the system. Preview the new content."
    Then I follow "Preview the new content"
    Then I should see "Updated Content" within "#remoteModal .cui-rollout-popup-content"
    Then I should see "Update content" within "#remoteModal"
    Then I follow "Keep current content"
    Then I should not see "Update content"
    Then I should see "XYZ" in the ckeditor "mailer_template_source"
    Then I should see "Preview the new content" within ".eamil_preview_link.cjs_email_rollout_link"
    Then I follow "Preview the new content"
    Then I should see "Updated Content" within "#remoteModal .cui-rollout-popup-content"
    Then I should see "Update content" within "#remoteModal"
    Then I close remote modal
    Then I should not see "Updated Content"

    Then I should see "Preview the new content" within ".eamil_preview_link.cjs_email_rollout_link"
    Then I follow "Preview the new content"
    Then I should see "Updated Content" within "#remoteModal .cui-rollout-popup-content"
    Then I should see "Update content" within "#remoteModal"
    Then I follow "Update content"
    Then I should not see "XYZ"
    Then I should not see "At any time, you can switch to the default content provided by the system. Preview the new content."

  @javascript @cross_browser
  Scenario: Removing vulnerable content when there are no changes in mail content
    When I follow "Manage"
    And I follow "System Emails"
    And I select the "General Administration" category
    And I follow "Customize"
    And I click ".cke_button__source_label"
    And I set the ckeditor content to "XYZ" with id "mailer_template_source"
    And I press "Save"
    And I close the flash
    Then I should see "XYZ" in the ckeditor "mailer_template_source"
    When I set the ckeditor content to "<script>alert(10)</script>" with id "mailer_template_source"
    And I press "Save"
    Then I should see "Warning: Presence of Insecure content"
    When I choose to ignore warning and proceed
    And I close the flash
    And I click ".cke_button__source_label"
    And I press "Save"
    Then I should see "Warning: Presence of Insecure content"
    When I click ".cjs_insecure_content_proceed_actions"
    And I click ".cke_button__source_label"
    Then I should not see "<script>alert(10)</script>"

   @javascript @cross_browser
   Scenario: Email Status Filter
    When I "disable" the email template "ArticleCommentNotification"
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "System Emails"
    Then I should see the page title "System Emails"
    And I should see the tab "Manage" selected
    When I select the "Community" category
    And I choose "Disabled"
    Then the email template "ArticleCommentNotification" should be "disabled"
    Then I should see "New comment notification to followers of an article"
    And I choose "Enabled"
    Then I should not see "New comment notification to followers of an article"
    And I logout

  @javascript @cross_browser
  Scenario: Email Customization Filter
    When I "disable" the email template "ArticleCommentNotification"
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "System Emails"
    Then I should see the page title "System Emails"
    And I should see the tab "Manage" selected
    When I select the "Community" category
    When I customize "ArticleCommentNotification" klass
    Then I hover over signature widget
    And I should see "Program signature"
    Then I fill in CKEditor "mailer_template_source" with "XYZ"
    And I press "Save"
    Then I follow back link
    And I choose "Customized Emails"
    Then I should see "New comment notification to followers of an article"
    And I choose "Non-customized Emails"
    Then I should not see "New comment notification to followers of an article"
    And I logout


  @javascript
  Scenario: Apply join related templates should be visible only when Chronus Auth is present
    And I follow "Manage"
    And I follow "Albers Mentor Program"
    And I follow "System Emails"
    And I follow "Enrollment and user management"
    Then I should see "Notification with instructions to a new user applying to join the program"
    And I should see "Notification with instructions to an existing user applying to join the program"
    And I should see "Notification to suspended member applying to join a new program"
    Then I remove "ChronusAuth" auth config for "primary"
    Then I create SAML Auth for "primary"
    And I reload the page
    Then I should not see "Notification with instructions to a new user applying to join the program"
    And I should not see "Notification with instructions to an existing user applying to join the program"
    And I should not see "Notification to suspended member applying to join a new program"