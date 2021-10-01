Feature: Connection Proposals

Background: I go to the appropriate pbe track in org:primary
  Given the current program is "primary":"pbe"
  And pbe program has custom term

@javascript @matching_scenario
Scenario: Admin visits the connection settings and configure some of the roles to empower them to propose projects
  When I cleanup the existing groups in rejected and proposed state
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I check "teacher" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I check "mentor" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  And I choose "propose_needs_approval_mentor_yes"
  And I choose "propose_needs_approval_teacher_yes"
  Then I press "Save"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  And I logout
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I should see "PROJECTS" within "ul.metismenu"
  And I follow "View Profile"
  And I follow "Ongoing projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I logout
  When I have logged in as "robert@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  And I follow "View Profile"
  And I follow "Ongoing projects"
  And I should see "Proposed" under group tabs
  And I should see "Rejected" under group tabs
  And I logout
  When I have logged in as "ram@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Manage"
  Then I follow "Projects"
  And I should see "Proposed" under group tabs
  And I should see "Rejected" under group tabs
  Then I follow "Manage"
  Then I follow "Program Settings"
  And I follow "Matching Settings"
  Then I uncheck "mentor" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I press "Save"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I follow "General Settings"
  Then I fill in "program_name" with "Liz Lemon - Walter-Skyler White"
  Then I press "Save"
  And I follow "Matching Settings"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I uncheck "teacher" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I press "Save"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I follow "Manage"
  Then I follow "Projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I logout
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Liz Lemon - Walter-Skyler White" from the program selector
  And I follow "View Profile"
  And I follow "Ongoing projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I logout
  When I have logged in as "ram@example.com"
  Then I hover over "my_programs_container"
  And I select "Liz Lemon - Walter-Skyler White" from the program selector
  Then I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I check "teacher" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I check "mentor" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I check "student" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  And I choose "propose_needs_approval_mentor_yes"
  And I choose "propose_needs_approval_teacher_yes"
  And I choose "propose_needs_approval_student_yes"
  Then I press "Save"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I follow "Manage"
  Then I follow "Projects"
  And I should see "Proposed" under group tabs
  And I should see "Rejected" under group tabs
  And I logout
  When I have logged in as "rahim@example.com"
  Then I hover over "my_programs_container"
  And I select "Liz Lemon - Walter-Skyler White" from the program selector
  And I follow "View Profile"
  And I follow "Ongoing projects"
  And I should see "Proposed"
  And I should see "Rejected"
  And I logout
  
@javascript @matching_scenario @cross-browser
Scenario: Mentor proposes a group and Admin Accepts making him Owner
  When I have logged in as "ram@example.com"
  And I login as super user
  Then I create messages enabled project template without task templates
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Allow proposer to set the start date of the project"
  Then I check "program_allow_circle_start_date"
  And I press "Save"
  When I enable end users to propose groups
  And I logout
  When I have logged in as "robert@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Propose a new project"
  Then the help text for "student" role in "primary":"pbe" should not be visible
  Then I press "Save"
  Then I should see "Please fill all the required fields. Fields marked * are required"
  Then I should see "Project Name"
  Then I fill in "similar_connection_name" with "Binge watch House of Cards"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  Then I press "Save"
  Then I should see the flash "The project proposal was successful. You will be notified once the administrator accepts your project."
  And I should see "Do you want to set a start date for your project?"
  And I should see "Congratulations! You will be notified once your project proposal gets accepted. When do you want to start your project?"
  And I select "January 25, 2020" for "#circle_start_date_form" from datepicker
  And I press "Set Start Date"
  And I should see "A start date has been set for the project."
  Then I should see "Add/Remove Owners"
  And I follow "Add/Remove Owners"
  Then I follow "Remove" within "#fetch_owners_form"
  Then I press "Update"
  Then I wait for "2" seconds
  And I should see "Your proposed project is awaiting acceptance from administrator. You will be notified once the administrator accepts your project."
  And I should see "Click here to explore other projects if you would like to join them."
  And I follow "My proposed projects"
  Then I should see "Projects" within "#page_heading"
  And I should see "Proposed (3)"
  Then I logout
  When I have logged in as "ram@example.com"
  When I open new mail
  Then I should see "Hi Freakin,Good unique name" in the email text part body
  Then I should see "has proposed a new project called Binge watch House of Cards" in the email text part body
  And I follow "View project" in the email
  Then I should see "Binge watch House of Cards"
  Then I should see "Please accept and make the project available for users."
  Then I follow "Accept & Make Available"
  Then I select "Messages enabled without task templates" from "assign_mentoring_model"
  Then I fill in "bulk_actions_message" with "Please go ahead and start working on it!!"
  Then I press "Accept & Make Available"
  Then I logout
  When I have logged in as "robert@example.com"
  When I open new mail
  Then I should see "Congratulations! We have accepted your proposed project" in the email text part body
  Then I should see "Please go ahead and start working on it!!" in the email text part body
  And I follow "Go to the project" in the email
  Then I should see "My Project"
  Then I should see "The project will start on January 25, 2020. You will be notified once it starts."
  Then I should not see "Click here to explore other projects if you would like to join them."
  Then I should see "Manage Members"
  Then I logout

@javascript @matching_scenario
Scenario: Mentor proposes a group and Admin Accepts but does not make him Owner
  When I have logged in as "ram@example.com"
  And I login as super user
  Then I create both disabled project template without task templates
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Allow proposer to set the start date of the project"
  Then I uncheck "program_allow_circle_start_date"
  And I press "Save"
  Then I logout
  When I enable end users to propose groups
  When I have logged in as "robert@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Propose a new project"
  Then the help text for "student" role in "primary":"pbe" should not be visible
  Then I fill in "similar_connection_name" with "Binge watch House of Cards"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  Then I press "Save"
  Then I should see the flash "The project proposal was successful. You will be notified once the administrator accepts your project."
  And I should not see "Do you want to set a start date for your project?"
  And I follow "My proposed projects"
  Then I should see "Projects" within "#page_heading"
  And I should see "Proposed (3)"
  Then I logout
  When I have logged in as "ram@example.com"
  When I open new mail
  Then I should see "Hi Freakin,Good unique name" in the email text part body
  Then I should see "has proposed a new project called Binge watch House of Cards" in the email text part body
  And I follow "View project" in the email
  Then I should see "Binge watch House of Cards"
  Then I follow "Accept & Make Available"
  Then I select "Both disabled without task templates" from "assign_mentoring_model"
  Then I fill in "bulk_actions_message" with "Please go ahead and start working on it!!"
  Then I press "Accept & Make Available"
  Then I should see "This project has not started yet. Publish the project for access to collaboration tools and resources. If you want, others may continue to find and join the project after it's published."
  Then I should see "Add/Remove Owners"
  And I follow "Add/Remove Owners"
  Then I follow "Remove" within "#fetch_owners_form"
  Then I press "Update"
  Then I wait for "2" seconds
  Then I logout
  When I have logged in as "robert@example.com"
  When I open new mail
  Then I should see "Congratulations! We have accepted your proposed project" in the email text part body
  Then I should see "Please go ahead and start working on it!!" in the email text part body
  And I follow "Go to the project" in the email
  Then I should see "My Project"
  Then I should see "This project has not started yet. You will be notified once it starts."
  Then I should see "Click here to explore other projects if you would like to join them."
  Then I should not see "Manage Members"
  Then I logout

@javascript @matching_scenario
Scenario: Mentor proposes a group and skip setting start date
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  Then I should see "Allow proposer to set the start date of the project"
  Then I check "program_allow_circle_start_date"
  And I press "Save"
  When I enable end users to propose groups
  And I logout
  When I have logged in as "robert@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Propose a new project"
  Then the help text for "student" role in "primary":"pbe" should not be visible
  Then I fill in "similar_connection_name" with "Binge watch House of Cards"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  Then I press "Save"
  Then I should see the flash "The project proposal was successful. You will be notified once the administrator accepts your project."
  And I should see "Do you want to set a start date for your project?"
  And I follow "Skip"
  Then I should see "Binge watch House of Cards" within "div#title_navig"

@javascript @matching_scenario
Scenario: Group proposals with no approval needed
  When I cleanup the existing groups in rejected and proposed state
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I check "teacher" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I check "mentor" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I press "Save"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  And I logout
  When I have logged in as "robert@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  And I follow "View Profile"
  And I follow "Ongoing projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I logout
  When I have logged in as "ram@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Manage"
  Then I follow "Projects"
  And I should see "Proposed" under group tabs
  And I should see "Rejected" under group tabs
  And I logout
  When I have logged in as "robert@example.com"
  Then I should see "Start a new project" within "ul.metismenu"
  Then I should not see "My proposed project" within "ul.metismenu"
  Then I follow "Start a new project" within "ul.metismenu"
  Then I should see "Start a New Project" within "div#page_heading"
  Then I fill in "similar_connection_name" with "Group creation without aprroval"
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  And I fill in "mentor" field with prefix "max_" of "primary":"pbe" with "3"
  Then I press "Save"
  Then I should see the flash "The project has been created successfully."
  And I follow "Skip"
  Then I should see "Publish Project"
  And I logout

@javascript @matching_scenario
Scenario: Showing similar circles inside connection creation
  When I cleanup the existing groups in rejected and proposed state
  When I have logged in as "ram@example.com"
  And I follow "Manage"
  Then I follow "Projects"
  And I should not see "Proposed"
  And I should not see "Rejected"
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Matching Settings"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I check "teacher" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I check "mentor" of "primary":"pbe" having idprefix as "program_send_group_proposals_"
  Then I press "Save"
  And I should see "Allow users to propose a project"
  Then I should see "mentor" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  Then I should see "student" of "primary":"pbe" with idprefix "program_send_group_proposals_" unchecked
  Then I should see "teacher" of "primary":"pbe" with idprefix "program_send_group_proposals_" checked
  And I logout
  When I have logged in as "robert@example.com"
  Then I hover over "my_programs_container"
  And I select "Project Based Engagement" from the program selector
  Then I follow "Start a new project" within "ul.metismenu"
  Then I should see "Start a New Project" within "div#page_heading"
  And I should see ".similar_circles_content" hidden
  Then I fill in "similar_connection_name" with "project"
  Then I should see "project_a" within "div.similar_circles_content"
  Then I should see "project_group" within "div.similar_circles_content"
  Then I should see "Here are similar projects. Explore and join instead of creating one." within "div.similar_circles_content"
  Then I follow "Join" within "div.similar_circles_listing"
  Then I switch to latest window
  Then I should see "project_a" within "div#page_heading"
  Then I close the new window and switch to main window
  Then I should see "project_group" within "div.similar_circles_content"
  And I click "#page_heading"
  And I should see ".similar_circles_content" hidden
  And I fill in "student" field with prefix "max_" of "primary":"pbe" with "3"
  And I fill in "mentor" field with prefix "max_" of "primary":"pbe" with "3"
  Then I press "Save"
  Then I should see the flash "The project has been created successfully."
  And I follow "Skip"
  Then I should see "Publish Project"
  And I logout
