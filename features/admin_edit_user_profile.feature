Feature: Admin edits profile of end user

@javascript @cross_browser
  Scenario: Admin edits profile of end user without getting required field error
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Then I mark "Gender" mandatory for mentors in "albers"
    Then I follow "Students"
    Then I follow "Good unique name"
    Then I should see "Gender"
    Then I should not see "Male"
    Then I should not see "Female"
    Then I should not see "I am the DANGER!"
    Then I follow "Edit Good unique name's profile"
    And I follow "Actions"
    And I should see "View Profile"
    And I click on the section with header "Mentoring Profile"
    Then I should see "Gender"
    And I fill the answer "About Me" with "I am the DANGER!"
    And I save the section "Mentoring Profile"
    Then I should see the flash "Your changes have been saved"
    And I click on the section with header "Basic Information"
    And I fill in "member_first_name" with "My"
    And I press "submit_general"
    Then I should see the flash "Your changes have been saved"
    Then I follow "My name"
    Then I should see "Gender"
    Then I should not see "Male"
    Then I should not see "Female"
    Then I should see "I am the DANGER!"
    Then I logout

    Given the current program is "primary":"albers"
    And I have logged in as "robert@example.com"
    Then I should see "Update Your Profile"
    And I should see "New mandatory fields have been added to the Mentoring Profile section of the profile. Please fill them out to complete your profile." 
    Then I select "Male" from "profile_answers[9]"
    Then I press "Save & Proceed"
    Then I wait for "2" seconds
    # And I click on profile picture and click "Edit Profile"
    # And I follow "Actions"
    # Then I follow "View your Profile"
    And I visit the profile of "robert@example.com"
    Then I should see "Gender"
    Then I should see "Male"
    Then I should not see "Female"
    Then I should see "I am the DANGER!"
    And I follow "Actions"
    Then I follow "Edit your Profile"
    And I click on the section with header "Mentoring Profile"
    Then I should see "Gender"
    And I fill the answer "About Me" with "I am NOT the DANGER!"
    And I save the section "Mentoring Profile"
    And I click on the section with header "Basic Information"
    And I fill in "member_first_name" with "New"
    And I press "submit_general"
    Then I should see the flash "Your changes have been saved"
    Then I should see "New name"
    And I follow "Actions"
    Then I follow "View your Profile"
    Then I should see "Gender"
    Then I should see "Male"
    Then I should not see "Female"
    Then I should not see "I am the DANGER!"
    Then I should see "I am NOT the DANGER!"
    Then I logout