# encoding: utf-8
Feature: Access connections API
Background: Program setup
  Given the current program for api is "primary":"albers"

Scenario: Admin receives an error when accesses a list of connections via XML using invalid key
  Given I requested connections list as "xml" with "invalid" key
  Then response should be "unauthorized"
  And I should receive "xml" response
  And I should see xml-tag "errors"
  And I should see xml-tag "errors/error"

Scenario: Admin receives an error when accesses a list of connections via JSON using invalid key
  Given I requested connections list as "json" with "invalid" key
  Then response should be "unauthorized"
  And I should receive "json" response
  And I should receive json array

Scenario: Admin receives an error when accesses a connections via XML using invalid key
  Given I requested connection as "xml" with "invalid" key
  Then response should be "unauthorized"
  And I should receive "xml" response
  And I should see xml-tag "errors"
  And I should see xml-tag "errors/error"

Scenario: Admin receives an error when accesses a connections via XML using invalid key
  Given I requested connection as "json" with "invalid" key
  Then response should be "unauthorized"
  And I should receive "json" response
  And I should receive json array

Scenario: Admin receives a list of connections via XML
  Given I requested connections list as "xml" with "valid" key
  Then response should be "success"
  And I should receive "xml" response
  And I should see xml-tags
    | connections                                         |
    | connections/connection                              |
    | connections/connection/id                           |
    | connections/connection/name                         |
    | connections/connection/mentors                      |
    | connections/connection/mentors/mentor               |
    | connections/connection/mentors/mentor/name          |
    | connections/connection/mentors/mentor/connected-at  |
    | connections/connection/mentees                      |
    | connections/connection/mentees/mentee               |
    | connections/connection/mentees/mentee/name          |
    | connections/connection/mentees/mentee/connected-at  |

Scenario: Admin receives a list of connections via JSON
  Given I requested connections list as "json" with "valid" key
  Then response should be "success"
  And I should receive "json" response
  And I should receive json array
  And I should receive json array containing object
  And I should receive json array containing object with
    | id      |
    | name    |
    | mentors |
    | mentees |

Scenario: Admin receives a connection via XML
  Given I requested connection as "xml" with "valid" key
  Then response should be "success"
  And I should receive "xml" response
  And I should see xml-tags
    | connection                              |
    | connection/id                           |
    | connection/name                         |
    | connection/state                        |
    | connection/closed-on                    |
    | connection/notes                        |
    | connection/last-activity-on             |
    | connection/mentors                      |
    | connection/mentors/mentor               |
    | connection/mentors/mentor/name          |
    | connection/mentors/mentor/connected-at  |
    | connection/mentees                      |
    | connection/mentees/mentee               |
    | connection/mentees/mentee/name          |
    | connection/mentees/mentee/connected-at  |

Scenario: Admin receives a connection via JSON
  Given I requested connection as "json" with "valid" key
  Then response should be "success"
  And I should receive "json" response
  And I should receive json object with
    | id                |
    | state             |
    | closed_on         |
    | notes             |
    | last_activity_on  |
    | name              |
    | mentors           |
    | mentees           |

Scenario: Admin creates a connection via XML
  Given I requested connection creation as "xml" with "valid" key
  Then response should be "success"
  And I should receive "xml" response
  And I should see xml-tags
    | connection    |
    | connection/id |

Scenario: Admin creates a connection via JSON
  Given I requested connection creation as "json" with "valid" key
  Then response should be "success"
  And I should receive "json" response
  And I should receive json object

Scenario: Admin updates a connection via XML
  Given I requested connection update as "xml" with "valid" key
  Then response should be "success"
  And I should receive "xml" response
  And I should see xml-tags
    | connection |

Scenario: Admin updates a connection via JSON
  Given I requested connection update as "json" with "valid" key
  Then response should be "success"
  And I should receive "json" response
  And I should receive json object

Scenario: Admin deletes a connection via XML
  Given I requested connection deletion as "xml" with "valid" key
  Then response should be "success"
  And I should receive "xml" response
  And I should see xml-tags
    | connection    |
    | connection/id |

Scenario: Admin deletes a connection via JSON
  Given I requested connection deletion as "json" with "valid" key
  Then response should be "success"
  And I should receive "json" response
  And I should receive json object

