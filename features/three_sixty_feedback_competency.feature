@javascript @cross-browser
Feature: Admin Creating and Publishing Three Sixty Feedback Survey

Background: Admin logs in and enabled Required Features
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"  
  And I enable "three_sixty" feature as a super user
  
Scenario: Admin adding new competency + Open Ended Question
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Library"
  Then I should see "New Competency"
  And I follow "New Competency"
  Then I should see "New Competency"
  And I fill in "three_sixty_competency_title" with "Are you a good tester" 
  And I fill in "three_sixty_competency_description" with "Rates your testing skills" 
  And I press "Submit"
  And I should see "Are you a good tester"
  And I add a new question "Can you think through all cases" of type "Rating"
  And I should see "Can you think through all cases"
  And I add a new question "List corner cases" of type "Rating"
  And I should see "List corner cases"
  And I add a new question "Other Comments" of type "Text"
  And I should see "Other Comments"
  # Add new open ended question
  Then I fill in "three_sixty_open_ended_question_title_" with "What are your hobbies?"
  And I press "Save" within "div#add_new_three_sixty_open_ended_question_container"
  Then I should see "What are your hobbies?"
  #Edit OEQ
  Then I edit a question
  And I should see "Editing question text still associates all historical data to the new question. Are you sure you want to proceed?"
  And I confirm popup
  Then I edit the open ended question
  #Validate
  Then I follow "Surveys"
  And I follow "Edit"
  And I fill in "three_sixty_survey_expiry_date" with a date 20 days from now
  Then I press "new_three_sixty_survey_submit"
  Then I select "Are you a good tester" from "select_competency"
  And I press "Add to Survey"
  Then I should see "Can you think through all cases"
  Then I should see "List corner cases"
  And I should see "Other Comments"
  #OEQ
  Then I select "What are your hobbies? Prioritize them." from "select_oeq"
  Then I press "Add" within "#three_sixty_new_survey_oeq"
  And I should see "What are your hobbies? Prioritize them."
  # Add OEQ here:
  Then I follow "new_three_sixty_open_ended_question"
  Then I fill in "three_sixty_question[title]" with "List three of your strenghts"
  And I press "Save"
  And I should see "List three of your strenghts"
  Then I logout

Scenario: Admin editing existing competency/question
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Library"
  Then I click on the "fa-pencil" icon
  And I fill in "three_sixty_competency_title" with " " 
  Then I press "Submit"
  Then I should see /can't be blank/
  Then I fill in "three_sixty_competency_title" with "Ownership"
  Then I press "Submit"
  Then I should see "Ownership"
  Then I edit a question
  Then I should see "Editing question text still associates all historical data to the new question. Are you sure you want to proceed?"
  And I confirm popup
  And I click on the section with header "Team Work"
  And I fill in "three_sixty_question[title]" with "Team player?"
  Then I press "Save"
  Then I should see "Team player?"
  Then I logout

Scenario: Admin deleting existing competency/question
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Library"
  Then I delete "Decision Making" competency in primary
  And I should see /Deleting a competency deletes all questions \within\ the competency and any historical data associated with their answers. We do not recommend this. Are you sure you want to proceed/
  Then I confirm popup
  And I should not see "Decision Making"
  Then I follow "Team Work"
  Then I should see "Give an example to signify the ability to work in a team?"
  Then I delete a competency question
  Then I should see "Deleting a question deletes any historical data associated with their answers. We do not recommend this. Are you sure you want to proceed?"
  Then I confirm popup
  Then I should not see "Give an example to signify the ability to work in a team?"
  #OEQ
  And I should see "Things to stop doing"
  Then I delete an open ended question
  Then I should see "Deleting a question deletes any historical data associated with their answers. We do not recommend this. Are you sure you want to proceed?"
  Then I confirm popup
  Then I should not see "Things to stop doing"
  Then I logout