Given(/^"([^\"]*)" creates a question with summary "([^\"]*)"$/) do |email, summary|
  program = Program.find_by(root: "albers")
  user = User.find_by_email_program(email, program)
  QaQuestion.create!(:user => user, :program => program, :summary => summary)
end

Given(/^"([^\"]*)" creates "([^\"]*)" as an answer for the question with summary "([^\"]*)"$/) do |email, answer_content, question_summary|
  question = QaQuestion.where(summary: question_summary).order("id DESC").first
  user = User.find_by_email_program(email, question.program)
  QaAnswer.create!(:qa_question => question, :user => user, :content => answer_content)
end

Given(/^"([^\"]*)" follows the question with summary "([^\"]*)"$/) do |email, question_summary|
  question = QaQuestion.where(summary: question_summary).order("id DESC").first
  user = User.find_by_email_program(email, question.program)
  question.toggle_follow!(user) unless question.followers.include? user
end

When(/^"([^\"]*)" marks "([^\"]*)" answer useful$/) do |email, answer_content|
  answer = QaAnswer.find_by(content: answer_content)
  user = User.find_by_email_program(email, answer.qa_question.program)
  answer.toggle_helpful!(user) unless answer.helpful?(user)
end

Then(/^I should see "([^\"]*)" users found answer "([^\"]*)" as helpful$/) do |user_count, answer_content|
  answer = QaAnswer.find_by(content: answer_content)
  within "div#qa_answer_#{answer.id}" do    
     step "I should see \"#{user_count}\""
  end
end

When(/^I create a question with "([^\"]*)" as summary and "([^\"]*)" as description$/) do |summary, description|
  steps %{
    And I fill in "qa_question_summary" with "#{summary}" within "div#cjs_new_qa_question_modal"
    And I fill in "qa_question_description" with "#{description}"
    And I press "Post Question"
  }
end

When(/^I give "([^\"]*)" as an answer$/) do |content|
  steps %{
    And I fill in "qa_answer_content" with "#{content}"
    And I press "Post Answer"
  }
end

Then(/^a new question with "([^\"]*)" as summary and "([^\"]*)" as description should be created$/) do |summary, description|
  question = QaQuestion.last
  assert_equal summary, question.summary
  assert_equal description, question.description
end

Then(/^a new answer with "([^\"]*)" as answer should be created$/) do |content|
  answer = QaAnswer.last
  assert_equal content, answer.content
end

Then(/^"([^\"]*)" should follow the question with summary "([^\"]*)" in "([^\"]*)"$/) do |email, summary, root|
  program = Program.find_by(root: root)
  question = QaQuestion.where(summary: summary).order("id DESC").first
  user = User.find_by_email_program(email, program)
  assert question.followers.include? user
end

When /^I navigate to question with title "([^"]*)" in "([^"]*)"$/ do |title, root|
  qa_question = QaQuestion.find_by(summary: title)
  if root.blank?
    visit qa_question_path(qa_question)
  else
    visit qa_question_path(qa_question, :root => root)
  end
end

When /^I navigate to last question in "([^"]*)"$/ do |root|
  qa_question = QaQuestion.last
  if root.blank?
    visit qa_question_path(qa_question)
  else
    visit qa_question_path(qa_question, :root => root)
  end
end

When /^I visit qa_questions index page in "([^"]*)"$/ do |root|
  visit qa_questions_path(:root => root)
end