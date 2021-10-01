Feature: Alert will be raised when the admin tries to update or delete the view.

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I maximize the window

@javascript @cross_browser
Scenario: Admin creates a new view, associates two metrics to it and then tries to delete the view.
  Then I follow "Manage"
  And I follow "User Views"
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New View"
  And I fill in "admin_view_description" with "A New Description"
  Then I follow "Next »"
  Then I click view
  And I should see "Users who have not signed up after being added to the program"
  And I should see "Users who have not signed up after being accepted into the program"
  And I should see "Users who have signed up"
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I press "Create View"
  Then I should see "The View - A New View has been created successfully"
  #And I follow "Home"
  #And I follow "Add New Report"
  #And I should see "New Report"
  #And I should see "Select a Report"
  #And I select "A New View" from "report_metric_abstract_view_id"
  #And I select "Membership" from "report_metric_section_id"
  #Then I press "Add"
  #And I should see "A New View"
  #Then I follow "Manage"
  #And I should see "Manage"
  #And I should see "User Views"
  #Then I follow "User Views"
  #And I click on the view "A New View"
  #And I should see "A New View"
  #And I should see "Update View"
  #And I click "#action_1 a.dropdown-toggle.btn-large"
  #Then I follow "Delete View" 
  #And I should see "Confirmation"
  #And I should see "This view is pinned to the Administrator Dashboard. Deleting this view will update the dashboard. Are you sure you want to delete this view ?"
  #And I confirm popup
  #And I should see "All Users"
  #And I should see "The View - A New View has been deleted successfully"
  Then I logout

@javascript @cross_browser
Scenario: Admin creates a new view, associates two metrics with it and then tries to update the view.
  Then I follow "Manage"
  And I follow "User Views"
  When I create a new view
  Then I should see "New View"
  And I fill in "admin_view_title" with "A New View"
  And I fill in "admin_view_description" with "A New Description"
  Then I follow "Next »"
  
  And I should see "Users who have not signed up after being added to the program"
  And I should see "Users who have not signed up after being accepted into the program"
  And I should see "Users who have signed up"
  Then I click view
  Then I follow "Next »"
  Then I should see "Select Fields to Display"
  Then I click view
  And I press "Create View"
  Then I should see "The View - A New View has been created successfully"
  #And I follow "Home"
  #And I follow "Add New Report"
  #And I should see "Select a Report"
  #And I should see "New Report"
  #And I select "A New View" from "report_metric_abstract_view_id"
  #And I select "Membership" from "report_metric_section_id"
  #Then I press "Add"
  #And I should see "A New View"
  #Then I follow "Manage"
  #And I should see "Manage"
  #And I should see "User Views"
  #Then I follow "User Views"
  #And I click on the view "A New View"
  #And I should see "A New View"
  #And I should see "Update View"
  #Then I follow "Update View" 
  #And I should see "Enter Details"
  #And I should see "Specify Filter Criteria"
  #And I should see "Select Fields to Display"
  #And I press "Update View"
  #And I should see "Confirmation"
  #And I should see "This view is pinned to Administrator Dashboard. Updating this view will update the dashboard. Alternatively, you can create a new view. Do you want to continue?"
  #And I confirm popup
  #And I should see "The View - A New View has been updated successfully"
  #And I should see "A New View"
  #Then I logout
