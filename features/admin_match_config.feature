Feature: Admin working with Match Configurations

@javascript @cross_browser
Scenario: Default value in match configs

  #Show match label shouldnt come for text questions

  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "New Config"
  Then I should see "Show match labels inside recommendation" within "#edit_match_config"
  Then I select "About Me" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I select "About Me" from "match_config_student_question_id" within "#edit_match_config"
  Then I should not see "Show match labels inside recommendation" within "#edit_match_config"
  Then I should not see "Set Matching"
  Then I should not see "Normal Matching"

  #Show match label should come for choice questions

  Then I select "Gender" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I should not see "Show match labels inside recommendation" within "#edit_match_config"
  Then I select "Industry interests" from "match_config_student_question_id" within "#edit_match_config"
  Then I should see "Show match labels inside recommendation" within "#edit_match_config"
  Then I should see "Set Matching"
  Then I should see "Normal Matching"
  Then I should not see "Match Label - Prefix" within "#edit_match_config"
  Then I choose "match_config_show_match_label_true" within "#edit_match_config"
  And I should see "Match Label - Prefix" within "#edit_match_config"
  And I fill in "match_config_prefix" with "Gender Prefix" within "#edit_match_config"
  And I press "Set Configuration"

  #Prefix value once reset and chosen not to show should not get retained after choosing Show match label again

  Then I should see "Gender" within "#match_configs"
  Then I should see "Industry interests" within "#match_configs"
  Then I follow "Edit" within "#match_configs"
  And I should see "Match Label - Prefix" within "#edit_match_config"
  Then I should see "Show match labels inside recommendation"
  Then I should see the radio button "match_config_show_match_label_true" selected
  Then I select "Work" from "match_config_mentor_question_id"
  And I should not see "Match Label - Prefix"
  And I should not see "Show match labels inside recommendation"
  Then I should see "Please select compatible question types"
  Then I follow "Cancel"
  Then I follow "Edit" within "#match_configs"
  Then I select "Gender" from "match_config_mentor_question_id" within "#edit_match_config"
  And I should see "Match Label - Prefix"
  And I should not see "Gender Prefix"
  Then I choose "match_config_show_match_label_true" within "#edit_match_config"
  Then I logout

@javascript @cross_browser
Scenario: Set Matching Preferences, Admin setting Threshold, Weights and Show match labels
  
  Given I unstub matching functions
  Given the current program is "primary":"albers"
  And I have logged in as "student_1@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select the option "Female" for the question "Gender"
  And I save the section "Mentoring Profile"
  Then I logout
  And I have logged in as "mentor_2@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select the option "Female" for the question "Gender"
  And I save the section "Mentoring Profile"
  Then I logout

  #Admin creating Match Config for Gender Question and setting threshold 1

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "New Config"
  Then I should see "Show match labels inside recommendation" within "#edit_match_config"
  Then I select "Gender" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I select "Location" from "match_config_student_question_id" within "#edit_match_config"
  Then I should see "Please select compatible question types"
  Then I select "Gender" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I should not see "Show match labels inside recommendation" within "#edit_match_config"
  Then I select "Gender" from "match_config_student_question_id" within "#edit_match_config"
  Then I should see "Show match labels inside recommendation" within "#edit_match_config"
  Then I should not see "Match Label - Prefix" within "#edit_match_config"
  Then I choose "match_config_show_match_label_false" within "#edit_match_config"
  Then I choose "Set Matching"
  Then I follow "Add new set"
  And I should see "Male" within "#s2id_mentee_choice_box_0_0"
  And I should see "Female" within "#s2id_mentee_choice_box_1_0"
  And I enter "Male" in "mentor_choice_box_0_0" autocomplete it with "Male"
  And I enter "Female" in "mentor_choice_box_1_0" autocomplete it with "Female"
  And I should not see "Match Label - Prefix" within "#edit_match_config"
  And I fill in "match_config_threshold" with "1"
  And I press "Set Configuration"
  Then I should see "Gender" within "#match_configs"
  Then I follow "Recompute Match Scores"
  Then I follow "Edit" within "#match_configs"
  And I should see "Male" within "#s2id_mentor_choice_box_0_0"
  And I should see "Male" within "#s2id_mentee_choice_box_0_0"
  And I should see "Female" within "#s2id_mentor_choice_box_1_0"
  And I should see "Female" within "#s2id_mentee_choice_box_1_0"
  Then I should see "1.0"
  Then I logout
  And I have logged in as "student_1@example.com"
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "100% match"
  Then I should not see "Show compatibility"
  Then I logout

  #Admin sets Show Match Label

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "Edit" within "#match_configs"
  Then I choose "match_config_show_match_label_true" within "#edit_match_config"
  And I should see "Match Label - Prefix" within "#edit_match_config"
  And I fill in "match_config_prefix" with "Gender Preferences - Male/Male and Female/Female" within "#edit_match_config"
  And I press "Set Configuration"
  Then I should see "Gender" within "#match_configs"
  Then I follow "Recompute Match Scores"
  Then I logout
  And I have logged in as "student_1@example.com"
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "Show compatibility"
  And I follow "Show compatibility"
  Then I should see "Female"
  Then I should see "Gender Preferences - Male/Male and Female/Female"  
  Then I close all modals
  Then I follow "Home"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select the option "Male" for the question "Gender"
  And I save the section "Mentoring Profile"
  Then I recompute match scores
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should not see "Show compatibility"
  Then I should see "Not a Match"
  Then I follow "Home"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I select the option "Female" for the question "Gender"
  And I save the section "Mentoring Profile"
  Then I recompute match scores
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "Show compatibility"
  Then I logout

  #Admin sets weight to -1

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "Edit" within "#match_configs"
  And I select "-1.00" from "match_config_weight"
  And I press "Set Configuration"
  Then I should see "Gender" within "#match_configs"
  Then I follow "Recompute Match Scores"
  Then I logout
  And I have logged in as "student_1@example.com"
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "10% match"
  And I follow "Show compatibility"
  Then I should see "Female"
  Then I should see "Gender Preferences - Male/Male and Female/Female"
  Then I logout
  Then I remove all match configs
  Then I recompute match scores
  Then I stub matching functions

@javascript @cross_browser
Scenario: Normal Matching Preferences, Admin setting Threshold, Weights and Show match labels
  
  Given I unstub matching functions
  Given the current program is "primary":"albers"
  And I have logged in as "student_1@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "I am the DANGER!"
  And I save the section "Mentoring Profile"
  Then I logout
  And I have logged in as "mentor_2@example.com"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "I am the DANGER!"
  And I save the section "Mentoring Profile"
  Then I logout  

  #Admin creating Match Config for About Me Question and setting threshold 1

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "New Config"
  Then I should see "Show match labels inside recommendation" within "#edit_match_config"
  Then I select "About Me" from "match_config_mentor_question_id" within "#edit_match_config"
  Then I should not see "Show match labels inside recommendation" within "#edit_match_config"
  Then I select "About Me" from "match_config_student_question_id" within "#edit_match_config"
  Then I should not see "Show match labels inside recommendation" within "#edit_match_config"
  Then I should not see "Match Label - Prefix" within "#edit_match_config"
  And I press "Set Configuration"
  Then I follow "Recompute Match Scores"
  Then I logout
  And I have logged in as "student_1@example.com"
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "100% match"
  And I should not see "Show compatibility"
  Then I follow "Home"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "DANGER!"
  And I save the section "Mentoring Profile"
  Then I recompute match scores
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "93% match"
  And I should not see "Show compatibility"
  Then I logout

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "Edit" within "#match_configs"
  And I fill in "match_config_threshold" with "1"
  And I press "Set Configuration"
  Then I follow "Recompute Match Scores"
  Then I logout
  And I have logged in as "student_1@example.com"
  Then I follow "Home"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "hello"
  And I save the section "Mentoring Profile"
  Then I recompute match scores
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "Not a Match"
  Then I follow "Home"
  And I follow "Edit Profile"
  And I click on the section with header "Mentoring Profile"
  And I fill the answer "About Me" with "I am the DANGER!"
  And I save the section "Mentoring Profile"
  Then I logout

  And I have logged in as "ram@example.com"
  And I login as super user
  Given the current program is "primary":"albers"
  Then I navigate to match_configs_path page
  Then I follow "Edit" within "#match_configs"
  And I select "-1.00" from "match_config_weight"
  And I fill in "match_config_threshold" with "1"
  And I press "Set Configuration"
  Then I follow "Recompute Match Scores"
  Then I logout
  And I have logged in as "student_1@example.com"
  When I navigate to "mentor_2@example.com" profile in "albers"
  Then I should see "10% match"
  Then I remove all match configs
  Then I recompute match scores
  Then I stub matching functions