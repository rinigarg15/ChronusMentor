Feature: Themes/Appearance

Background: Admin logs in
    Given the current program is "primary":""
    And I have logged in as "ram@example.com"

@javascript @p2
Scenario: Use Theme as Admin
   And I login as super user
   And I follow "Manage"
   Then I should see "Program Branding"
   And I follow "Program Branding"
   Then I should see "Use theme"
   # Add Theme
   Then I follow "Add theme"
   Then I fill in "Theme name" with "My Theme"
   And I fill in "theme[css]" with file "files/test_file_1.css"
   Then I press "Add"
   Then I should see "My Theme (program specific)"

   # Edit lastly created theme
   Then I click by xpath "(//a[text()='Edit'])[last()]"
   Then I fill in "Theme name" with "My Theme Modified"
   And I fill in "theme[css]" with file "files/pic_2.png"
   Then I press "Save"
   Then I should see the flash "Please correct the below error(s) highlighted in red."
   Then I should see the flash "CSS File file type is wrong"
   Then I should see the flash "Vars list Important styles are missing."
   And I fill in "theme[css]" with file "files/test_file.css"
   Then I press "Save"
   Then I should see "My Theme Modified (program specific)"

   # Delete lastly created theme
   Then I click by xpath "(//a[text()='Delete'])[last()]"
   And I should see "Are you sure you want to delete this theme?"
   Then I confirm popup
   Then I should not see "My Theme Modified (program specific)"
   Then I logout

@javascript @p2
Scenario: Confirm popup at Organization Level
   And I login as super user
   And I follow "Manage"
   Then I should see "Program Branding"
   And I follow "Program Branding"
   Then I should see "Use theme"
   Then I follow "Use theme"
   Then I should see "Do you want to apply this theme to all programs?"
   Then I press "Yes"
