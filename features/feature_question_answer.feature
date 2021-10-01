@qa
Feature: Question and Answers
  In order to clarify my doubts
  As a student
  I want to ask questions

Background:
  Given the current program is "primary":"albers"

  @javascript @cross-browser
  Scenario: Ask a question
    Given I have logged in as "rahim@example.com"
    And I follow "Advice"
    And I follow "Question & Answers"
    Then I should see "Tips"
    And I follow "Ask a Question"
    And I should see "Ask a Question"
    And I create a question with "" as summary and "" as description
    Then I should see the flash "Please fill all the required fields. Fields marked * are mandatory."
    And I create a question with "A new question" as summary and "Description for the latest question" as description
    Then a new question with "A new question" as summary and "Description for the latest question" as description should be created
    When "rahim@example.com" should follow the question with summary "A new question" in "albers"
    And I navigate to question with title "A new question" in "albers"
    Then I should see "A new question"
    And I should see "Description for the latest question"
    And I should see "Following"
    And I should see "Follower"

  @javascript @cross-browser
  Scenario: Answer a question
    And "rahim@example.com" creates a question with summary "Rahim question"
    And I have logged in as "robert@example.com"
    And I navigate to question with title "Rahim question" in "albers"
    Then I should see "Rahim question"
    And I should see "Related Questions"
    And I should see "Follower"
    Then I should see "There are no answers for this question yet."
    Then I follow "Answer this question"
    Then I should see "Your Answer"
    When I give "Waste question" as an answer
    Then I should see "Waste question"
    And I follow "Follow"
    Then I close the flash
    Then I follow "Answer this question"
    Then I should see "Your Answer"
    When I give "" as an answer
    Then I should see the flash "Answer cannot be blank"
    Then I close the flash
    Then I follow "Cancel"
    When I follow "Home"
    And I visit qa_questions index page in "albers"
    Then I should see "Ask a Question"
    Then I should see "Top Contributors"
    And I should see "Good unique name"
    When I navigate to question with title "Rahim question" in "albers"
    Then I should see "Rahim question"

  #Marking an answer helpful increments the count of likes

  @javascript @cross-browser
  Scenario: Follow a question and Mark answer useful
    Given "rahim@example.com" creates a question with summary "Random question"
    And "robert@example.com" creates "Worst Question" as an answer for the question with summary "Random question"
    And "robert@example.com" follows the question with summary "Random question"
    And I have logged in as "ram@example.com"
    When I navigate to last question in "albers"
    Then I should see "Follow"
    Then I follow "Answer this question"
    Then I should see "Your Answer"
    When I give "Good question" as an answer

    Then individual mails should go to "robert@example.com,rahim@example.com" having "Good question"
    When "ram@example.com" marks "Worst Question" answer useful
    And "ram@example.com" follows the question with summary "Random question"
    And I navigate to last question in "albers"
    Then I should see "1" users found answer "Worst Question" as helpful
    And I should see "Following"

  @javascript @cross-browser
  Scenario: Check Q&A deletion
    And I have logged in as "rahim@example.com"
    Then I follow "Advice"
    And I follow "Question & Answers"
    And I follow "Ask a Question"
    And I create a question with "A new question" as summary and "Description for the latest question" as description
    When "rahim@example.com" should follow the question with summary "A new question" in "albers"
    And I navigate to question with title "A new question" in "albers"
    Then I should see "A new question"
    And I should see "Description for the latest question"

    #Deleting QA
    When I go to the homepage
    And I select "Albers Mentor Program" from the program selector
    Then I hover on tab "Advice"

    And I follow "Question & Answers"
    And I navigate to question with title "A new question" in "albers"
    And I follow "Answer this question"
    And I press "Post Answer"
    And I should see the flash "Answer cannot be blank"
    And I close the flash 
    And I fill in "qa_answer_content" with "My answer"
    And I press "Post Answer"
    And I should see "My answer"
    And I click "span.caret" within "div#page_canvas"
    And I follow "Delete"
    And I confirm popup
    And I should not see "My answer"
    And I click "span.caret" within "div#title_actions"
    And I follow "Delete"
    And I confirm popup
    And I follow "Question & Answers"
    And I should not see "A new question"
    And I logout

    @javascript @cross-browser
    Scenario: Follow/Unfollow a Question - Check RA
    And I have logged in as "rahim@example.com"
    Then I follow "Advice"
    And I follow "Question & Answers"
    Then I follow "where in this world is coimbatore?"
    And I follow "Follow"
    Then I close the flash
    And I follow "Answer this question"
    Then I should see "Your Answer"
    And I fill in "Your Answer" with "BTW salem is in Tamilnadu, India"
    And I press "Post Answer"
    And I go to the homepage
    And I follow "My Activity"
    And I follow "View Answer"
    And I follow "Following"
    Then I close the flash
    And I follow "Answer this question"
    Then I should see "Your Answer"
    And I fill in "Your Answer" with "Do you know about India?"
    And I press "Post Answer"
    And I go to the homepage
    And I follow "My Activity"
    Then I should not see "Do you know about India?"

    @javascript
    Scenario:Viewing the QnA from the Users Profile's Page
    And I have logged in as "rahim@example.com"
    Then I hover on tab "Advice"
    And I follow "Question & Answers"
    And I follow "Ask a Question"
    And I create a question with "A new question" as summary and "Description for the latest question" as description
    And I click on profile picture and click "View Profile"
    And I follow "Questions (1)"
    Then I should see "A new question"
    And I should see "Description for the latest question"
    And I logout

    @javascript
    Scenario: Sort the questions and answer
    And I have logged in as "rahim@example.com"
    Then I follow "Advice"
    And I follow "Question & Answers"
    And I select "Most viewed" from "sort_by"
    And I should see "Is madurai in INDIA?" in the xpath "//div[@class='list-group']/div[1]"
    And I navigate to question with title "Is madurai in INDIA?" in "albers"
    And I follow "Answer this question"
    Then I should see "Your Answer"
    And I fill in "Your Answer" with "first"
    And I press "Post Answer"
    And I follow "Like"
    And I follow "Answer this question"
    Then I should see "Your Answer"
    And I fill in "Your Answer" with "second"
    And I press "Post Answer"
    And I should see "second" in the xpath "//div[@class='list-group']/div[1]"
    And I select "Most helpful" from "sort_by"
    And I should see "first" in the xpath "//div[@class='list-group']/div[1]"
    And I logout

