Feature: Admin uses admin view language filtering

Background:
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And I login as super user
  And I have enabled "language_settings" feature

@javascript @cross_browser
Scenario: Admin adds the language column in member view, and does filtering and sorting at UI level
  Then I follow "Manage"
  Then I follow "Member Views"
  And I should not see "Language"
  Then I follow "Update View"
  Then I add language column
  Then I press "Update View"
  Then I should see "Language"
  Then I sort on language column
  And I should not see "Hindi"
  And I should not see "Telugu"
  Then I sort on language column
  And I should see "Telugu"
  And I should see "Hindi"
  Then I apply filter for language "Hindi"
  And I should see "Hindi"
  And I should not see "Telugu"
  Then I clear filter for language
  And I should see "Hindi"
  And I should see "Telugu"
  Then I apply filter for language "Telugu"
  And I should see "Telugu"
  And I should not see "Hindi"
  Then I logout

@javascript @cross_browser
Scenario: Admin creates a admin view with the language filtering in filter criteria at member level
  Then I follow "Manage"
  Then I follow "Member Views"
  Then I click "#clicked-title-admin-view"
  Then I click ".cjs_create_admin_view_link"
  And I fill in "admin_view_title" with "Language filter member view test"
  Then I follow "Next »"
  Then I should see "Language"
  Then I toggle language selection for "Hindi"
  Then I follow "Next »"
  Then I press "Create View"
  Then I should see "Hindi"
  And I should not see "Telugu"
  Then I follow "Update View"
  Then I toggle language selection for "Hindi"
  Then I toggle language selection for "Telugu"
  Then I press "Update View"
  Then I should not see "Hindi"
  And I should see "Telugu"
  Then I logout

@javascript
Scenario: Admin adds the language column in users view, and does filtering and sorting at UI level
  Given the current program is "primary":"albers"
  Then I follow "Manage"
  Then I follow "User Views"
  And I should not see "Language"
  Then I follow "Update View"
  Then I add language column
  Then I press "Update View"
  And I should see "This view is pinned to Administrator Dashboard, Campaign1 Name email campaign, Campaign2 Name email campaign, Campaign4 Name email campaign, Campaign5 Name email campaign, Disabled Campaign-3 Name email campaign, Disabled Campaign4 Name email campaign, Birthday Party event and RoR Meetup event. Updating this view will update the dashboard and campaign target audience. And, you have to update the event guest list in respective event page separately incase you want the same changes on event guest list as well. Alternatively, you can create a new view. Do you want to continue?"
  Then I press "OK"
  Then I wait for ajax to complete
  Then I should see "Language"
  Then I sort on language column
  And I should not see "Hindi"
  And I should not see "Telugu"
  Then I sort on language column
  And I should see "Telugu"
  And I should see "Hindi"
  Then I apply filter for language "Hindi"
  And I should see "Hindi"
  And I should not see "Telugu"
  Then I clear filter for language
  And I should see "Hindi"
  And I should see "Telugu"
  Then I apply filter for language "Telugu"
  And I should see "Telugu"
  And I should not see "Hindi"
  Then I logout

@javascript
Scenario: Admin creates a admin view with the language filtering in filter criteria at program level
  Given the current program is "primary":"albers"
  Then I follow "Manage"
  Then I follow "User Views"
  Then I click "#clicked-title-admin-view"
  Then I click ".cjs_create_admin_view_link"
  And I fill in "admin_view_title" with "Language filter user view test"
  Then I follow "Next »"
  Then I should see "Language"
  Then I toggle language selection for "Hindi"
  Then I follow "Next »"
  Then I press "Create View"
  Then I should see "Hindi"
  And I should not see "Telugu"
  Then I follow "Update View"
  Then I toggle language selection for "Hindi"
  Then I toggle language selection for "Telugu"
  Then I press "Update View"
  Then I should not see "Hindi"
  And I should see "Telugu"
  Then I logout