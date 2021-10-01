When /^I accesed new page form$/ do
  steps %{
    Then I should see "Manage"
    Then I follow "Manage"
    And I should see "Program Overview"
    And I follow "Program Overview"
    And I should see "Add a new page"
    And I should see the tab "Manage" selected
    And I follow "Add a new page"
  }
end