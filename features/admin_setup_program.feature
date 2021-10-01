@setup_program

Feature: Setup a mentor program
In order to setup a mentor program
As an admin
I want to create the program and set the mentoring connections method and the mentoring connection style

# XXX: This test is really slow. Identify the root cause and fix this

@javascript
Scenario: Create Basic Organization
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I should see "What would you like to call 'Mentor' in the program?"
  And I should see "What would you like to call 'Mentee' in the program?"
  And the text field "program_mentor_name" in "div#app_landing" should have value "Mentor"
  And the text field "program_student_name" in "div#app_landing" should have value "Mentee"
  And I select "Basic" from "program_organization_subscription_type"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then "#program_engagement_type_1" should not be visible
  Then "#program_engagement_type_2" should not be visible
  Then I press "Setup Program"
  And I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  And I check "cjs_mentee_can_request_mentor"
  #Mentee Request Administrator
  Then I choose "program_mentor_request_style_1"
  Then "#program_allow_one_to_many_mentoring_true" should not be visible
  Then "#program_allow_one_to_many_mentoring_false" should not be visible
  Then page should not have css "program_allow_one_to_many_mentoring_false"
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  And I should not see "Forums" within "#manage"
  And I follow "Program Settings"
  And I should not see "Terms & Conditions" within "#program_form"
  And I should not see "Permissions"
  And I should see "Connection Settings"
  And I follow "Connection Settings"
  Then "#program_allow_one_to_many_mentoring_true" should not be visible
  Then "#program_allow_one_to_many_mentoring_false" should not be visible
  Then I should see "One-on-one"
  And I should see "Membership"
  And I follow "Matching Settings"
  Then the disabled "program_engagement_type" checkbox_id should be checked
  #Then the "program_enabled_features_" checkbox_id should not be checked
  When I follow "Manage"
  Then I should see "Connections"
  When I follow "Connections"
  Then I click on dropdown toggle within "#title_actions"
  Then I should see "Find a Mentor"
  Then I logout

@javascript
Scenario: Create a Preferred Program with Premium Subscription
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I select "Premium" from "program_organization_subscription_type"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then "#program_engagement_type_1" should be visible
  Then "#program_engagement_type_2" should be visible
  Then I choose "program_engagement_type_1"
  Then I check "program_engagement_type"
  Then I press "Setup Program"
  And I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  And I check "cjs_mentee_can_request_mentor"
  #Mentee Request Administrator
  Then I choose "program_mentor_request_style_1"
  And I choose "program_allow_one_to_many_mentoring_true"
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  And I should see "Forums" within "#manage"
  Then I should see "Membership Requests"
  And I follow "Program Settings"
  And I should see "Terms & Conditions" within "#program_form"
  Then I should see "Permissions"
  And I should see "Features"
  And I should see "Connection Settings"
  And I should see "Membership"
  And I follow "Matching Settings"
  Then the disabled "program_engagement_type" checkbox_id should be checked
  Then the "program_enabled_features_" checkbox_id should not be checked
  Then I should see "Mentees request administrator to assign mentors"
  Then I logout

@javascript
Scenario: Create a Mentee Request Mentor Program with One on One style Enterprise Subscription
  #Premium and Enterprise don't differ from UI, Enterprise customers can have SFTP, API access
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I select "Enterprise" from "program_organization_subscription_type"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then "#program_engagement_type_1" should be visible
  Then "#program_engagement_type_2" should be visible
  Then I choose "program_engagement_type_1"
  Then I check "program_engagement_type"
  Then I press "Setup Program"
  And I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  And I check "cjs_mentee_can_request_mentor"
  #Mentee Request Administrator
  Then I choose "program_mentor_request_style_0"
  And I choose "program_allow_one_to_many_mentoring_false"
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  And I should see "Forums" within "#manage"
  Then I should see "Membership Requests"
  And I follow "Program Settings"
  And I should see "Terms & Conditions" within "#program_form"
  Then I should see "Permissions"
  And I should see "Features"
  And I should see "Connection Settings"
  And I should see "Membership"
  And I follow "Matching Settings"
  Then the disabled "program_engagement_type" checkbox_id should be checked
  Then the "program_enabled_features_" checkbox_id should not be checked
  Then I should see "Mentees send mentoring requests to mentors"
  Then "#program_calendar_setting_allow_mentor_to_describe_meeting_preference" should not be visible
  Then "#program_calendar_setting_allow_mentor_to_configure_availability_slots" should not be visible
  Then I logout

@javascript
Scenario: Create Administrator account where the mentoring connections are made by admin only and the mentoring connection style is group.
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then I choose "program_engagement_type_1"
  Then I check "program_engagement_type"
  Then I press "Setup Program"
  And I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  And I choose "program_allow_one_to_many_mentoring_true"
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then the disabled "program_engagement_type" checkbox_id should be checked
  And the "program_enabled_features_" checkbox_id should not be checked
  And "#not_needed" should not be visible
  And the "program_mentor_request_style_0" checkbox_id should not be checked
  Then I logout

@javascript
Scenario: Create a One-Time Mentoring Program
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then I choose "program_engagement_type_1"
  Then I check "program_enabled_features_"
  Then I press "Setup Program"
  And I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  Then "#program_mentor_request_style_1" should not be visible
  Then "#program_allow_one_to_many_mentoring_true" should not be visible
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  Then I should see "Membership Requests"
  And I follow "Program Settings"
  And I should see "Terms & Conditions" within "#program_form"
  Then I should see "Permissions"
  And I should see "Features"
  And I should see "Connection Settings"
  And I should see "Membership"
  And I follow "Matching Settings"
  Then the "program_engagement_type" checkbox_id should not be checked
  Then the disabled "program_enabled_features_" checkbox_id should be checked
  Then "Mentees send meeting requests to mentors" should be visible
  Then "#program_calendar_setting_allow_mentor_to_describe_meeting_preference" should be visible
  Then "#program_calendar_setting_allow_mentor_to_configure_availability_slots" should be visible
  Then I logout

@javascript
Scenario: Create a Project Based Engagement
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then I choose "program_engagement_type_2"
  Then I press "Setup Program"
  Then I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  Then "#program_mentor_request_style_1" should not be visible
  Then "#program_allow_one_to_many_mentoring_true" should be visible
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  Then I should see "Membership Requests"
  And I follow "Program Settings"
  And I should see "Terms & Conditions" within "#program_form"
  Then I should see "Permissions"
  And I should see "Features"
  And I should see "Connection Settings"
  And I should see "Membership"
  And I follow "Matching Settings"
  Then I should see "Allow users to propose a connection"
  Then I logout

@javascript
Scenario: Super user should be able to set the sorting criteria for names - Sort by First Name or Last Name
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  And I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then I choose "program_engagement_type_1"
  Then I check "program_engagement_type"
  And I should see "Profile Questions CSV"
  And I fill in "program_organization_profile_questions" with file "files/profile_questions.csv"
  Then I press "Setup Program"
  And I should see "Program Details"
  And I should see "Create Administrator Account"
  And I should see "Complete Registration"
  And I fill in "member_email" with "admin@chronus.com"
  And I fill in "member_first_name" with "administrator"
  And I fill in "member_last_name" with "step"
  And I fill in "member_password" with "monkey"
  And I fill in "member_password_confirmation" with "monkey"
  Then I valdiate and give my consent for terms and conditions by clicking "Sign up"
  And I press "signup_btn"
  Then I wait for ajax to complete
  Then I should see "Complete Registration"
  Then I should see "Description"
  And I fill in "program_description" with "This is a program for IIT students"
  And I check "cjs_mentee_can_request_mentor"
  Then I choose "program_mentor_request_style_0"
  And I choose "program_allow_one_to_many_mentoring_true"
  And I should see "Sort users by"
  And I choose "program_sort_users_by_1"
  Then program setup session & host issue hack
  And I follow "Join"
  And I follow "Login"
  And I fill in "email" with "admin@chronus.com"
  And I fill in "password" with "monkey"
  And I press "Login"
  And I follow "Manage"
  And I follow "Program Settings"
  Then I should not see "Sort users by"
  Then I follow "Manage"
  Then I follow "Preview"
  Then I should see "Role"
  Then I check "Mentor"
  Then I check "Mentee"
  Then I follow "Preview"
  Then I wait for ajax to complete
  Then I should see "Basic Information"
  Then I should see "Name"
  Then I should see "Email"
  Then I should see "Work and Education"
  Then I should not see "Mentoring Profile"
  Then I should not see "Phone"
  Then I should see "Industry"
  Then I should see "Accounting"
  Then I should see "Describe you working industry"
  Then I logout

@javascript @cross_browser
Scenario: All mandatory fields check and adding invalid profile questions upload file
  Given default host
  And I login as super user
  And I should see "Term for Mentee"
  And I should see "Term for Mentor"
  Then I press "Setup Program"
  Then I should see "Please fill all the required fields. Fields marked * are mandatory"
  Then I close the flash
  Then I fill in "program_name" with "iit"
  And I fill in "program_organization_program_domain_subdomain" with "iit"
  And I fill in "program_mentor_name" with "Mentor"
  And I fill in "program_student_name" with "Mentee"
  And I choose "program_program_type_mentor"
  And I fill in "program_number_of_licenses" with "1000"
  And I choose "creation_way_0"
  Then I press "Setup Program"
  Then I should see "Please fill all the required fields. Fields marked * are mandatory"
  Then I choose radio button with id "program_engagement_type_1" within "div#cjs_program_engagement_type"
  And I scroll to bottom of page
  Then I press "Setup Program"
  Then I should see "Please select some mode of mentoring"
  Then I check "program_engagement_type"
  And I fill in "program_organization_profile_questions" with file "files/profile_questions_invalid.csv"
  Then I press "Setup Program"
  Then I should see "Error at line 2: Field Name can't be blank"