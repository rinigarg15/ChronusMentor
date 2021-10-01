@reindex @manage_career_development @javascript

Feature: Manage Career Development Portals
  In order to setup a Career Development Portal
  I want to create a portal as Super Admin and manage the portal as admin

  Background:
    Given the current program is "nch":""
    And I perform missed migrations
    And I have logged in as "nch_admin@example.com"

  Scenario: Listing of Career Development Portals at global level
    And I follow "Manage"
    And I should see "Career Development Programs"
    And I should not see "New Program"
    And I should see "Primary Career Portal"
    And I disable the feature "career_development" as a super user
    And I follow "Manage"
    And I should not see "Career Development Programs"

  Scenario: Adding a member as Admin and Employee in Portal
    And I follow "Manage"
    And I follow "Member Views"
    And I follow "Mentee"
    Then I follow "Add User To Program"
    Then I should see "NCH Mentoring Program"
    And I enable "career_development" feature as a super user
    And I close all modals
    And I follow "Manage"
    And I follow "Member Views"
    And I follow "Mentee"
    Then I follow "Add User To Program"
    Then I should see "Primary Career Portal"
    Then I select "Primary Career Portal" from "admin_view_program_id"
    Then I should see "Employee"
    Then I check "Employee"
    Then I press "Submit"
    Then I should see "The selected user have been added to the program as Employee successfully"

    When I follow "Add User as Administrator"
    Then I select "Primary Career Portal" from "exisiting_user_to_program_admin_program_id"
    Then I press "Add"
    Then I should see "Nch Mentee has been added to the list of administrators"

  Scenario: Portal and Program listing in order
    When I enable "career_development" feature as a super user
    And I follow "Manage"
    And I follow "Member Views"
    Then I should see programs "Primary Career Portal, NCH Mentoring Program" in order inside kendo table
    Then I follow "Admin"
    Then I should see "Primary Career Portal" within "#profile_side_bar"
    Then I should see "NCH Mentoring Program" within "#profile_side_bar"
    Then I follow "Manage"
    And I follow "Customize"
    And I open section with header "Basic Information"
    Then I should see "2 Programs"

    When I go to programs page
    Then I should see "Welcome, Freakin Admin (Administrator)!"
    Then I should see "Primary Career Portal" within "#page_canvas"
    Then I should see "NCH Mentoring Program" within "#page_canvas"


    When I follow "Manage"
    Then I follow "Member Views"
    And I click "#clicked-title-admin-view"
    And I should see "Create a new view"
    Then I follow "Create a new view"
    Then I should see "Create New View"
    Then I fill in "Title" with "Test Admin View"
    Then I follow "Next »"
    Then I click view
    Then I should see "Program and Roles"
    Then I press "Advanced"
    And I should see "Primary Career Portal"
    And I should see "Employee"

    Then I logout
    Then I follow "Programs"
    Then I should see "Primary Career Portal" within "#program_list"
    Then I should see "NCH Mentoring Program" within "#program_list"

  Scenario: Create Career Development Portal at global level
    And I disable the feature "career_development" as a super user
    And I follow "Manage"
    And I should not see "Career Development Programs"
    And I enable "career_development" feature as a super user

    When I login as super user
    And I follow "Manage"
    And I should see "Career Development Programs"
    Then I should see "New Program" in Career Development Programs Pane
    And I should see "Primary Career Portal"

  Scenario: Listing of Career Development Portals at track level
    Given the current program is "nch":"portal"
    And I follow "Manage"
    And I should not see "Career Development Programs"

  Scenario: Creation of new Career Development Portal in standalone organization
    Then I logout
    Given the current program is "foster":""
    And I have logged in as "fosteradmin@example.com"
    Then I follow "Manage"
    And I should not see "Career Development Programs"
    Then I enable "career_development" feature as a super user
    And I login as super user
    Then I follow "Manage"
    And I should see "Career Development Programs"
    Then I should see "New Program"

  Scenario: Creation of new Career Development Portal in standalone organization
    Then I logout
    Given the current program is "foster":""
    And I have logged in as "fosteradmin@example.com"
    Then I follow "Manage"
    And I should not see "Career Development Programs"
    Then I enable "career_development" feature as a super user
    And I login as super user
    Then I follow "Manage"
    And I should see "Career Development Programs"
    Then I should see "New Program"
    And I follow "New Program" in Career Development Programs Pane
    Then I should see "Setup New Career Development Program"
    Then I follow "Next »"
    And I should see "Please fill all the required fields"
    Then I fill in "program_name" with "Faculty Development"
    Then I follow "Next »"
    And I fill in "org_name" with "NCH"
    And I press "Done"
    Then I should see the flash "The portal has been successfully setup!"

  @stub_cd_sub_domain
  Scenario: Export and import a program
    Given the current program is "nch":"portal"
    And I follow "Manage"
    Then I should see "Export Solution Pack" hidden
    When I login as super user
    Then I follow "Manage"
    Then I should see "Export Solution Pack"
    Then I follow "Export Solution Pack"
    Then I should see "Created by :"
    And I fill in "Created by :" with "Super User" within "#modal_export_solution_pack_popup_form"
    And I fill in "Description :" with "Testing Export for Portal" within "#modal_export_solution_pack_popup_form"
    And I press "Submit"
    Then I should see "Successfully Exported! Click here to view all the content packs."
    And I follow "Click here"
    And I should see "Testing Export for Portal"
    And I should see "Super User"
    And I should see "Download"
    When I follow "Nation Wide Children Hospital Org"
    And I follow "Manage"
    And I follow "New Program" in Career Development Programs Pane
    Then I should see "Name of the Program"
    And I fill in "Name of the Program" with "Solution Pack Import"
    And I choose "Use a solution pack"
    And I attach the exported pack to "career_dev_portal_solution_pack_file"
    And I press "Done"
    Then I should see "The solution pack was imported and the Program has been successfully setup!"

  Scenario: Listing of portals inside a mentoring program
    Given the current program is "nch":"main"
    And I give permission to admins in program "nch":"main"
    Then I create a career development portal for "Nation Wide Children Hospital Org"
    And I follow "Manage"
    Then I follow "Add Users"
    And I follow "Add users from Nation Wide Children Hospital Org"
    Then I should see "nch_admin2@example.com"
    And I should see "nch_employee@example.com"
    And I should see "Primary Career Portal"
    And I should see "Employee"
    Then I check "Employee"
    Then I should see "nch_employee@example.com"
    Then I should not see "nch_admin2@example.com"

  Scenario: Administrator should see Customize Contact Admin Setting inside general section
    Given the current program is "nch":"portal"
    And I follow "Manage"
    And I should not see "Customize Contact Administrator Setting"
    And I login as super user
    And I follow "Manage"
    And I should see "Customize Contact Administrator Setting" within ".cui-general-admin-setting"
    And I should not see "Connections" within "div"

    Given the current program is "nch":"main"
    And I logout
    And I have logged in as "nch_admin@example.com"
    When I follow "Manage"
    And I should not see "Customize Contact Administrator Setting"
    And I login as super user
    And I follow "Manage"
    And I should see "Customize Contact Administrator Setting" within ".cui-general-admin-setting"
    And I should not see "Customize Contact Administrator Setting" within ".cui-admin-connection-setting"
    And I should see "Connections"

  Scenario: End user should see tracks and protals in seperate sections
    Then I enable "enrollment_page" feature as a super user
    Given the current program is "nch":""
    Then I list all the programs
    Then I should find programs "Nation Wide Children Hospital Org, Primary Career Portal, NCH Mentoring Program, Browse Programs" in order in element "li.list-group-item"

    And I follow "Browse Programs"
    Then I should see "All Programs" within "#page_heading"
    And I should see "Career Development Program" within "#page_canvas"
    And I should see "Primary Career Portal" within "#page_canvas"
    And I should see "NCH Mentoring Program" within "#page_canvas"

    And I disable the feature "career_development" as a super user
    Given the current program is "nch":""
    Then I list all the programs
    And I should not see "Primary Career Portal" within ".cui_program_selector" 
    Then I should see "NCH Mentoring Program" within ".cui_program_selector"
    And I follow "Browse Programs"
    Then I should see "All Programs" within "#page_heading"
    And I should not see "Career Development Program" within "#page_canvas"
    And I should not see "Primary Career Portal" within "#page_canvas"
    And I should see "NCH Mentoring Program" within "#page_canvas"

  
 Scenario: The admin should see progrma and portals with title on resource creation page
    Given the current program is "nch":""
    Then I follow "Manage"
    Then I follow "Resources"
    Then I follow "Add new resource"
    And I should see "Career Development Program" within "#new_resource .white-bg"
    And I should see "Primary Career Portal" within "#new_resource .white-bg"
    And I should see "NCH Mentoring Program" within "#new_resource .white-bg"

