Feature: Ongoing Mentoring Related Info will be hidden in manage page and settings under it.

Background: Admin logs in
  Given the current program is "primary":"albers"
  And I have logged in as "ram@example.com"
  And I follow "Manage"

@javascript
Scenario: Ongoing Mentoring related features should be hidden in Connection Section for ongoing mentoring disabled program
  Then I should see "Mentoring Requests" within "div#manage"
  Then I should see "Mentoring Insights" within "div#manage"
  And I change engagement type of program "primary":"albers" to "career based"
  And I follow "Manage"
  Then I should not see "Mentoring Requests" within "div#manage"
  Then I should not see "Mentoring Insights" within "div#manage"

@javascript
Scenario: Ongoing mentoring related features should be hidden in Features for ongoing mentoring disabled program
  And I login as super user
  And I follow "Manage"
  And I follow "Program Settings"
  And I follow "Features"
  And I should not see "Flash Mentoring"
  And I should not see "Mentor Initiated Offer"
  Then I should see "Bulk Matching"
  Then I should see "Coaching Goals"
  Then I should see "Connection Profiles"
  Then I should see "Mentoring Area Calendar"
  Then I should see "Mentoring Connections V2"
  Then I should see "Mentoring Insights"
  And I change engagement type of program "primary":"albers" to "career based"
  And I follow "Features"
  Then I should not see "Bulk Matching"
  Then I should not see "Coaching Goals"
  Then I should not see "Connection Profiles"
  Then I should not see "Mentoring Area Calendar"
  Then I should not see "Mentoring Connections V2"
  Then I should not see "Mentoring Insights"
  And I should not see "Flash Mentoring"
  And I should not see "Mentor Initiated Offer"