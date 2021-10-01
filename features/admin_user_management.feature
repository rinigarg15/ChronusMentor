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

@javascript @cross_browser
Scenario: Admin does bulk actions
  Then I follow "Manage"
  And I follow "User Views"
  And I should not see "Student" in the row "ct_admin_view_checkbox_3"
  And I should not see "Administrator" in the row "ct_admin_view_checkbox_3"
  And I click on "cjs_add_role" in Actions
  Then I should see "Please select at least one user"
  Then I hide the Actions
  #Add role
  Then I check "cjs_admin_view_primary_checkbox"
  And I click on "cjs_add_role" in Actions
  Then I should see "What additional roles would you like to assign"
  And I check "Student"
  And I press "Submit"
  Then I wait for "2" seconds
  Then I should see "The selected roles have been successfully added to the selected users in the program"
  Then I should see "Student" in the row "ct_admin_view_checkbox_3"
  Then I check "ct_admin_view_checkbox_3"
  And I click on "cjs_add_role" in Actions
  Then I should see "What additional roles would you like to assign"
  And I check "Administrator"
  And I press "Submit"
  Then I should see "The selected roles have been successfully added to the selected users in the program"
  Then I should see "Administrator" in the row "ct_admin_view_checkbox_3"

  #Add Tags
  And I follow "Good unique"
  Then I should not see "tag1" in "tags_section"
  Then I follow "Manage"
  And I follow "User Views"
  Then I check "ct_admin_view_checkbox_3"
  And I click on "cjs_add_tags" in Actions
  Then I should see "Add Tags"
  And I fill in tag text area with "tag1"
  And I press "Submit"
  Then I should see "The following tags have been successfully added to the selected users in the current view tag1"
  And I follow "Good unique"
  Then I should see "tag1" in "tags_section"
  Then I follow "Manage"
  And I follow "User Views"

  #Remove Tags
  Then I check "ct_admin_view_checkbox_3"
  And I click on "cjs_remove_tags" in Actions
  Then I should see "Remove Tags"
  Then I should see "Only the tags selected above will be removed and other tags existing for the user will be retained"
  And I fill in tag text area with "tag1"
  And I press "Submit"
  Then I should see the flash "The following tags have been successfully removed from users selected in the current view tag1"
  And I follow "Good unique"
  Then I should not see "tag1" in "tags_section"
  Then I follow "Manage"
  And I follow "User Views"  

  #Remove User
  Then I filter table by "first_name" with "mentor_e"
  Then I should see "mentor_e"
  Then I check "ct_admin_view_checkbox_29"
  And I should see "mentor_4@example.com"
  And I click on "cjs_remove_from_program" in Actions
  Then I should see "Remove User"
  Then I should see "Removal of users is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from the program permanently."
  Then I should see "Deactivate User" button
  And I press "Remove User"
  Then I should see "The selected users have been removed from the program successfully"
  And I should not see "mentor_4@example.com"

  #Send Message
  Then I check "ct_admin_view_checkbox_3"
  And I click on "cjs_send_message" in Actions
  And I fill in "admin_message_subject" with "An admin view subject"
  And I fill in CKEditor "admin_message_content" with "An admin view message"
  And I press "Send"
  Then I should see "Your message has been sent"
  And I logout
  When I have logged in as "robert@example.com"
  Given "1" last "message" exist
  And I follow "Messages"
  And I follow "My Messages"
  Then I should see "Freakin Admin (Administrator)"
  Then I should see "An admin view subject - An admin view message"
  And I logout

@javascript
Scenario: Admin Deactivates a user
  #Suspend Membership
  Then I follow "Manage"
  And I follow "User Views"
  Then I check "ct_admin_view_checkbox_5"
  And I click on "cjs_suspend_membership" in Actions
  And I fill in "admin_view_reason" with "A reason"
  And I press "Submit"
  Then I should see "The selected users membership have been deactivated from the program"
  When I visit the profile of "mentrostud@example.com"
  Then I should see "Mentor Studenter's membership has been deactivated from this program."
  And I logout

@javascript
Scenario: Admin does bulk actions
  Then I follow "Manage"
  And I follow "User Views"

  #Export to CSV
  Then I check "cjs_admin_view_primary_checkbox"
  # There is no method to use both @javasript and check response-header for file
  # So check just click on 'cjs_export_csv'
  # https://groups.google.com/forum/#!topic/ruby-capybara/xg88j4bvDZM
  And I click on "cjs_export_csv" in Actions

@javascript
Scenario: Resend Sign up Instructions
  Given I reset the password for member with email "robert@example.com"
  When I follow "Manage"
  And I follow "User Views"
  Then I check "ct_admin_view_checkbox_3"
  And I click on "cjs_resend_signup_instr" in Actions
  Then I should see "Sign up instructions will be sent to the following user:"
  And I press "Submit"
  Then I should see "The signup instructions for the selected user has been sent successfully"
  When I open new mail
  Then I should see "" in the email text part body
  Then I should see "Welcome to Albers Mentor Program! We look forward to your participation." in the email text part body
  And I follow "Complete Sign Up" in the email
  And I should see "Sign up with Password"

@javascript
Scenario: Admin adds a new view for organization
  Given the current program is "primary":""
  Then I follow "Manage"
  And I follow "Member Views"
  And I should see "Update View"
  And I click "#clicked-title-admin-view"
  And I should see "Create a new view"
  Then I follow "Create a new view"
  Then I should see "New View"
  And I fill in "admin_view_title" with "Global View"
  Then I follow "Next »"
  Then I click view
  And I check "admin_view_member_status_state_2"
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I press "Create View"
  Then I should see "The View - Global View has been created successfully"
  And I should see "No members were found in the current view. You can try the following."
  Then I follow "Update View"
  Then I click view
  And I check "admin_view_member_status_state_0"
  And I select "About Me" from "admin_view[profile][questions][questions_1][question]"
  And I select "Not Filled" from "admin_view[profile][questions][questions_1][operator]"
  And I follow "Add one more"
  Then I select "Location" from "admin_view_profile_questions_questions_2_question"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_2_operator"
  Then I select "City" from "admin_view_profile_questions_questions_2_scope"
  Then I click "#s2id_autogen4"
  Then I click on select2 result "Chennai"
  Then I select "Advanced filters" from "cjs-connection-status-filter-category-1"
  Then I select "Number of ongoing mentoring connections" from "cjs-connection-status-filter-type-1"
  Then I select "Greater than" from "cjs-connection-status-filter-operator-1"
  Then I fill in "cjs-connection-status-filter-countvalue-1" with "0"
  # Remove all
  And I click ".ui-icon-arrowthickstop-1-w"
  And I press "Update View"
  Then I should see "You need to select at least one field"
  And I click view
   # Add required columns
  Then I click by xpath "(//div[text()='Entire Education'])[last()]"
  Then I click by xpath "(//div[text()='Upload your Resume'])[last()]"
  Then I click by xpath "(//div[text()='About Me'])[last()]"
  Then I click by xpath "(//div[text()='Ongoing Engagements'])[last()]"
  Then I click by xpath "(//div[text()='Closed Engagements'])[last()]"
  And I press "Update View"
  Then I should see "Entire Education"
  Then I should see "Upload your Resume"
  Then I should see "Good unique"
  Then I should see "About Me"
  Then I should see "Ongoing Engagements"
  Then I should see "Closed Engagements"

@javascript @cross_browser
Scenario: Admin adds a new view
  Then I follow "Manage"
  And I follow "User Views"
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New View"
  And I fill in "admin_view_description" with "A New Description"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  And I check "admin_view_roles_and_status_state_suspended"
  And I check "admin_view_roles_and_status_signup_state_signed_up_users"
  And I should see "Users who have not signed up after being added to the program"
  And I should see "Users who have not signed up after being accepted into the program"
  And I should see "Users who have signed up"
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I press "Create View"
  Then I should see "The View - A New View has been created successfully"
  Then I should see "A New Description"
  And I should see "No users were found in the current view. You can try the following"
  And I click ".dropdown-title"
  And I should see "A New Description"
  Then I follow "Update View"
  Then I click view
  And I fill in "admin_view_description" with "An Updated Description"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I check "admin_view_roles_and_status_state_active"
  And I uncheck "admin_view_roles_and_status_state_suspended"
  And I uncheck "admin_view_roles_and_status_signup_state_signed_up_users"
  And I select "About Me" from "admin_view[profile][questions][questions_1][question]"
  And I select "Not Filled" from "admin_view[profile][questions][questions_1][operator]"
  And I follow "Add one more"
  Then I select "Location" from "admin_view_profile_questions_questions_2_question"
  Then I select "Contains Any Of" from "admin_view_profile_questions_questions_2_operator"
  Then I select "City" from "admin_view_profile_questions_questions_2_scope"
  Then I click "#s2id_autogen5"
  Then I click on select2 result "Chennai"
  And I select "Greater than" from "new_view_filter_profile_completeness_status"
  And I fill in "new_view_filter_profile_completeness_value" with "10"
  Then I click view
  And I press "Update View"
  Then I should see "An Updated Description"
  Then I should see "Good unique"
  Then I follow "Update View"
  Then I click view
  Then I check "admin_view_roles_and_status_signup_state_added_not_signed_up_users"
  And I press "Update View"
  Then I should see "Good unique"
  Then I follow "Update View"
  Then I click view
  Then I uncheck "admin_view_roles_and_status_signup_state_added_not_signed_up_users"
  Then I check "admin_view_roles_and_status_signup_state_signed_up_users"
  And I press "Update View"
  Then I should not see "Good unique"

@javascript @cross_browser
Scenario: Admin adds a new view with customized columns
  Then I follow "Manage"
  And I follow "User Views"
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New View"
  Then I follow "Next »"
  Then I click view
  Then I should not see "Draft Mentoring Connection Status"
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I click ".ui-icon-arrowthickstop-1-w"
  And I press "Create View"
  Then I should see "You need to select at least one field"
  Then I click by xpath "(//div[text()='Entire Education'])[last()]"
  Then I click by xpath "(//div[text()='Upload your Resume'])[last()]"
  Then I click by xpath "(//div[text()='T&C Accepted On'])[last()]"
  And I press "Create View"
  Then I should see "The View - A New View has been created successfully"
  Then I should see "Entire Education"
  Then I should see "Upload your Resume"
  Then I should see "Good unique"
  Then I should see "T&C Accepted On"
  Then I logout

@javascript
Scenario: Admin adds a new view with draft connections
  Given the current program is "primary":"albers"
  Then I follow "Manage"
  And I follow "User Views"
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Student"
  Then I should see "User's mentoring connection status"
  And I select "Advanced filters" from "admin_view[connection_status][status_filters][status_filter_1][category]"
  And I select "Number of drafted mentoring connections" from "admin_view[connection_status][status_filters][status_filter_1][type]"
  And I select "Greater than" from "admin_view[connection_status][status_filters][status_filter_1][operator]"
  And I fill in "admin_view[connection_status][status_filters][status_filter_1][countvalue]" with "0"
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I press "Create View"
  Then I should see "The View - A New View has been created successfully"
  Then I should see "drafted-user@chronus.com"
  Then I should see "student_1@example.com"
  And I should not see "mkr@example.com"

  And I follow "Update View"
  Then I click view
  Then I should see "User's mentoring connection status"
  And I select "Advanced filters" from "admin_view[connection_status][status_filters][status_filter_1][category]"
  And I select "Number of drafted mentoring connections" from "admin_view[connection_status][status_filters][status_filter_1][type]"
  And I select "Less than" from "admin_view[connection_status][status_filters][status_filter_1][operator]"
  And I fill in "admin_view[connection_status][status_filters][status_filter_1][countvalue]" with "1"
  And I press "Update View"
  Then I should see "The View - A New View has been updated successfully"
  Then I should not see "drafted-user@chronus.com"
  Then I should not see "student_1@example.com"
  And I should see "mkr@example.com"
  Then I logout