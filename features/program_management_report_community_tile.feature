Feature: New dashboard for program administrators

Background: Admin logs in
  Given the current program is "primary":"albers"
  Then I maximize the window
  And I have logged in as "ram@example.com"
  Then I enable "mentoring_connections_v2" feature as a super user
  And I stub chronus s3 utils

@javascript @cross-browser
Scenario: Admin sees community tile - Announcements and Events
  Then I should see "Community" within "#community_info"
  Then I should see "Active announcements"
  Then I should see "For"
  Then I should not see "Expires on"
  Then I should see "All come to audi big announce Mentors and Students"
  Then I should see "All come to audi small Mentors and Students"
  Then I should see "Upcoming event"
  Then I should see "Event On"
  Then I should see "Attending"
  Then I should see "Birthday Party"
  Then I follow "View All Announcements »"
  Then I should see "Announcements"
  Then I should see "Drafted Announcements"
  Then I should see "Published Announcements"
  Then I follow "Home"
  Then I follow "View All Events »" within "#community_info"
  Then I should see "Events"
  Then I should see "Upcoming (1)"
  Then I should see "Past (0)"
  Then I should see "Drafted (1)"
  Then I follow "Home"
  Then I follow "All come to audi big announce" within "#community_info"
  Then I should see "For Mentors and Students"
  Then I follow "Home"
  Then I follow "Birthday Party" within "#community_info"
  Then I should see "Location chennai, tamilnadu, india"

@javascript @cross-browser
Scenario: Admin applies date filter inside community tile - Resources  
  Then I should see "Resources viewed"
  Then I should see "Working with the Mentoring Connection Plan 0 views"
  Then I should see "How to Use Your Connection Plan 0 views"
  Then I should see "Guide to Timely and Efficient Goal Setting 0 views"
  Then I should see "Resources marked helpful"
  Then I should see "Mentee Handbook 0 users"
  Then I should see "Mentor Handbook 0 users"
  Then I should see "How to Get Matched 0 users"
  Then I should see "View All Resources »"
  Then I follow "View All Resources »"
  Then I should see "Resources"
  Then I should see "Working with the Mentoring Connection Plan"
  Then I should see "How to Use Your Connection Plan"
  Then I should see "Guide to Timely and Efficient Goal Setting"
  Then I should see "How to Get Matched"
  Then I should see "Mentor Handbook"
  Then I should see "Mentee Handbook"
  Then I follow "Home"
  Then I follow "How to Use Your Connection Plan" within "#community_info"
  Then I should see "Introduction to Online Mentoring"
 
@javascript @cross-browser
Scenario: Admin manipulates community tile settings - Other Activity
  Then I should see "Other activity"
  Then I should see "Forum posts 0"
  Then I should see "Articles shared 4"
  Then I should see "Comments on articles 0"
  And I click ".cjs_management_report_date_range_preset" within "#community_info"
  And I select "Custom" from reports date range presets
  And I select "3" days after program creation as "#community_info .cjs_management_report_time_filter_form .cjs_daterange_picker_start"
  And I select "500" days after program creation as "#community_info .cjs_management_report_time_filter_form .cjs_daterange_picker_end"
  And I press "Go"
  And I should see "Custom" within ".cjs_management_report_date_range_preset" within "#community_info"
  Then I should see "Forum posts 0"
  Then I should see "Articles shared 4"
  Then I should see "Comments on articles 0"