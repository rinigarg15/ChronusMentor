Then /^I uncheck summary option from question with title "([^"]*)"$/ do |question_text|
  id = Connection::Question.where(question_text: question_text).first.id
  steps %{
    And I edit the question with title "#{question_text}"
    And I uncheck "display_question_in_summary_#{id}"
  }
end

Then /^add as summary option should not be disabled for "([^"]*)"$/ do |question_text|
  id = Connection::Question.where(question_text: question_text).first.id
  steps %{
    And I edit the question with title "#{question_text}"
    And element with id "#display_question_in_summary_#{id}" should not be disabled
  }
end

Then /^add as summary option should be disabled for "([^"]*)"$/ do |question_text|
  id = Connection::Question.where(question_text: question_text).first.id
  steps %{
    And I edit the question with title "#{question_text}"
    And element with id "#display_question_in_summary_#{id}" should be disabled
    When I hover over "display_question_in_summary_setting_already_enabled_tooltip_#{id}"
    Then I should see "This option is already enabled for"
    Then I should see "Question3"
    Then I should see "Please uncheck the option to enable it here."
  }
end

Then /^I fill connection summary question answer for question "([^"]*)" as "([^"]*)"$/ do |question_text, answer_text|
  id = Connection::Question.where(question_text: question_text).first.id
  steps %{
    And I fill in "common_answers_#{id}" with "#{answer_text}"
  }
end
