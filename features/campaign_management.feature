Feature: Campaign Management

Background: Admin logs in and enabled Campaign Management Feature
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I login as super user
  

@javascript @not_run_on_jenkins
Scenario: Admin lists all campaigns
  And I follow "Manage"
  Then I follow "Email Campaigns"
  Then I dismiss campaign management report tour
  Then I should see "Create Campaign"

  When I follow "Active (2)"
  Then I should see "Active (2)" within "#campaigns-result li.active"
  And I should see "Stopped (4)"
  And I should not see "Stopped (4)" within "#campaigns-result li.active"
  And I should see "Drafted (2)"
  And I should not see "Drafted (2)" within "#campaigns-result li.active"
  And I should see "Campaign1 Name (4 emails)"
  And I should not see "Campaign4 Name (2 emails)"

  When I follow "Stopped (4)"
  Then I should see "Active (2)"
  And I should not see "Active (2)" within "#campaigns-result li.active"
  And I should see "Stopped (4)" within "#campaigns-result li.active"
  And I should not see "Campaign1 Name (4 emails)"
  And I should see "Campaign4 Name (2 emails)"

  @javascript @cross_browser @not_run_on_jenkins
  Scenario: Create new Email Campaign
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    And I follow "Active (2)"
    And I follow "Campaign1 Name"
    And I press "Got it" within "div#step-0"
    Then I follow "Add New Email"
    And I fill in "campaign_management_abstract_campaign_message_mailer_template_subject" with "Complete your profile"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Complete Your profile with appropriate information"
    Then I set the campaign message duration as "-2"
    Then I press "Save"
    Then I should see the flash "Duration must be greater than 0."
    And I fill in "campaign_message_duration" with "1000"
    Then I press "Save"
    Then I should see "Complete your profile"
    Then I should see "Sent after 1000 days"




@not_run_on_tddium @not_run_on_jenkins
@javascript
  Scenario: Check if back links are working
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    Then I should see "Create Campaign"

    When I follow "Active (2)"
    Then I should see "Campaign1 Name"
    Then I follow "Campaign1 Name"
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Email Stats"
    And I should see "Add New Email"
    Then I follow "Got it" within "div#step-0"
    And I click ".btn.btn-primary.btn-large.dropdown-toggle"
    And I should see "Edit"
    And I follow "Edit"
    Then I should see "Edit Campaign: Campaign1 Name"
    When I click ".select2-choice"
    Then I should see "Create a new view"
    When I follow "Create a new view"
    Then I should see "Create New View"
    When I follow the back link
    Then I should see "Edit Campaign: Campaign1 Name"

    When I follow the back link
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Stats"
    And I should see "Email Stats"
    And I should see "Add New Email"

    Then I follow "Campaign Message - Subject1"
    Then I should see "Edit Campaign: 'Campaign1 Name'"
    When I follow the back link
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Email Stats"
    And I should see "Add New Email"

    Then I click ".k-alt"
    Then I should see "Edit Campaign: 'Campaign1 Name'"
    When I follow the back link
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Email Stats"
    When I follow "Campaign Message - Subject1"
    Then I should see "Edit Campaign: 'Campaign1 Name'"
    When I follow the back link
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Email Stats"
     Then I follow "Add New Email"
    Then I should see "New Campaign: 'Campaign1 Name'"
    When I follow the back link
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Stats"
    And I should see "Email Stats"
    And I should see "Add New Email"

    Then I follow the back link
    Then I should see "Create Campaign"

@not_run_on_tddium @not_run_on_jenkins
@javascript
  Scenario: Create Campaign, Add Email, Update Email, Add one more email, Delete Email, Edit Campaign, Activate Campaign, Disable Campaign, Destroy Campaign
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    Then I should see "Create Campaign"
    Then I follow "Create Campaign"
    Then I should see "New Campaign"
    Then I press "Create Campaign"

    When I click ".select2-choice"
    Then I should see "Create a new view"
    When I follow "Create a new view"
    Then I should see "Create New View"
    When I follow the back link
    Then I should see "New Campaign"
    And I should see "Campaigns are used to send emails to people who meet the conditions you select. When you 'Start' a campaign, we'll start to look for people and begin sending them emails on the schedule you choose."

    Then I fill in "Campaign Name" with "Test's Campaign\"
    Then I fill in "To" with "All"
    Then I should see "All Mentors"
    Then I click "#adminview_15"

    Then I should see "24"
    Then I press "Create Campaign"
    Then I should see "Test's Campaign\"
    And I should see "Add an Email"

    Then I follow "Add an Email"
    And I reload the page
    Then I fill in "Subject" with "Test's Subject\"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Test Message"

    When I fill in a number field "#campaign_message_duration" with "12"
    Then I should see "Insert Variables"
    And I click on "Insert Variables"
    Then I click "#cjs_preview_email_link"
    Then I should see "A test email has been sent to ram@example.com"
    And a mail should go to "ram@example.com" having "Test Message"

    Then I press "Save"
    Then I should see "The email has been successfully created."
    And I reload the page
    And I should see "Test's Subject\"
    And I should see "Sent after 12 days"

    Then I follow "Test's Subject\"
    And I fill in "Subject" with "Updated Test Subject"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Updated Test Message"
    When I fill in a number field "#campaign_message_duration" with "4"
    Then I press "Save"

    Then I should see "The email has been successfully updated."
    And I should see "Sent after 4 days"
    And I should see "Updated Test Subject"

    And I follow "Add New Email"
    Then I fill in "Subject" with "Test Subject-2"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Test Message-2"
    When I fill in a number field "#campaign_message_duration" with "8"
    Then I press "Save"

    Then I should see "The email has been successfully created."
    And I should see "Updated Test Subject"
    And I should see "Test Subject-2"

    And I should see "Sent after 4 days"
    And I should see "Sent after 8 days"


    # Edit campaign
    Then I click ".btn.btn-primary.btn-large.dropdown-toggle"
    And I follow "Edit"
    And I should see "Campaigns are used to send emails to people who meet the conditions you select. When you 'Start' a campaign, we'll start to look for people and begin sending them emails on the schedule you choose."
    And I fill in "Campaign Name" with "Updated Test Campaign"
    And I press "Save"
    Then I should see "The campaign has been successfully updated."
    And I should see "Updated Test Campaign"

    # Deactivating & Activating Campaign
    And I click ".btn.btn-primary.btn-large.dropdown-toggle"
    And I should see "Disable"
    And I follow "Disable"
    And I confirm popup

    Then I should see "The campaign has been disabled."
    And I should see "Disabled"

    And I click ".btn.btn-primary.btn-large.dropdown-toggle"
    And I should see "Start"
    And I follow "Start"
    And I confirm popup

    Then I should see "The campaign is now active."

    And I click ".btn.btn-primary.btn-large.dropdown-toggle"
    Then I should see "" within ".divider"

    # Deleting active campaign
    And I click ".delete_user_campaign_action"
    Then I should see "You are about to delete the campaign Updated Test Campaign."
    And I should see " Deleting a campaign is an irreversible action leading to loss of analytics. Did you intend to disable the campaign instead?"
    And I should see "Disable Campaign"
    And I should see "Delete Campaign"
    And I should see "Cancel"
    Then I press "Disable Campaign"
    And I confirm popup
    Then I should see "The campaign has been disabled."
    And I should see "Disabled"

    # Deleting inactive campaign
    And I click ".btn.btn-primary.btn-large.dropdown-toggle"
    Then I should see "" within ".divider"
    And I click ".delete_user_campaign_action"
    Then I should see "You are about to delete the campaign Updated Test Campaign."
    And I should see " Deleting a campaign is an irreversible action leading to loss of analytics. Did you intend to disable the campaign instead?"
    And I should not see "Disable Campaign"
    And I should see "Keep Disabled"
    And I should see "Delete Campaign"
    And I should see "Cancel"
    And I press "Delete Campaign"
    Then I should not see "Updated Test Campaign"

    # Deleting a campaign message
    Then I follow "Active (2)"
    And I follow "Campaign1 Name"
    Then I should see "Campaign Message - Subject1"
    And I should see "Sent the same day"
    Then I should see "Campaign Message - Subject2"
    And I should see "Sent after 5 days"
    And I click ".cjs_campaign_stop_actions"
    And I confirm popup

    Then I should not see "Campaign Message - Subject1"

@javascript @not_run_on_jenkins
  Scenario: Check for overall analytics - if there are no analytics for the last 6 months (defualt timeframe)
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    And I follow "Active (2)"
    And I follow "Campaign1 Name"
    Then I should see "Campaign Message - Subject1"
    And I should see "40.0%"
    And I should see "5"

@javascript @not_run_on_jenkins @not_run_on_tddium
  Scenario: Delete a stopped campaign
  And I follow "Manage"
  Then I follow "Email Campaigns"
  Then I dismiss campaign management report tour
  And I follow "Stopped (4)"
  And I follow "Campaign4 Name"
  And I press "Got it" within "div#step-0"
  And I click ".btn.btn-primary.btn-large.dropdown-toggle"
  And I click ".delete_user_campaign_action"
  Then I should see "You are about to delete the campaign Campaign4 Name."
  And I should see " Deleting a campaign is an irreversible action leading to loss of analytics."
  And I press "Delete Campaign"    

@not_run_on_tddium
@javascript @not_run_on_jenkins 
  Scenario: Check for Range of Duration
    And I follow "Manage"
    Then I follow "Email Campaigns"
   Then I dismiss campaign management report tour
    Then I should see "Create Campaign"
    Then I follow "Create Campaign"
    Then I should see "New Campaign"
    Then I should not see campaign email link
    Then I should not see campaign information link
    Then I press "Create Campaign"

    Then I fill in "Campaign Name" with "Test Campaign"
    Then I fill in "To" with "All"
    Then I should see "All Mentors"
    Then I click "#adminview_15"

    Then I should see "24"
    Then I press "Create Campaign"

    Then I follow "Add New Email"
    Then I fill in "Subject" with "Test Subject"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Test Message"
    When I fill in a number field "#campaign_message_duration" with "-1"

    Then I should see "Insert Variables"
    And I click on "Insert Variables"
    Then I click "#cjs_preview_email_link"
    Then I should see "A test email has been sent to ram@example.com"
    Then I press "Save"

    Then I should not see "The campaign has been successfully setup and made active."

    When I fill in a number field "#campaign_message_duration" with "181"
    Then I should see "Insert Variables"
    And I click on "Insert Variables"
    Then I click "#cjs_preview_email_link"
    Then I should see "A test email has been sent to ram@example.com"
    Then I press "Save"

    Then I should not see "The campaign has been successfully setup and made active."

@not_run_on_tddium @not_run_on_jenkins
@javascript
  Scenario: Check for valid tags and syntax of email tags
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    Then I should see "Create Campaign"
    Then I follow "Create Campaign"
    Then I should see "New Campaign"
    Then I should not see campaign email link
    Then I should not see campaign information link
    Then I press "Create Campaign"

    Then I fill in "Campaign Name" with "Test Campaign"
    Then I fill in "To" with "All"
    Then I should see "All Mentors"
    Then I click "#adminview_15"

    Then I should see "24"
    Then I press "Create Campaign"

    Then I follow "Add New Email"
    Then I fill in "Subject" with "Hello {{user_firstname}"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Hi {{user_firstname}}"

    Then I should see "Insert Variables"
    And I click on "Insert Variables"
    Then I click "#cjs_preview_email_link"
    Then I should see "Subject contains invalid syntax, donot apply any styles to the tags in subject"
    Then I press "Save"
    Then I should see "Please fix the highlighted errors."
    Then I should see "contains invalid syntax, donot apply any styles to the tags in subject"

    Then I fill in "Subject" with "Hello {{user_firstname}}"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Hi {{user_firstname}"
    Then I click "#cjs_preview_email_link"
    Then I should not see "A test email has been sent to ram@example.com"
    #the next two lines are part of single message but seperated because of 'within' keyword in the error message.
    Then I should see "Body contains invalid syntax, donot apply any styles"
    Then I should see "flower braces of the tag"
    Then I press "Save"
    Then I should see "Please fix the highlighted errors."

    Then I fill in "Subject" with "Hello {{invalid_subject_tag}}"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Hi {{invalid_source_tag}}, welcome to {{invalid_source_tag2}}"
    Then I click "#cjs_preview_email_link"
    Then I should see "Subject contains invalid tags - {{invalid_subject_tag}} and Body contains invalid tags - {{invalid_source_tag}}, {{invalid_source_tag2}}"
    Then I press "Save"
    Then I should see "Please fix the highlighted errors."
    Then I should see "contains invalid tags - {{invalid_subject_tag}}"
    Then I should see "contains invalid tags - {{invalid_source_tag}}, {{invalid_source_tag2}}"

    Then I fill in "Subject" with "Hello {{user_firstname}}"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Hi {{user_firstname}}"
    Then I click "#cjs_preview_email_link"
    Then I should see "A test email has been sent to ram@example.com"
    Then I press "Save"
    Then I should see "The email has been successfully created."
    And I should see "Hello {{user_firstname}}"
    And I should see "Sent the same day"

@not_run_on_tddium
@javascript @not_run_on_jenkins
Scenario: Removing Add Users button from admin view
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    Then I should see "Create Campaign"
    Then I follow "Create Campaign"
    Then I should see "New Campaign"
    Then I should not see campaign email link
    Then I should not see campaign information link
    Then I press "Create Campaign"

    Then I fill in "Campaign Name" with "Test Campaign"
    Then I fill in "To" with "All"
    Then I should see "All Mentors"
    Then I click "#adminview_15"

    Then I should see "24"

    Then I follow "View Users"
    Then I should not see "Add Users"

@javascript @not_run_on_jenkins
Scenario: Admin should see the tour of campaigns listing page
  And I follow "Manage"
  Then I follow "Email Campaigns"
  And I should see "Welcome to the Campaign Management Dashboard" within "#campaign-management-tour-modal"
  And I should see "Campaigns are used to send emails to people who meet the conditions you select. When you 'Start' a campaign, we'll start to look for people and begin sending them emails on the schedule you choose." within "#campaign-management-tour-modal"
  And I should see "Our rich analytics tool helps you gain insights to make your Campaigns more effective. You can use open and click-through rates to fine tune your campaigns, and help you achieve the desired goals of your mentoring program." within "#campaign-management-tour-modal"
  Then I should see "Take a tour"
  And I follow "Take a tour"
  And I should see "Get started by creating a new campaign or ‘Start’ one of the campaigns in ‘Draft’ state. Do not forget to customize the email content to suit your program needs!"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Visit the detailed campaign-page to view analytics for the campaign, or make any updates - add more emails before you start, edit or delete a campaign."
  Then I click ".popover-navigation .btn-primary"
  And I should see "Switch between tabs to view your Drafted, Active and Stopped campaigns."
  Then I should see "Got it"
  Then I press "Got it" within "div#step-3"
  And I should see "Switch between tabs to view your Drafted, Active and Stopped campaigns" hidden
  And I reload the page
  And I should see "Welcome to the Campaign Management dashboard" hidden
  And I hover over class "cui-campaign-take-tour"
  Then I should see "Click here for a quick tour"
  And I click ".cui-campaign-take-tour"
  And I should see "Get started by creating a new campaign or ‘Start’ one of the campaigns in ‘Draft’ state. Do not forget to customize the email content to suit your program needs!"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Visit the detailed campaign-page to view analytics for the campaign, or make any updates - add more emails before you start, edit or delete a campaign"
  Then I click ".popover-navigation .btn-primary"
  And I should see "View quick open rates, click rates, and start date of your campaign before you dig deeper by visiting the detailed campaign page."
  Then I click ".popover-navigation .btn-primary"
  And I should see "Switch between tabs to view your Drafted, Active and Stopped campaigns."
  Then I should see "Got it"
  Then I press "Got it" within "div#step-3"
  And I should see "Switch between tabs to view your Drafted, Active and Stopped campaigns" hidden

@not_run_on_tddium @javascript @not_run_on_jenkins
Scenario: Admin should see the tour of campaigns details page
  And I follow "Manage"
  Then I follow "Email Campaigns"
  Then I dismiss campaign management report tour
  And I reload the page
  Then I should see "Create Campaign"
  And I should see "Campaign1 Name (4 emails)"
  Then I follow "Campaign1 Name"
  And I click ".cui-campaign-take-tour"
  And I should see "View a quick summary of all the emails in your campaign."
  Then I click ".popover-navigation .btn-primary"
  And I should see "Make edits to your campaign, delete or add new emails here. You can also temporarily disable a campaign so that no new emails are sent out."
  Then I should see "Got it"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Make edits to your campaign" hidden
  And I reload the page
  And I should see "View a quick summary of all the emails in your campaign" hidden

  And I hover over class "cui-campaign-take-tour"
  Then I should see "Click here for a quick tour"
  And I click ".cui-campaign-take-tour"
  And I should see "View a quick summary of all the emails in your campaign"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Make edits to your campaign, delete or add new emails here. You can also temporarily disable a campaign so that no new emails are sent out."
  Then I should see "Got it"
  Then I click ".popover-navigation .btn-primary"
  And I should see "View a quick summary of all the emails in your campaign" hidden

@not_run_on_tddium @not_run_on_jenkins
@javascript
Scenario: Admin should see the tour on campaign message new and edit page
  And I follow "Manage"
  Then I follow "Email Campaigns"
  And I reload the page
  Then I should see "Create Campaign"
  And I should see "Campaign1 Name (4 emails)"
  Then I follow "Campaign1 Name"
  And I reload the page
  Then I follow "Add New Email"

  And I should see "Choose who the email comes from. Select your name from the list of all program administrators to tell your users that the email has come from a trusted source"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Personalized emails have a higher chance of being read and acted on. Add custom variables to add that personal touch to your emails"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Decide when you want the emails to go out"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Take a quick peek of the email before sending it out to your users"
  Then I should see "Got it"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Take a quick peek of the email before sending it out to your users" hidden
  And I reload the page
  And I should see "Choose who the email comes from" hidden

  And I hover over class "cui-campaign-take-tour"
  Then I should see "Click here for a quick tour"
  And I click ".cui-campaign-take-tour"
  And I should see "Choose who the email comes from. Select your name from the list of all program administrators to tell your users that the email has come from a trusted source"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Personalized emails have a higher chance of being read and acted on. Add custom variables to add that personal touch to your emails"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Decide when you want the emails to go out"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Take a quick peek of the email before sending it out to your users"
  Then I should see "Got it"
  Then I click ".popover-navigation .btn-primary"
  And I should see "Take a quick peek of the email before sending it out to your users" hidden

@javascript @not_run_on_jenkins
  Scenario: SuperUser uploads a csv file
    And I login as super user
    And I follow "Manage"
    And I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    When I set the attachment field "campaign[template]" to "campaign_management/campaign_model_import.csv"
    And I press "Upload"
    And I confirm popup
    Then I should see "The Campaign template has been set up successfully from the template file"

@javascript @not_run_on_jenkins
  Scenario: Email level analytics
    And I follow "Manage"
    Then I follow "Email Campaigns"
   Then I dismiss campaign management report tour
    And I follow "Active (2)"
    And I follow "Campaign1 Name"
    Then I should see "Campaign Message - Subject1"
    And I should see "3"
    And I should see "66.7 %"
    And I should see "33.3 %"
    And I should see "Sent the same day"


@javascript @not_run_on_jenkins @not_run_on_tddium
  Scenario: Clone a stopped Campaign
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    And I follow "Stopped (4)"
    And I follow "Campaign4 Name"
    And I press "Got it" within "div#step-0"
    Then I should see "Campaign Message - Subject5"
    Then I should see "Campaign Message - Subject6"
    Then I follow "Duplicate"
    Then I should see "Duplicate Campaign"
    Then I wait for ajax to complete
    Then I fill in "Campaign Name" with "Clone Campaign"
    Then I press "Save as Draft"
    Then I should see "Campaign Message - Subject5"
    Then I should see "Campaign Message - Subject6"
    Then I should see "Start Campaign"
    And I should see "Clone Campaign"
    When I follow the back link
    And I follow "Stopped (4)"
    And I follow "Campaign4 Name"
    Then I follow "Duplicate"
    Then I should see "Duplicate Campaign"
    Then I fill in "Campaign Name" with "Clone Campaign active"
    Then I press "Start Campaign"
    Then I should see "Campaign Message - Subject5"
    Then I should see "Campaign Message - Subject6"
    Then I should not see "Start Campaign"
    And I should see "Clone Campaign active"

@javascript @not_run_on_jenkins
  Scenario: Start a drafted campaign
  And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    And I follow "Drafted (2)"
    Then I follow "Get users to sign up"
    Then I follow "Start Campaign"
    Then I should see "The campaign is now active."
    Then I should not see "Start Campaign"

@javascript @not_run_on_jenkins 
  Scenario: Start a drafted campaign while adding a new email
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I dismiss campaign management report tour
    And I follow "Drafted (2)"
    Then I follow "Get users to sign up"
    And I press "Got it" within "div#step-0"
    Then I follow "Add New Email"
    And I fill in "campaign_management_abstract_campaign_message_mailer_template_subject" with "Complete your profile"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Complete Your profile with appropriate information"
    When I hover over the info icon close to schedule input and verify info text
    Then I set the campaign message duration as "2"
    Then I press "Save"
    Then I should see "Do you want to start the campaign now?"
    Then I press "No, just save the email"
    Then I should see "The email 'Complete your profile' has been added to the campaign 'Get users to sign up'"
    And I should see "Start Campaign"
    Then I follow "Add New Email"
    And I fill in "campaign_management_abstract_campaign_message_mailer_template_subject" with "Complete your profile again"
    And I fill in CKEditor "campaign_management_abstract_campaign_message_mailer_template_source" with "Complete Your profile with appropriate information"
    Then I set the campaign message duration as "2"
    Then I press "Save"
    Then I should see "Do you want to start the campaign now?"
    Then I press "Yes"
    Then I should see "Congratulations on starting the 'Get users to sign up' campaign. You can track the effectiveness of the campaign on the campaign page."
    Then I should not see "Start Campaign"

@javascript @not_run_on_jenkins
  Scenario: Check if back links are working
    And I follow "Manage"
    Then I follow "Email Campaigns"
    Then I should see "Create Campaign"
    Then I dismiss campaign management report tour
    When I follow "Active (2)"
    Then I should see "Campaign1 Name"
    Then I follow "Campaign1 Name"
    Then I should see "Campaign1 Name"
    And I should see "Campaign Emails"
    And I should see "Overall Email Stats"
    And I should see "Emails Sent"
    And I should see "Email Stats"
    And I should see "Add New Email"
