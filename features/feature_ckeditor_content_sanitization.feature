@javascript
Feature: CKEditor Content Sanitization

  Background: Login with admin, superuser and enable sanitization version v2
    Given the current program is "primary":""
    And I Enable Version "v2"
    And I have logged in as "ram@example.com"
    And I login as super user

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Organization Edit
  When I follow "Manage"
  And I follow "Program Settings"
  And I click "#add_agreement_link"
  Then I should see "Source"
  Then I set the ckeditor content to "Agreement Content {{test}}<script>alert(1)</script>" with id "agreement_text"
  And I follow "Done"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I set the ckeditor content to "Agreement Content <script>alert(1)</script>" with id "agreement_text"
  And I follow "Done"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(1)</script>"
  Then I choose to ignore warning and proceed
  And I click "#add_privacy_link"
  Then I should see "Source"
  Then I set the ckeditor content to "Privacy Policy {{test}}<script>alert(2)</script><i class='fa fa-close'></i>" with id "privacy_text"
  And I follow "Done"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I click ".cke_button__source"
  Then I set the ckeditor content to "Privacy Policy <script>alert(2)</script><i class='fa fa-close'></i>" with id "privacy_text"
  Then I click ".cke_button__source"
  Then I click ".cke_button__source"
  And I follow "Done"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(2)</script>"
  Then I choose to ignore warning and proceed
  Then I should see element "i.fa.fa-close"
  Then I logout

Scenario: Admin cannot choose ignore and proceed to publish vulnerable content if organization security setting 'allow_vulnerable_content_by_admin' is set to false
  When I follow "Manage"
  And I set organization backend setting "security_setting.allow_vulnerable_content_by_admin" to "false"
  And I follow "Program Settings"
  And I click "#add_agreement_link"
  Then I should see "Source"
  Then I set the ckeditor content to "Agreement Content {{test}}<script>alert(1)</script>" with id "agreement_text"
  And I follow "Done"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I set the ckeditor content to "Agreement Content <script>alert(1)</script>" with id "agreement_text"
  And I follow "Done"
  Then I should see "Warning: Presence of Insecure content"
  Then I should see "Show Vulnerable Content"
  And I should not see "Ignore warnings and publish content"
  Then  I click "a.cjs_insecure_content_proceed_actions"
  Then I logout

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Program Invitations
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  And I follow "Invitations"
  And I follow "Send Invites"
  Then I click "#edit-campaign-link-3"
  And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "{{test}}This is an invitation <script>alert(3)</script>"
  Then I press "Save"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(3)</script>"
  Then I choose to ignore warning and proceed

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Mailer::Templates, no validation for tags
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  And I follow "System Emails"
  When I select the "Matching and engagement" category
  And I follow "Customize"
  Then I set the ckeditor content to "Email Template <script>alert(5)</script> {{url_program}}" with id "mailer_template_source"
  And I click "input.btn-primary"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(5)</script>"
  Then I choose to ignore warning and proceed
  Then I logout

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Program Events
  And I stub chronus s3 utils
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  And I follow "Events"
  And I click "a.btn-large"
  When I click "#s2id_program_event_admin_view_id > .select2-choice"
  And I click on select2 result "All Users"
  And I fill in "program_event_title" with "Chronus Admin"
  And I fill in "program_event_location" with "Mountain View California"
  Then I set the content to "December 31, 2024" with id "new_program_event_form_date"
  Then I set the content to "12:15 am" with id "program_event_start_time"
  Then I set the content to "01:00 am" with id "program_event_end_time"
  Then I set the ckeditor content to "Program Event {{test}} <script>alert(6)</script>" with id "new_program_event_details"
  And I click "#publish_and_invite"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I set the ckeditor content to "Program Event <script>alert(6)</script>" with id "new_program_event_details"
  And I click "#publish_and_invite"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(6)</script>"
  Then I choose to ignore warning and proceed
  Then I visit Program Events Index page
  And I press "OK"
  And I follow "Chronus Admin"
  And I press "OK"
  And I follow "Edit Program Event"
  Then I wait for "2" seconds
  And I click "#publish_and_invite"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(6)</script>"
  Then I choose to ignore warning and proceed
  Then I logout

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Mailer::Widgets, no validation for tags
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  And I follow "System Emails"
  When I select the "Matching and engagement" category
  And I follow "customize" within "#email_tags"
  Then I set the ckeditor content to "Mailer Widget <script>alert(7)</script> {{url_program}}" with id "mailer_widget_source"
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(7)</script>"
  Then I choose to ignore warning and proceed
  Then I logout

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Resources
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  Then I visit Add a new resource
  Then I set the content to "This is a Resource Title" with id "resource_title"
  Then I set the ckeditor content to "Resource Content {{test}} <script>alert(8)</script>" with id "resource_content"
  And I click ".form-actions input"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I set the ckeditor content to "Resource Content <script>alert(8)</script>" with id "resource_content"
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(8)</script>"
  Then I choose to ignore warning and proceed
  Then I should see "Click here"
  And I scroll to bottom of page
  And I follow "This is a Resource Title" within "#page_canvas"
  And I press "OK"
  And I follow "Edit resource"
  Then I wait for "2" seconds
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(8)</script>"
  Then I click "a.cjs_insecure_content_proceed_actions"
  And I follow "This is a Resource Title" within "#page_canvas"
  And I follow "Edit resource"
  And I click ".form-actions input"
  And I follow "This is a Resource Title" within "#page_canvas"
  Then I logout

@cross_browser
Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Pages
  When I follow "Manage"
  Then I visit Add a new page Org Level
  Then I set the content to "This is an Org Page Title" with id "page_title"

  Then I set the ckeditor content to "Org Page Content {{test}} <script>alert(9)</script>" with id "program_overview_content"
  And I click ".form-actions input"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I set the ckeditor content to "Org Page Content <script>alert(9)</script>" with id "program_overview_content"
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(9)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  And I follow "Edit"
  Then I wait for "2" seconds
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(9)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Manage"
  Then I visit Add a new page Program Level
  Then I set the content to "This is an Program Page Title" with id "page_title"
  Then I set the ckeditor content to "Program Page Content <script>alert(10)</script>" with id "program_overview_content"
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(10)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  And I follow "Edit"
  Then I wait for "2" seconds
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(10)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  Then I logout
  
@cross_browser
Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Articles
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  Then I hover on tab "Advice"
  When I follow "Articles"
  And I follow "Write New Article"
  And I scroll and click the element "div#a_text" below my visibility
  And I set the article title to "My new article"
  And I set the general article content to "This is my new article created by admin {{test}} <script>alert(11)</script>"
  And I publish the article
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  And I set the general article content to "This is my new article created by admin <script>alert(11)</script>"
  And I publish the article
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(11)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  And I follow "Edit Article"
  Then I should see "Edit Article"
  And I wait for "2" seconds
  And I press "Update"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(11)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  And I click on profile picture and click "Sign out"
  Given I have logged in as "robert@example.com"

  Then I hover on tab "Advice"
  When I follow "Articles"
  And I follow "Write New Article"
  And I scroll and click the element "div#a_text" below my visibility
  And I set the article title to "My new article"
  And I set the general article content to "This is my new article created by user <script>alert(11)</script>"
  And I publish the article
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(11)</script>"
  And I click ".modal-header .close"
  And I set the general article content to "This is my new article created by user"
  And I publish the article
  And I follow "Edit Article"
  And I set the general article content to "This is my new article created by user <script>alert(12)</script>"
  And I press "Update"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(12)</script>"
  Then I choose to ignore warning and proceed
  Then I logout

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Announcements
  When I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Announcements"
  And I follow "Create a New Announcement"
  And I fill in "announcement_title" with "Announcement Title"
  And I select "Immediately" from "announcement_email_notification"
  Then I set the ckeditor content to "Test Message {{test}} <script>alert(13)</script>" with id "new_announcement_body"
  And I press "Post"
  Then I should see "Error: Tags can't be used"
  And I should not see "Warning: Presence of Insecure content"
  Then I click ".cjs_tags_content_proceed_actions"
  Then I set the ckeditor content to "Test Message <script>alert(13)</script>" with id "new_announcement_body"
  And I set the attachment field "post_attachment" to "pic_2.png"
  And I fill in "announcements_expiry" with a expiry date 20 days from now
  And I select "Immediately" from "announcement_email_notification"
  And I press "Post"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(13)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  Then I click ".btn.dropdown-toggle"
  And I follow "Edit"
  Then I wait for "2" seconds
  And I click ".form-actions input"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(13)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  Then I logout

#Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Campaign Message
#  When I follow "Manage"
#  And I follow "Albers Mentor Program"
#  And I follow "Manage"
#  And I follow "Email Campaigns"
#  And I follow "Create Campaign"
#  And I fill in "campaign_management_user_campaign_title" with "Campaign Title"
#  When I click "#s2id_campaign_admin_views > .select2-choice"
#  And I click on select2 result "All Mentors"
#  And I press "Create Campaign"
#  And I follow "Add New Email"
#  And I fill in "campaign_management_abstract_campaign_message_mailer_template_subject" with "New Campaign Message"
#  Then I set the ckeditor content to "Campaign Message <script>alert(14)</script>" with id "campaign_management_abstract_campaign_message_mailer_template_source"
#  And I press "Save"
#  Then I should see "Show Vulnerable Content"
#  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
#  Then I should see "<script>alert(14)</script>"
#  Then I choose to ignore warning and proceed
#  And I follow "New Campaign Message"
#  And I press "Save"
#  Then I should see "Show Vulnerable Content"
#  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
#  Then I should see "<script>alert(14)</script>"
#  Then I choose to ignore warning and proceed
#  Then I logout

Scenario: Show Vulnerable Content PopUp for CKEDITOR instances in Mentoring Model Facilitation Templates
  Then I enable "mentoring_connections_v2" feature as a super user
  And I login as super user
  And I follow "Manage"
  And I follow "Albers Mentor Program"
  And I follow "Connection Plan Templates"
  And I follow "Create a New Template"
  And I fill in "cjs_title_field" with "New Mentoring Template with Vulnerability"
  And I press "Save and proceed to Configure Features »"
  And I press "Save and proceed to Add Content »"
  And I follow "Add a new action"
  And I follow "New Facilitation Message"
  Then I wait for ajax to complete
  Then I set the ckeditor content to "New Facilitation Message {{test}} <script>alert(16)</script>" with id "mentoring_model_facilitation_template_message"
  And I press "Save Message"
  And I should not see "Warning: Presence of Insecure content"

  Then I set the ckeditor content to "New Facilitation Message <script>alert(16)</script>" with id "mentoring_model_facilitation_template_message"
  And I press "Save Message"
  Then I should see "Show Vulnerable Content"
  And I click "div.modal-body div.cjs_insecure_warning_content_show_hide_container a"
  Then I should see "<script>alert(16)</script>"
  Then I choose to ignore warning and proceed
  And I press "OK"
  Then I logout