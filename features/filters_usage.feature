@javascript @reindex
Feature: To Explore the usage of combination of filters in the listing pages

@p2 @admin
Scenario: Admin uses the filter in the mentors listing page and manage connections page
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  And there are some available for advance search configuration and ordered option question for "mentor" in "primary":"albers"
  When I have logged in as "ram@example.com"
  Then I follow "Mentors" tab
  Then I apply location filter
  Then I follow "More filters"
  And I apply choice based filter in combination with location filter
  Then I remove location filter and check only choice based filter
  Then I follow "Manage"
  And I follow "Mentoring Connections"
  Then I filter for "sub_filter_inactive" connections in v1
  Then I filter by Student Name
  Then I apply Closes on filter
  And I logout

@p2 @cross-browser
Scenario: Mentee visits the Mentors listing page and explores the filters
  Given the current program is "primary":"albers"
  Then I wait for "User" Elastic Search Reindex
  Then I perform missed migrations
  And there are some available for advance search configuration and ordered option question for "mentor" in "primary":"albers"
  And I have logged in as "mkr@example.com"
  When I follow "Mentors" tab
  Then I follow "More filters"
  Then I apply text based filters
  Then I apply ordered option filter in combination with text based filter
  Then I remove text based filter and check only ordered option filter
  Then I filter using quick find
  Then I logout

@cross-browser
Scenario: AJAX pagination and sorting
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  And I have logged in as "mkr@example.com"
  When I follow "Mentors" tab
  Then I should see "Showing 1 - 10 of 19"
  And I should see "2" within "ul.pagination"
  When I follow "2" within "ul.pagination"
  Then I should see "2" within "ul.pagination .current"
  And I should see "Showing 11 - 19 of 19"
  Then I filter a mentor "Kal Raman" using quick find
  When I select "Name (Z-A)" from "sort_by"
  Then I should see "Showing 1 - 10 of 19"
  And I should see "1" within "ul.pagination .current"
  And I should not see "Good unique name"
  When I select "Join Date (Old to New)" from "sort_by"
  Then I should see "Showing 1 - 10 of 19"
  And I should see "Mentor Studenter"
  When I select "Join Date (New to Old)" from "sort_by"
  Then I should see "Showing 1 - 10 of 19"
  And I should not see "Mentor Studenter"
  When I select "Match Score (Low to High)" from "sort_by"
  Then I should see "Showing 1 - 10 of 19"
  And I should see "Not Accepted"
  When I select "Match Score (High to Low)" from "sort_by"
  Then I should see "Showing 1 - 10 of 19"
  And I should not see "Not Accepted"
  And I logout


@javascript @cross-browser
Scenario: Admin visits mentoring connections page and filters the results
  Given the current program is "primary":"albers"
  Then I perform missed migrations
  And I have logged in as "ram@example.com"
  When I follow "Manage"
  And I follow "Mentoring Connections"
  And I should see "Ongoing" within "li.ct_active"
  Then I filter for "sub_filter_inactive" connections in v1
  Then I should see "Reset all"
  And I logout

  
@cross-browser
Scenario: AJAX admin pagination and sorting
  Given the current program is "primary":"albers"
  Then I wait for "User" Elastic Search Reindex
  Then I perform missed migrations
  And I have logged in as "ram@example.com"
  When I follow "Mentors" tab
  Then I should see "Showing 1 - 10 of 23"
  And I check "Available Mentors"
  Then I should see "Showing 1 - 10 of 20"
  And I uncheck "Available Mentors"
  When I follow "2" within "ul.pagination"
  Then I should see "2" within "ul.pagination .current"
  When I select "20" from "items_per_page_selector"
  Then I should see "1" within "ul.pagination .current"
  Then I should see "2" within "ul.pagination"
  And I should not see "3" within "ul.pagination"
  And I should see "Showing 1 - 20 of 23"
  And I select "40" from "items_per_page_selector"
  Then I should not see "ul.pagination"
  And I should see "Showing 1 - 23 of 23"
  And I logout
