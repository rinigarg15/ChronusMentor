Feature: Admin sets a connection question to be displayed as connection summary.

Background: Set the program to albers
Given the current program is "primary":"albers"

@javascript @cross_browser
Scenario: Connection Question in Group Summary
  Given the current program is "primary":"pbe"
  And I have logged in as "ram@example.com"
  And pbe program has custom term
  And I login as super user
  Then I follow "Manage"
  And I follow "Customize Projects Profile Fields"
  And I follow "Add New Question"
  When I hover over "display_question_in_summary_setting_already_enabled_tooltip_new"
  Then I should not see "This option is already enabled for"
  And I should see "Display this profile field answer in project summary" within "div.display_question_in_summary_control"
  Then I hover over "info-circle" icon within "div.display_question_in_summary_setting_new"
  Then I should see "This option can be enabled for only one project profile field. Recommended to select this option for all but file type field."
  And I select "Upload File" from "common_question_type_new"
  And element with id "#display_question_in_summary_new" should be disabled
  And I select "Single line" from "common_question_type_new"
  And element with id "#display_question_in_summary_new" should not be disabled
  And I fill in "survey_question_question_text_new" with "Question1"
  Then I check "display_question_in_summary_new"
  And I press "Add"
  And I follow "Add New Question"
  And element with id "#display_question_in_summary_new" should be disabled
  And I select "Single line" from "common_question_type_new"
  When I hover over "display_question_in_summary_setting_already_enabled_tooltip_new"
  Then I should see "This option is already enabled for"
  Then I should see "Question1"
  Then I should see "Please uncheck the option to enable it here."
  And I fill in "survey_question_question_text_new" with "Question2"
  And I press "Add"
  Then I uncheck summary option from question with title "Question1"
  And I press "Save"
  And add as summary option should not be disabled for "Question2"
  And I press "Save"
  And I follow "Add New Question"
  And element with id "#display_question_in_summary_new" should not be disabled
  And I select "Single line" from "common_question_type_new"
  And I fill in "survey_question_question_text_new" with "Question3"
  Then I check "display_question_in_summary_new"
  And I press "Add"
  And add as summary option should be disabled for "Question2"
  And add as summary option should be disabled for "Question1"

@javascript @cross_browser
Scenario: Connection Question in Group Summary in home page widget is truncated
  Given the current program is "primary":"pbe"
  And I have logged in as "ram@example.com"
  And pbe program has custom term
  And I login as super user
  Then I follow "Manage"
  And I follow "Customize Projects Profile Fields"
  And I follow "Add New Question"
  And I should see "Display this profile field answer in project summary"
  Then I hover over "info-circle" icon within "div.display_question_in_summary_setting_new"
  Then I should see "This option can be enabled for only one project profile field. Recommended to select this option for all but file type field."
  And I select "Upload File" from "common_question_type_new"
  And element with id "#display_question_in_summary_new" should be disabled
  And I select "Single line" from "common_question_type_new"
  And element with id "#display_question_in_summary_new" should not be disabled
  And I fill in "survey_question_question_text_new" with "Question1"
  Then I check "display_question_in_summary_new"
  And I press "Add"
  And I follow "Manage"
  And I follow "Projects"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I should see "Project start date"
  And I fill in "Name" with "Todo App"
  And I fill in "Maximum number of students who can participate" with "3"
  And I fill connection summary question answer for question "Question1" as "Contrary to popular belief, Lorem Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur,Contrary to popular belief, Lorem Ipsum is not simply random text. It has roots in a piece of classical Latin literature from 45 BC, making it over 2000 years old. Richard McClintock, a Latin professor at Hampden-Sydney College in Virginia, looked up one of the more obscure Latin words, consectetur,"
  And I press "Save and Continue Later"
  And I follow "Manage"
  And I follow "Projects"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I should see "Project start date"
  And I fill in "Name" with "Todo App2"
  And I fill in "Maximum number of students who can participate" with "3"
  And I fill connection summary question answer for question "Question1" as "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book."
  And I press "Save and Continue Later"
  And I follow "Manage"
  And I follow "Projects"
  When I follow "Create New Project"
  Then I should be on new group page in primary:pbe program
  And I should see "Project start date"
  And I fill in "Name" with "Todo App3"
  And I fill in "Maximum number of students who can participate" with "3"
  And I fill connection summary question answer for question "Question1" as "here are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believablehere are many variations of passages of Lorem Ipsum available, but the majority have suffered alteration in some form, by injected humour, or randomised words which don't look even slightly believable"
  And I press "Save and Continue Later"
  Then I wait for "Group" Elastic Search Reindex
  Then I wait for "GroupStateChange" Elastic Search Reindex
  And I follow "Manage"
  And I follow "Projects"
  And I follow "Drafted"
  And I follow "Make Project Available"
  And I press "Make Project Available"
  And I follow "Make Project Available"
  And I press "Make Project Available"
  And I follow "Make Project Available"
  And I press "Make Project Available"
  And I logout
  And I have logged in as "rahim@example.com"
  And I should see "Todo App"
  And I should see "Todo App2"
  And I should see "...»" within "div.cjs_connection_description"
  And I follow "»" within "div.cjs_connection_description"
  And I should see "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book."
  And I should see "Todo App2"