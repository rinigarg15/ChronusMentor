Feature: Superuser exports a program from an organization and creates a new organization out of the exported solution pack and verifies if things are fine.

@javascript @cross-browser
Scenario: Export and import a program
  Given the current program is "primary":"albers"
  When I have logged in as "ram@example.com"
  And I login as super user
  And I follow "Manage"
  And I follow "Export Solution Pack"
  Then I should see "Created by"
  And I fill in "Created by" with "Super User"
  And I fill in "Description" with "Testing the export"
  And I press "Submit"
  And I should see "Successfully Exported! Click here to view all the content packs."
  And I visit solution packs listing
  And I should see "Testing the export" 
  And I should see "Super User"
  And I follow "Primary Organization"
  And I follow "Manage"
  And I follow "New Program"
  And I fill in "Name of the Program" with "Solution Pack Import"
  And I follow "Next »"
  And I choose "Use a solution pack"
  And I attach the exported pack to "program_solution_pack_file"
  And I press "Done"
  Then I wait for "10" seconds
  Then I should see "The solution pack was imported and the Program has been successfully setup!"
