Then /^I should see a count of "([^\"]*)" for profile question with text "([^\"]*)" in filter section in the program "([^\"]*)"/ do |count, profile_question_text, program_name|
  program = Program.find_by(name: program_name)
  profile_question = ProfileQuestion.find_by(organization: program.organization.id, question_text: profile_question_text)
  steps %{
    And I should see "#{count}" within "#applied_filters_data #filter_activity_#{profile_question.id}"
  }
end

When /^I hover over the bubble with the text "([^\"]*)"/ do |text|
  page.find("#search_keywords_chart").find("svg g text", text: text).hover
end

Then /^I change the top filters limit to "([^\"]*)"/ do |value|
  MatchReport::MenteeActions::TOP_FILTERS_LIMIT = value.to_i
end