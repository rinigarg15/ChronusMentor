@reindex
Feature: Admin user management

Background: Admin logs in
  Given the current program is "primary":""
  And I have logged in as "ram@example.com"
  And clear mail deliveries
  And I enable "member_tagging" feature as a super user
  #And I reindex model "user"
  Given the current program is "primary":"albers"
  And I follow "Manage"
  And I follow "Albers Mentor Program"

@javascript @cross_browser
Scenario: Update the view to show Mentors with a particular mentoring mode
  And I disable calendar feature that was removed from UI as super user of "primary":"albers"
  Then I follow "Manage"
  Then I follow "User Views"
  Then I should see "All Users"
  When I create a new view
  And I fill in "admin_view_title" with "Test View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I click on the section with header "Engagement status"
  Then I should not see "Mentor's Mentoring Mode Preference"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I follow "Manage"
  And I follow "Program Settings"
  Then I follow "Matching Settings"
  And I check "program_allow_mentoring_mode_change"
  And I press "Save"
  Then I follow "Manage"
  Then I follow "User Views"
  When I create a new view
  And I fill in "admin_view_title" with "Test View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I click on the section with header "Engagement status"
  Then I should see "Mentor's Mentoring Mode Preference"
  And I select "One-time Mentoring" from "admin_view[connection_status][mentoring_model_preference]"
  Then I follow "Next »"
  Then I click view
  Then I click by xpath "(//div[text()='Mentoring Mode'])[last()]"
  And I press "Create View"
  Then I should see "Test View"
  Then I scroll until I see "Mentoring Mode"
  Then I should see "One-time Mentoring"
  Then I should see "Ongoing and One-time Mentoring"
  Then I should not see "Not applicable"
  Then I follow "Update View"
  And I select "Ongoing Mentoring" from "admin_view[connection_status][mentoring_model_preference]"
  And I press "Update View"
  Then I should see "Test View"
  Then I scroll until I see "Mentoring Mode"
  Then I should see "Ongoing and One-time Mentoring"
  Then I should not see "Not applicable"
  Then I follow "Update View"
  And I select "Ongoing and One-time Mentoring" from "admin_view[connection_status][mentoring_model_preference]"
  And I press "Update View"
  Then I should see "Test View"
  Then I scroll until I see "Mentoring Mode"
  Then I scroll until I see "Ongoing and One-time Mentoring"
  Then I should not see "Not applicable"

@javascript
Scenario: Ongoing is disabled then ongoing-related things must not be present
  And I follow "Manage"
  And I enable "calendar" feature that was removed from UI as super user of "primary":"albers"
  And I change engagement type of program "primary":"albers" to "career based and ongoing"
  Then I follow "Manage"
  Then I follow "User Views"
  Then I should see "All Users"
  When I create a new view
  And I fill in "admin_view_title" with "Test View"
  Then I follow "Next »"
  Then I click view
  When I click "#s2id_cjs_new_view_filter_roles_1 > .select2-choices"
  And I click on select2 result "Mentor"
  And I click on the section with header "Engagement status"
  Then I should see "User's mentoring connection status"
  Then I should see "Mentor Availability"
  Then I should see "Last Mentoring Connection closed on"
  Then I should see "Ongoing mentoring"
  Then I follow "Next »"
  Then I click view
  Then I should see "Connection slots"
  Then I should see "Connections"
  And I change engagement type of program "primary":"albers" to "career based"
  And I follow "Manage"
  Then I follow "User Views"
  When I create a new view
  And I fill in "admin_view_title" with "Test View"
  Then I follow "Next »"
  Then I click view
  And I click on the section with header "Engagement status"
  Then I should not see "Mentoring Connection Status"
  Then I should not see "Draft Mentoring Connection Status"
  Then I should not see "Mentor Availability"
  Then I should not see "Last Mentoring Connection closed on"
  Then I should not see "Ongoing mentoring"
  Then I follow "Next »"
  Then I click view
  Then I should not see "Connection slots"
  Then I logout

@javascript @cross_browser
Scenario: Unmarking Admin View All Users as a favourite and then marking it again
  And I follow "Manage"
  And I follow "User Views"
  Then I click on the "fa-star" icon
  And I should see icon "fa-star-o"
  Then I click on the "fa-star-o" icon
  And I should see icon "fa-star"