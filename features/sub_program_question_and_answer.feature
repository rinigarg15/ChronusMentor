@sub_programs
Feature: Accessing Q & A at the program level
Users should be able to view questions and answers at the program level
But they should go to the sub-program to answer them or ask new questions.

Background:
  Given the current program is "annauniv":"psg"

@javascript
  Scenario: User asks a question in a sub-program
    When I have logged in as "stud1@psg.com"
    And I follow "Advice"
    And I follow "Question & Answers"
    Then I follow "Ask a Question"
    Then I should see "Ask a Question"
    When I create a question with "How to drive a car?" as summary and "Please tell me how to drive a car" as description
    And I navigate to question with title "How to drive a car?" in "psg"
    And I should see "How to drive a car?"

    # mentor@psg.com should not see this question in PSG
    When I logout
    Given I have logged in as "mentor@psg.com"
    And I select "CEG Mentor Program" from the program selector
    And I should not see "How to drive a car?"


  # But should see in PSG.
  And I select "psg" from the program selector
  And I navigate to question with title "How to drive a car?" in "psg"
  Then I should see "How to drive a car?"

  # And also in Anna Univ.
  And I select "Anna University" from the program selector
  And I navigate to question with title "How to drive a car?" in ""

  # Someone belonging to only CEG should not see this question.
  When I logout
  And I have logged in as "sarat_mentor_ceg@example.com"
  When I go to the homepage
  And I should not see "How to drive a car?"
