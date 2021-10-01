@mentoring_area_change_expiry_date
Feature: Change expiry date/request for change in expiry date option for end users

	@javascript @cross-browser
	Scenario: User changes mentoring connection date/request admin for a change in date
	    Given the current program is "primary":"albers"
	    Given I have logged in as "ram@example.com"
	    Then I enable admin audit logs
		  When I hover over "my_programs_container"
		  And I select "Primary Organization" from the program selector
		  Then I enable "mentoring_connections_v2" feature as a super user
		  And I logout
		  Given the current program is "primary":"albers"
	    Given I have logged in as "ram@example.com"
	    And I follow "Manage"
	    And I follow "Program Settings"
	    And I follow "Connection Settings"
	    And I should see the radio button "program_allow_to_change_connection_expiry_date_false" selected
	    And I choose "program_allow_to_change_connection_expiry_date_true"
	    And I press "Save"
	    And I logout
	    Given the current program is "primary":"albers"
	    Given I have logged in as "mkr@example.com"
	    And I follow "name & madankumarrajan"
	    And I follow "(change)"
      And I should see "Set Expiration Date"
	    And I fill in "set_expiry_date_reason_1" with "A reason"
	    And I fill in first "set_new_expiry_date" with a date 10 days from now
	    And I press "Set Expiration Date"
	    Then I should see "New expiration date for the mentoring connection has been set"
	    And I logout
	    Given the current program is "primary":"albers"
	    Given I have logged in as "ram@example.com"
	    And I follow "Manage"
	    And I follow "Program Settings"
	    And I follow "Connection Settings"
	    And I should see the radio button "program_allow_to_change_connection_expiry_date_true" selected
	    And I choose "program_allow_to_change_connection_expiry_date_false"
	    Then I press "Save"
	    And I logout
	    Given the current program is "primary":"albers"
	    Given I have logged in as "mkr@example.com"
	    And I follow "name & madankumarrajan"
	    And I follow "(Request for change)"
	    And I press "Send"
	    Then I should see "Your message has been sent to Administrator"
	    And I should see "Contact Administrator to extend the duration of your mentoring connection."
	    And I click "#request_expiry_date_from_flash_1"
	    And I press "Send"
	    Then I should see "Your message has been sent to Administrator"
	    And I logout