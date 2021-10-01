Feature: Mentor Check in Report


@javascript @cross_browser
  Scenario: Create a new mentor check in, filter and verify
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I enable "contract_management" feature as a super user
    Then I enable "mentoring_connections_v2" feature as a super user
    And I login as super user
    And I follow "Manage"
    And I follow "Mentoring Connection Plan Templates"
    And I follow "Edit"
    Then I follow "CONFIGURE FEATURES"
    And I check "cjs_mentoring_model_admin_manage_mm_milestones"
    And I press "Save and proceed to Add Content »"
    And I should see "Add New Goal"
    When I click ".cjs_add_new_goal"
    And I should see "Add New Goal" within "div#remoteModal"
    And I fill in "mentoring_model_goal_template_title" with "Divergent"
    And I press "Save" within "#remoteModal"
    
    When I click "#cjs_add_milestone_template"
    And I should see "Add Custom Milestone" within "div#remoteModal"
    And I fill in "cjs_milestone_template_form_title_" with "Level 1"
    And I press "Save" within "#remoteModal"
    
    Then I should see "Level 1"
    And I follow "Expand or Collapse" within ".cjs_milestone_template_entity"

    When I click ".add-action-opener"
    And I follow "New Task"
    
    And I fill in "mentoring_model_task_template_title" with "Pass the simulation"
    And I assign the task to "Mentor"
    And I check "mentoring_model_task_template_required"
    And I align the task to the goal "Divergent"
    And I press "Save Task"
    Then I should see "Pass the simulation"
    And I follow "Manage"
    And I follow "Mentoring Connections"
    Then I should see "Ongoing"
    And I follow "Ongoing"
    And I follow "Create New Mentoring Connection"
    And I fill in "mentor" field of "primary":"albers" with "Good unique name <robert@example.com>"
    And I fill in "student" field of "primary":"albers" with "student example <rahim@example.com>"
    And I click "#create_and_publish"
    Then I should see "name & example"
    And I logout

    And I have logged in as "robert@example.com"
    Then I follow "name & example"
    Then I should see "Pass the simulation"
    And I click ".cjs_expand_mentoring_model_task"
    Then I click on dropdown toggle within ".cjs-edit-content-header"
    And I follow "Check-in" within ".cjs-edit-content-header"
    Then I wait for ajax to complete
    And I checkin with the following details "0","30"
    Then I should see "checked in"
    Then I should see "30 minutes"
    Then I should see "checked in 30 minutes"
    Then I reload the page
    Then I should see "00:30 hours" within ".cjs-connection-plan-container"
    And I logout

    When I have logged in as "ram@example.com"
    Then I follow "Health Reports" within "nav#sidebarLeft"
    Then I should see "Mentor Check-in Report"
    And I follow "Mentor Check-in Report"
    Then I should see "name & example"
    And I filter by checkins today for mentor checkin report
    Then I should see "name & example"

@javascript @download
  Scenario: Admin views mentor check in report
  # file format is wrong. will fix the download after that.
    Given the current program is "primary":"albers"
    And I clear the downloads folder
    And I have logged in as "ram@example.com"
    Then I follow "Health Reports" within "nav#sidebarLeft"
    Then I should not see "Mentor Check-in Report"
    Then I enable "contract_management" feature as a super user
    Then I follow "Health Reports" within "nav#sidebarLeft"
    Then I should see "Mentor Check-in Report"
    And I follow "Mentor Check-in Report"
    Then I should see "Mentoring Connection"
    #And I click "#check_in_csv"
    
    # Then I wait for download to complete
   # Then the csv header must have the fields "Mentor,Mentoring Connection,Date,Time,Type,Comment,Title"
   # Then the csv must have the following row
   # | Mentor               | Good unique name         |
   # | Mentoring Connection | name & madankumarrajan |
   # | Time                 | 0.5                      |
   # | Type                 | Meeting                  |
   # | Title                | Arbit Daily Topic        |