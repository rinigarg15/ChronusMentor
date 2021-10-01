Feature: Remove a user
In order to perform the above steps
As an admin
I want to login and enter the appropriate as required

@javascript
Scenario: Logged in admin removes a user
    Given the current program is "primary":"albers"
    When I have logged in as "ram@example.com"
    Then I follow "Students"
    Then I should scroll by "1000"
    Then I follow "rahim user"
    Then I should see "rahim user"
    Then I should see "Remove rahim user"
    Then I follow "Remove rahim user"
    
    Then I should see "You are about to remove rahim user from the program. Did you intend to deactivate the membership instead?"
    Then I should see "Removal of users is an irreversible action and will lead to loss of data. All their contributions in any mentoring connections, any activity in articles, forums and profile data including reporting information will be removed from the program permanently."
    Then I should see "Deactivating users revokes their access to the program, without loss of information."
    And I press "Remove User"
    Then I should see "'s profile, any mentoring connections and other contributions have been removed"
    Then I logout
