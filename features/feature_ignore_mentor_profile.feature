@javascript
Feature: Skip and Bookmark mentor profiles

Background:
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I enable "skip_and_favorite_profiles" feature as a super user
  And I enable "mentor_recommendation" feature as a super user
  And I logout

Scenario: Mentee ignores a mentor profile
  When I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  Then I should see "Ignore"
  Then I filter a mentor with name "mentor_j chronus" using quick find
  Then I follow "mentor_j chronus"
  Then I click ".cjs_ignore_feature"
  Then I should see the flash "mentor_j chronus's profile has been ignored. Click here to reconsider."
  Then I should see "Reconsider"
  Then I follow "here" within ".toast-message"
  Then I should see "Ignore"
  Then I should not see "Reconsider"
  Then I follow "Mentors"
  Then I filter a mentor with name "mentor_j chronus" using quick find
  Then I click ".cjs_ignore_feature" of mentor with email "mentor_9@example.com" in program "primary":"albers"
  Then I should see the flash "mentor_j chronus's profile has been ignored. Click here to reconsider."
  Then I should not see "Reconsider"
  Then I should not see "mentor_j chronus" within "div.listing"
  Then I follow "here" within ".toast-message"
  Then I should see "Ignore" of mentor with email "mentor_9@example.com" in program "primary":"albers"
  Then I should see "mentor_j chronus"

#Scenario: Mentee marks a mentor profile favorite from recommendations
  #Given "userrahim@example.com" user have no pending mentor requests in program "primary":"albers"
  #Given "userrahim@example.com" user is not part of any active connection in program "primary":"albers"
  #And The "userrahim@example.com" user has a published mentor recommendation in program "primary":"albers"
  #When I have logged in as "userrahim@example.com"
  #And I follow "Home"
  #Then I should see "Recommendations from administrator"
  #Then I should see "Kal Raman"
  #Then I should see "Ignore"

  #Then I ignore quick connect mentor recommendation with email "userram@example.com" in program "primary":"albers"
  #Then I should not see "Recommendations from administrator"
  #Then I should see the flash "Kal Raman's profile has been ignored. Click here to reconsider."
  #Then I should not see "Kal Raman" within "div#program_home"
  #Then I follow "here" within ".toast-message"
  #Then I should see "Recommendations from administrator"
  #Then I should see "Kal Raman"
  #Then I should see "Ignore"

Scenario: Mentee ignores a mentor and sees Ignored
  And I enable "skip_and_favorite_profiles" feature as a super user
  When I have logged in as "mkr@example.com"
  Then I follow "Mentors"
  Then I filter a mentor with name "Kal Raman" using quick find
  Then I follow "Kal Raman"
  Then I should see "Ignore"
  Then I click ".cjs_ignore_feature" 
  Then I should see "Reconsider"
  Then I should see "Ignored"
  Then I follow "here" within ".toast-message"
  Then I should not see "Ignored"
  Then I should see "90% match"
  Then I click ".cjs_ignore_feature" 
  Then I should see "Ignored"
  Then I should see "Reconsider"
  Then I click ".cjs_ignore_feature"
  Then I should not see "Ignored"
  Then I should see "90% match"