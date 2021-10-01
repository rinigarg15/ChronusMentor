@javascript
Feature: Admin Creating and Publishing Three Sixty Feedback Survey

Background: Enable 360 Degree Survey Tool
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"  
  And I enable "three_sixty" feature as a super user
  Then I logout
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"

Scenario: Complete 360 Survey Workflow
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  Then I should see "360 Degree Surveys"
  And I follow "New Survey"
  #Settings
  And I fill in "three_sixty_survey_title" with "Young Leadership Survey" 
  And I fill in "three_sixty_survey_expiry_date" with a date 20 days from now
  And I choose "Assessees"
  Then I fill in "Line Manager" as reviewer group
  Then I fill in "Peer" as reviewer group
  Then I fill in "Direct Report" as reviewer group
  And I press "Proceed to Questions"
  #Define Questions
  Then I should see the flash "The survey has been successfully created. Please choose the competencies and questions you want for the survey."
  And I should see "Young Leadership Survey" 
  And I should see "Competencies & Questions"
  And I select "Leadership" from "select_competency"
  And I press "Add to Survey"
  And I select "Delegating" from "select_competency"
  And I press "Add to Survey"
  And I select "Team Work" from "select_competency"
  And I press "Add to Survey"
  And I follow "Preview »"
  #Preview
  And I should see "Young Leadership Survey"
  And I should see "Leadership"
  And I should see "Are you a leader?"
  And I should see "Do people blindly follow you?"
  And I should see "Do you often take responcibility?"
  Then I should see "Delegating"
  Then I should see "Do you tend to micromanage?"
  And I should see "Do you spread the work evenly among derect reports?"
  Then I should see "Team Work"
  And I should see "Give an example to signify the ability to work in a team?"
  And I follow "Add Survey Assessees »"

  #Participants Page
  And I should see "Assessees"
  And I type in "student" into autocomplete list "member_name_with_email" and I choose "student example" 
  And I press "Add"
  And I should see "student example"
  And I follow "Send"
  Then I should see "The survey 'Young Leadership Survey' has been successfully published and the assessees have been notified."
  And I should see "Young Leadership Survey"
  And I should see "student example"
  Then I update the threshold of reviewer group "Peer" with "0" in "primary"
  Then I update the threshold of reviewer group "Direct Report" with "0" in "primary"
  Then I logout

#Assessee Workflow
  When I have logged in as "rahim@example.com"  
  And I open new mail
  And I follow "Complete the survey" in the email
  Then I fill the survey
  Then I follow "Add Reviewer"
  Then I fill in "three_sixty_survey_reviewer[name]" with "Ashley"
  Then I fill in "three_sixty_survey_reviewer[email]" with "ashley@googlemail.com"
  And I select "Peer" from "three_sixty_survey_reviewer[three_sixty_survey_reviewer_group_id]"
  Then I press "Add"
  Then I follow "Send"
  Then I should see "Please add the minimum number of reviewers required for this survey."
  Then I follow "Add Reviewer"
  Then I fill in "three_sixty_survey_reviewer[name]" with "Charles"
  Then I fill in "three_sixty_survey_reviewer[email]" with "Babbage"
  And I select "Line Manager" from "three_sixty_survey_reviewer[three_sixty_survey_reviewer_group_id]"
  Then I press "Add"
  Then I should see "is not a valid email address"
  Then I fill in "three_sixty_survey_reviewer[email]" with "charles@googlemail.com"
  Then I press "Add"
  And I follow "Send"
  Then I should see "The reviewers you have added will be notified shortly."
  #Edit Survey + Validating Quicklink
  Then I go to the homepage
  And I follow "My Three Sixty Degree Surveys"
  And I follow "Young Leadership Survey"
  Then I fill the survey
  #Follow email link again
  Then I open mail of "rahim@example.com"
  And I follow "Complete the survey" in the email
  Then I should see "Young Leadership Survey"
  And I should see "Add Reviewers"
  And I should see "Ashley <ashley@googlemail.com>, Peer"
  And I should see "Charles <charles@googlemail.com>, Line Manager"
  And I should see "Edit Survey Response"
  Then I logout

  #Reviewers Workflow
  Then "ashley@googlemail.com" does the review
  Then I should not see "Your Details"
  Then "charles@googlemail.com" does the review
  Then I should not see "Your Details"

  #Admin checks response
  #TODO: Add validating the Report 
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"  
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  #Bug - Sphinx issue - the new survey is not loading
  #Then I should see "3/3"

  #Delete Published Survey
  #Bug - Sphinx issue - the new survey is not loading
  #Then I delete the survey "Young Leadership Survey"
  #Then I should see "This 360 Degree Survey has been published to an assessee and #multiple reviewers, who will be unable to access the survey once deleted. #Deleting the survey will also cause loss of feedback data. Are you sure you want #to proceed?"
  #And I confirm popup
  #Then I should not see "Young Leadership Survey"
  Then I logout

  Scenario: Edit and Publish a Drafted Survey + "Add Question" in "Define Questions"
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  And I follow "Edit"
  And I fill in "three_sixty_survey_expiry_date" with a date 20 days from now
  And I press "Proceed to Questions"
  Then I select "Leadership" from "select_competency"
  And I press "Add to Survey"
  Then I delete a competency question of drafted survey
  #Do you often take responcibility? 
  Then I should see "Are you sure you want to remove this question from the survey?"
  Then I confirm popup
  And I should see "Add Question"
  Then I follow "Preview"
  Then I should not see "Do you often take responcibility?"
  And I follow "Back to questions"
  Then I should not see "Do you often take responcibility?"
  Then I follow "Add Question"
  And I should see "Add Question" within "div#remoteModal"
  And I check "questions[]"
  And I press "Add" within "div.modal-dialog"
  Then I should see "Do you often take responcibility?"
  Then I follow "Preview"
  Then I should see "Do you often take responcibility?"
  And I follow "Add Survey Assessees"
  And I follow "Send"
  Then I should see "The survey 'Survey For Level 1 Employees' has been successfully published and the assessees have been notified."
  Then I logout

  Scenario: Delete Drafted Survey
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  Then I delete a drafted survey
  Then I should see "Are you sure you want to discard the survey?"
  And I confirm popup
  Then I should see "The drafted survey has been removed."
  Then I should not see "Survey For Level 3 Employees"
  #Discard at some step
  Then I follow "Edit"
  Then I follow "Discard Survey"
  And I should see "Are you sure you want to discard the survey?"
  And I confirm popup
  Then I should not see "Survey For Level 1 Employees"
  Then I logout

Scenario: Complete 360 Survey Workflow - Admin Adding reviewers
  And I follow "Manage"
  And I follow "360 Degree Survey Tool"
  Then I should see "360 Degree Survey"
  Then I update the threshold of reviewer group "Peer" with "2" in "primary"
  Then I update the threshold of reviewer group "Direct Report" with "2" in "primary"
  And I follow "New Survey"
  #Settings
  And I fill in "three_sixty_survey_title" with "Young Leadership Survey" 
  And I fill in "three_sixty_survey_expiry_date" with a date 20 days from now
  Then I fill in "Line Manager" as reviewer group
  Then I fill in "Peer" as reviewer group
  Then I fill in "Direct Report" as reviewer group
  And I press "Proceed to Questions"
  #Define Questions
  Then I should see the flash "The survey has been successfully created. Please choose the competencies and questions you want for the survey."
  And I should see "Young Leadership Survey" 
  And I should see "Competencies & Questions"
  And I select "Leadership" from "select_competency"
  And I press "Add to Survey"
  And I select "Delegating" from "select_competency"
  And I press "Add to Survey"
  And I select "Team Work" from "select_competency"
  And I press "Add to Survey"
  And I follow "Preview »"
  #Preview
  And I should see "Young Leadership Survey"
  And I should see "Leadership"
  And I should see "Are you a leader?"
  And I should see "Do people blindly follow you?"
  And I should see "Do you often take responcibility?"
  Then I should see "Delegating"
  Then I should see "Do you tend to micromanage?"
  And I should see "Do you spread the work evenly among derect reports?"
  Then I should see "Team Work"
  And I should see "Give an example to signify the ability to work in a team?"
  And I follow "Add Survey Assessees »"
  #Participants Page
  And I should see "Assessees"
  And I type in "student" into autocomplete list "member_name_with_email" and I choose "student example" 
  And I press "Add"
  And I should see "student example"
  #No threshold warning for admin
  Then I fill in "three_sixty_survey_reviewer[name]" with "Freakin Admin"
  Then I fill in "three_sixty_survey_reviewer[email]" with "ram@example.com"
  And I select "Line Manager" from "three_sixty_survey_reviewer[three_sixty_survey_reviewer_group_id]"
  Then I press "Add"
  Then I fill in "three_sixty_survey_reviewer[name]" with "Ashley"
  Then I fill in "three_sixty_survey_reviewer[email]" with "ashley@googlemail.com"
  And I select "Peer" from "three_sixty_survey_reviewer[three_sixty_survey_reviewer_group_id]"
  Then I press "Add"
  And I follow "Send"
  Then I should see "The survey 'Young Leadership Survey' has been successfully published and the assessees have been notified."
  And I should see "Young Leadership Survey"
  And I should see "student example"
  Then I should see "0 out of 3 have answered"
  Then I follow "Add Reviewers"
  Then I should see "Please add the reviewers who will evaluate student example for the survey 'Young Leadership Survey' "
  Then I follow "Add Reviewer"
  Then I should see "Select"
  Then I fill in "three_sixty_survey_reviewer[name]" with "Ashley"
  Then I fill in "three_sixty_survey_reviewer[email]" with "ashley@googlemail.com"
  And I select "Peer" from "three_sixty_survey_reviewer[three_sixty_survey_reviewer_group_id]"
  Then I press "Add"
  Then I should see "has already been added"
  Then I fill in "three_sixty_survey_reviewer[email]" with "ashleytest@googlemail.com"
  Then I press "Add"
  Then I follow "Send"
  Then I should see "The reviewers you have added will be notified shortly."
  Then I logout