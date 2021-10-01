Feature: Articles Consolidation
	In Order to use the same articles across multiple programs
	As a mentor
	I want to publish a single article to all programs I belong to

  @javascript @cross_browser
  Scenario: Creating a article + Deletion of Article
    Given the current program is "annauniv":"psg"
    And I have logged in as "mentor@psg.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    When I follow "Write New Article"
    And I scroll and click the element "div#a_text" below my visibility
    And I set the article title to "Unique Title"
    And I set the general article content to "This is a sample article on terrorism"
    And I publish the article
    Then I should see "Unique Title"
    And I should see "This is a sample article on terrorism"
    And I should not see "Mark as helpful"

    Given the current program is "annauniv":"psg"
    When I go to the homepage
    Then I hover on tab "Advice"
    And I go the "Articles" listing page
    And I visit article with title "Unique Title" in "psg"
    Then I should see "This is a sample article on terrorism"
    And I should not see "Mark as helpful"

    And I go to the homepage
    And I go the "Articles" listing page
    And I visit article with title "Unique Title" in "psg"
    Then I should see "Views"
    And I logout

    #Add Comments
    Given I have logged in as "stud1@psg.com"
    Then I hover on tab "Advice"
    And I go the "Articles" listing page
    And I visit article with title "Unique Title" in "psg"
    And I fill in "comment_body" with "This is an awesome article"
    And I press "Comment"

    And I visit article with title "Unique Title" in "psg"
    Then I should see "This is an awesome article"

    #Delete Comment
    And I click "span.caret" within "div#comments_box"
    Then I follow "Delete"
    And I should see "Are you sure you want to delete the comment? This action cannot be undone."
    And I confirm popup

    And I visit article with title "Unique Title" in "psg"
    Then I should not see "This is an awesome article"
    Then I logout

    #Article Deletion
    Given the current program is "annauniv":"psg"
    And I have logged in as "mentor@psg.com"
    And I visit article with title "Unique Title" in "psg"
    And I click "span.caret" within "div#title_actions"
    And I follow "Delete Article"
    Then I should see "Are you sure you want to delete this article? This cannot be undone."
    And I confirm popup
    Then I should see the flash "The article was deleted"
    And I should not see "Unique Title"

  @javascript @cross_browser
  Scenario: Mentee can visit the article and rate it. The rating should be persistent.
    Given the current program is "annauniv":"psg"
    And I have logged in as "stud1@psg.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    Then I should see articles listed

    When I follow "About Anna University and PSG"
    Then I should be able to rate the current article
    Then I follow the back link
    Then I should see "1Like"
    When I follow "About Anna University and PSG"
    Then I should be able to rate the current article
    Then I should not see "1Like"
    And I logout

    Given the current program is "annauniv":"ceg"
    And I have logged in as "stud2@psg.com"
    When I go to the homepage
    And I go the "Articles" listing page
    Then I should see "About Anna University and PSG"

    When I follow "About Anna University and PSG"
    Then I should be able to rate the current article
    Then I should see that I can revert back the rating
    And I go to the homepage
    And I go the "Articles" listing page
    Then I should see "About Anna University and PSG"
    When I follow "About Anna University and PSG"
    Then I should see "Views"
    But I should see "Comments"
    And I logout

  @javascript @p2 @cross_browser
  Scenario: Check Article Lables Autocomplete
    Given the current program is "primary":"albers"
    When I have logged in as "robert@example.com"
    Then I hover on tab "Advice"
    And I follow "Articles"
    Then I follow "Write New Article"
    And I scroll and click the element "div#a_text" below my visibility
    When I click "#s2id_article_article_content_label_list > .select2-choices"
    And I click on select2 result "animals"