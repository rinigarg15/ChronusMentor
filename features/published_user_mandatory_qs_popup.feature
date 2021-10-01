Feature: Published user fills mandatory qs popup

@javascript @cross_browser
  Scenario: Admin edits profile of end user without getting required field error
    Given the current program is "primary":"albers"
    And I have logged in as "ram@example.com"
    Then I mark "About Me" mandatory for mentors in "albers"
    Then I mark "Upload your Resume" mandatory for mentors in "albers"
    Then I logout
    Given "robert@example.com" has not answered "Upload your Resume"
    And I have logged in as "robert@example.com"
    Then I should see "Update Your Profile"
    Then I should see "New mandatory fields have been added to the Mentoring Profile section of the profile. Please fill them out to complete your profile."
    Then I should see "About Me"
    Then I press "Save & Proceed"
    Then I should see "Please fill the highlighted fields with appropriate values to proceed"
    Then I fill in "About Me" with "here"
    Then I press "Save & Proceed"
    Then I should see "Update Your Profile"
    Then I should see "New mandatory fields have been added to the More Information section of the profile. Please fill them out to complete your profile."
    Then I should not see "About Me"
    Then I should see "Upload your Resume"
    Then I press "Save & Proceed"
    Then I should see "Please fill the highlighted fields with appropriate values to proceed"
    And I set the attachment field with ".ajax-file-uploader" to "some_file.txt"
    And I wait for upload to complete
    Then I in "60" seconds should see "File was successfully scanned for viruses"
    Then I press "Save & Proceed"