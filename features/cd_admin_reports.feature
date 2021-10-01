@reindex @manage_career_development

Feature: Manage Career Development Portals
  In order to view reports in the Career Development Portal
  I want to login as an Admin

  Background:
    Given the current program is "nch":"portal"
    When I have logged in as "nch_admin@example.com"

  @javascript
  Scenario: Demographic Report
    And I follow "User Reports" within "nav#sidebarLeft"
    And I follow "Geographic Distribution Report"
    And I should not see "Most Users"
    And I should see "Most Employees"
    And I should see "India"
    And I should see "Country" within "#cjs_demographic_report_table_view"
    And I should see "India" within "#cjs_demographic_report_table_view"
    And I should not see "All Users" within "#cjs_demographic_report_table_view"
    And I should see "Employees" within "#cjs_demographic_report_table_view"
    And I should see "1" within "#cjs_demographic_report_table_view"
    Then I follow "filter_report"
    Then I should not see "Role" within "#other_report_filters"
    And I should not see "Employees" within "#other_report_filters"
    And I should see "Country" within "#other_report_filters"
    And I should see "India" within "#other_report_filters"
    And I click "#country_India"
    And I press "Go"