When(/^I visit survey config page$/) do
  visit survey_survey_questions_path(survey, :root => "albers")
end

When(/^I add questions to survey$/) do
  create_few_questions
end

When(/^I submit the answers "([^\"]*)"$/) do |answers|
  visit edit_answers_survey_path(survey, :root => "albers", :src => Survey::SurveySource::TASK)
  questions = survey.survey_questions
  answer_data = answers.split(',')
  answer_data = answer_data.reverse!
  answer_data.each_with_index do |ans, i|
    ans = ans.gsub("'", '').strip
    if questions[i].choice_based?
      # Do not choose anything if not given.
      unless ans.empty?
        if questions[i].choice_but_not_matrix_type?
            choose "common_answers_#{questions[i].id}_#{ans.downcase}"
        else
          questions = questions[i].rating_questions
          answer_data = ans.split(' ')
          answer_data.each_with_index do |ans, j|
            unless ans.empty?
              choose "survey_answers_#{questions[j].id}_#{ans}"
            end
          end
        end
      end
    else
      step "I fill in \"common_answers_#{questions[i].id}\" with \"#{ans}\""
    end
  end
  step "I press \"Submit\""
end

Then /^I open the first individual survey$/ do
  step "I click \"div.k-grid-content .k-alt .fa-align-justify\""
end

When(/^I fill the answers "([^\"]*)"$/) do |answers|
  questions = survey.survey_questions
  answer_data = answers.split(',')
  answer_data = answer_data.reverse!
  answer_data.each_with_index do |ans, i|
    ans = ans.gsub("'", '').strip
    if questions[i].choice_based?
      # Do not choose anything if not given.
      unless ans.empty?
        #Multiple Answers allowed?
        if (questions[i].question_type == 3)
          step "I check \"common_answers_#{questions[i].id}_#{ans.downcase}\""
          next
        end
        #Rating Scale
        if (questions[i].question_type == 4)
          step "I choose \"common_answers_#{questions[i].id}_#{ans.downcase}\""
          next
        end
        #Only one answer
        step "I select \"#{ans}\" from \"common_answers_#{questions[i].id}\""
        #choose "common_answers_#{questions[i].id}_#{ans.downcase}"
        next
      end
      next
    end
    if (questions[i].question_type == 6)
      step "I fill in \"survey_answers_#{questions[i].id}\" with \"#{ans}\""
    else
      step "I fill in \"common_answers_#{questions[i].id}\" with \"#{ans}\""
    end
  end
end

Then /^I fill in "([^"]*)" with "([^"]*)" for "([^"]*)"$/ do |field, answer, question_text|
  question = survey.survey_questions.where(:question_text => question_text).first()
  And "I fill in \"#{field}#{question.id}\" with \"#{answer}\""
end


When(/^I participate in the survey$/) do
  visit edit_answers_survey_path(survey, :root => "albers", :src => Survey::SurveySource::TASK)
end

When (/^I fill in other field with "([^\"]*)"$/) do |ans|
  q=SurveyQuestion.last
  select("Other...", :from => "common_answers_#{q.id}")
  step "I fill in \"preview_#{q.id}\" with \"#{ans}\""
  if (ENV['BS_RUN'] == 'true')
    page.execute_script %Q[jQuery("#preview_#{q.id}").focus()];
    page.execute_script %Q[jQuery("#preview_#{q.id}").trigger('onchange')];
  end
end

When (/^I should see "([^\"]*)" as the other answer$/) do |ans|
  q=SurveyQuestion.last
  page.has_field?("preview_#{q.id}",:with => ans)
end

When(/members have participated in the survey/) do
  s = survey
  questions = s.survey_questions.reload
  mentors = s.program.mentor_users
  answers_count = mentors.count*2
  resid=1
  assert_difference 'SurveyAnswer.count', answers_count do
    mentors.each do |mentor|
      questions[1].survey_answers.create!(answer_value: {answer_text: 'Hello\\', question: questions[1]}, user: mentor, response_id: resid, last_answered_at: Time.now.utc)
      questions[2].survey_answers.create!(answer_value: {answer_text: 'Best', question: questions[2]}, :user => mentor, :response_id => resid, :last_answered_at => Time.now.utc)
      resid +=1
    end
  end
  survey.update_total_responses!
end

When (/^I should see "([^"]*)" (\d+) times$/ ) do |word, count|
  assert_equal page.find(:xpath, '//body').text.split(word).length, (count.to_i+1)
end

And (/^I edit the question with title "([^"]*)"$/) do |question_title|
  question_id = CommonQuestion.find_by(question_text: question_title).id
  steps %{
    And I click "#common_question_value_#{question_id} .btn-group .btn"
    And I click "a.edit_common_question_#{question_id}"
  }
end

And (/^I delete the question with title "([^"]*)"$/) do |question_title|
  question_id = CommonQuestion.where(question_text: question_title).first.id
  steps %{
    And I click "#common_question_value_#{question_id} .btn-group .btn"
    And I click "a#cjs-survey-question-#{question_id}-delete"
  }
end

And (/^I select "([^"]*)" option for question with title "([^"]*)"$/) do |option_value, question_title|
  question_id = CommonQuestion.find_by(question_text: question_title).id
  step "I select \"#{option_value}\" from \"common_question_type_#{question_id}\""
end

And (/^I should see "([^"]*)" option selected for question with title "([^"]*)"$/) do |option_value, question_title|
  question_id = CommonQuestion.find_by(question_text: question_title).id
  step "I should see \"#{option_value}\" within \"#common_question_type_#{question_id}\""
end

Then (/^I create a survey type task$/) do
  mm1 = MentoringModel.first
  task_template1 = MentoringModel::TaskTemplate.new
  task_template1.mentoring_model_id = mm1.id
  task_template1.role_id = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME, "primary").programs.ordered.first.roles.find_by(name: RoleConstants::MENTOR_NAME).id
  task_template1.title = "task template title"
  task_template1.duration = 1
  task_template1.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
  task_template1.action_item_id = Survey.last.id
  task_template1.save!
end

And (/^I click delete link of last survey$/) do
  survey_id = Survey.last.id
  step "I click \".survey-#{survey_id}-delete\""
end

Then (/^I delete survey type task$/) do
  MentoringModel::TaskTemplate.last.destroy
end

Then (/^I delete all the surveys of "([^"]*)" program$/) do |root|
  program = Program.find_by(root: root)
  program.surveys.delete_all
end

And (/^I update "([^"]*)" postive outcome options$/) do |question_title|
  question = CommonQuestion.where(question_text: question_title).first
  question.update_attribute(:positive_outcome_options, "positive outcome options set")
end

Given /^I update the response date of survey responses for program "([^"]*)":"([^"]*)"$/ do |organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  program.surveys.each do |survey|
    survey.survey_answers.update_all(last_answered_at: 2.days.ago)
  end
end

Then /^I select all profile columns$/ do
  within "div.multiselect-available-list .ui-priority-secondary" do
    step "I click \"span.ui-icon-arrowstop-1-e\""
  end
  step "I click \"#cjs_update_survey_response_column .form-actions .btn-primary\""
end

Then /^I remove all default columns$/ do
  within (first(:css,"div.multiselect-selected-list .ui-priority-secondary")) do
    step "I click \"span.ui-icon-arrowstop-1-w\""
  end
  step "I click \"#cjs_update_survey_response_column .form-actions .btn-primary\""
end

Then /^I clear filter on first question of survey with name "([^\"]*)" in program "([^"]*)":"([^"]*)"$/ do |survey_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  survey = program.surveys.find_by(name: survey_name)
  question = survey.survey_questions.first
  column_field = "answers#{question.id}"
  step "I clear table filter for \"#{column_field}\""
end

Then /^I sort table on first question of survey with name "([^\"]*)" in program "([^"]*)":"([^"]*)"$/ do |survey_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  survey = program.surveys.find_by(name: survey_name)
  question = survey.survey_questions.first
  column_field = "answers#{question.id}"
  step "I sort table by \"#{column_field}\""
end

Then /^I apply filter on first question of survey with name "([^\"]*)" in program "([^"]*)":"([^"]*)" with value "([^\"]*)"$/ do |survey_name, organization_subdomain, program_root, value|
  program = get_program(program_root, organization_subdomain)
  survey = program.surveys.find_by(name: survey_name)
  question = survey.survey_questions.first
  field = "answers#{question.id}"
  step "I set the focus to the main window"
  within "th[data-field='#{field}']" do
    step "I click \".k-grid-filter\""
  end
  CucumberWait.retry_until_element_is_visible {page.find('.k-textbox', :match => :prefer_exact).set(value)}
  if(ENV['BS_RUN'] == 'true')
   page.execute_script "jQuery('.k-textbox').trigger('change');"
  end
  steps %{
    Then I should see submit button "Filter"
    Then I press "Filter"
    Then I wait for ajax to complete
  }
end

Then /^I scroll to find question by "([^\"]*)"$/ do |value|
  page.execute_script "jQuery('.suwala-doubleScroll-scroll-wrapper').scrollLeft(#{value});"
end

When /^I scroll until I see "([^\"]*)"$/ do |text|
   text = clear_utf_symbols(text)
   max_scroll_tries = 1
   while(max_scroll_tries<=5) do
    value = 400*max_scroll_tries
    if !page.has_content?(text)
      page.execute_script "jQuery('.suwala-doubleScroll-scroll-wrapper').scrollLeft(#{value});"
    end
    max_scroll_tries = max_scroll_tries+1;
   end
  step "I should see \"#{text}\""
end

Then /^I apply filter on "([^\"]*)" with "([^\"]*)" for survey with name "([^\"]*)" in program "([^"]*)":"([^"]*)"$/ do |question_text, value, survey_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  survey = program.surveys.find_by(name: survey_name)
  question = survey.survey_questions.where(:question_text => question_text).first
  field = "answers#{question.id}"
  step "I set the focus to the main window"
  #scroll to find the question
  #step "I scroll to find question by \"200\""
  within "th[data-field='#{field}']" do
    step "I click \".k-grid-filter\""
  end
  steps %{
    Then I check "#{value}"
    Then I press "Filter" within ".k-filter-menu"
    Then I wait for ajax to complete
  }
end

Then /^I should see the answer "([^\"]*)" for the question "([^\"]*)"$/ do |answer_text, question_text|
  page.should have_field(question_text, with: answer_text)
end

Then /^I follow the back link$/ do
  step "I click \".fa-arrow-left\""
end

When /^I apply time filter$/ do
  page.execute_script "jQuery(\"#cjs_submit_date_range_filter\").click();"
end

Then /^I select "([^\"]*)" days after "([^\"]*)":"([^\"]*)" program creation as "([^\"]*)"$/ do |days, organization_subdomain, program_root, element|
  program = get_program(program_root, organization_subdomain)
  formatted_date = program.created_at + days.to_i.days
  page.execute_script("jQuery('#{element}').data('kendoDatePicker').value('#{DateTime.localize(formatted_date, format: :full_display_no_time)}')")
end

Then /^I select "([^\"]*)" days and "([^\"]*)" days after "([^\"]*)":"([^\"]*)" program creation$/ do |days1, days2, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  formatted_date1 = program.created_at + days1.to_i.days
  formatted_date2 = program.created_at + days2.to_i.days
  page.execute_script("jQuery('#report_time_filter_form .cjs_daterange_picker_value').val('#{formatted_date1.to_date} - #{formatted_date2.to_date}')")
end

And /^I add matrix forced ranking question to survey$/ do
  program = Program.find_by(name: "Albers Mentor Program")
  survey = program.surveys.find_by(name: "Mentoring Relationship Health")
  q = survey.survey_questions.new(:question_type => CommonQuestion::Type::MATRIX_RATING, :matrix_setting => CommonQuestion::MatrixSetting::FORCED_RANKING, :program_id => program.id, :question_text => "Matrix Question")
  ["Bad","Average","Good"].each_with_index{|text, pos| q.question_choices.build(text: text, position: pos + 1, ref_obj: q) }
  q.row_choices_for_matrix_question = "Ability,Confidence,Talent"
  q.create_survey_question
  q.save
end

Then /^I answer matrix question with "([^\"]*)" of "([^\"]*)"$/ do |answer, position|
  program = Program.find_by(name: "Albers Mentor Program")
  survey = program.surveys.find_by(name: "Mentoring Relationship Health")
  q = survey.survey_questions.find_by(question_text: "Matrix Question")
  id = "survey_answers_" + (q.id + position.to_i).to_s + "_" + answer
  choose(id, :match => :prefer_exact, :visible => true)
end

Then /^I should see matrix answer with "([^\"]*)" of "([^\"]*)"$/ do |answer, position|
  program = Program.find_by(name: "Albers Mentor Program")
  survey = program.surveys.find_by(name: "Mentoring Relationship Health")
  q = survey.survey_questions.find_by(question_text: "Matrix Question")
  id = "survey_answers_" + (q.id + position.to_i).to_s + "_" + answer
  assert find_field(id).should be_checked
end

Then /^I should not see matrix answer with "([^\"]*)" of "([^\"]*)"$/ do |answer, position|
  program = Program.find_by(name: "Albers Mentor Program")
  survey = program.surveys.find_by(name: "Mentoring Relationship Health")
  q = survey.survey_questions.find_by(question_text: "Matrix Question")
  id = "survey_answers_" + (q.id + position.to_i).to_s + "_" + answer
  assert has_no_checked_field?(id)
end

And /^I add choice "([^\"]*)" for survey question next to "([^\"]*)"$/ do |new_choice, existing_choice|
  existing_element =  page.all(:css, "#common_question_choices_list_new li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == existing_choice
  end
  within(existing_element) do
    find(:css, ".cjs_add_choice").click
  end
  new_element =  page.all(:css, "#common_question_choices_list_new li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == ""
  end
  within(new_element) do
    find(:css, "input[type=text]").set(new_choice)
  end
end

And /^I add row "([^\"]*)" for matrix question next to "([^\"]*)"$/ do |new_row, existing_row|
  existing_element =  page.all(:css, "#matrix_question_rows_list_new li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == existing_row
  end
  within(existing_element) do
    find(:css, ".cjs_add_row").click
  end
  new_element =  page.all(:css, "#matrix_question_rows_list_new li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == ""
  end
  within(new_element) do
    find(:css, "input[type=text]").set(new_row)
  end
end

And /^I add choice "([^\"]*)" for survey question "([^\"]*)" in "([^\"]*)" next to "([^\"]*)"$/ do |new_choice, question_text, program_name, existing_choice|
  program = Program.where(name: program_name).first
  question = program.survey_questions.find_by(question_text: question_text)
  choice_id = question.question_choices.find{|choice| choice.text == existing_choice}.id
  page.execute_script("jQuery('#common_question_#{question.id}_#{choice_id}_container .cjs_add_choice').click()")

  new_element =  page.all(:css, "#common_question_choices_list_#{question.id} li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == ""
  end

  within(new_element) do
    find(:css, "input[type=text]").set(new_choice)
  end
end

And /^I add row "([^\"]*)" for matrix question "([^\"]*)" in "([^\"]*)" next to "([^\"]*)"$/ do |new_row, question_text, program_name, existing_row|
  program = Program.where(name: program_name).first
  question = program.survey_questions.find_by(question_text: question_text)

  rq_id = question.matrix_rating_question_records.find{|rq| rq.question_text == existing_row}.id
  page.execute_script("jQuery('#matrix_question_#{question.id}_#{rq_id}_container .cjs_add_row').click()")

  new_element =  page.all(:css, "#matrix_question_rows_list_#{question.id} li.cjs_quicksearch_item").find do |li|
    li.find(:css, "input[type=text]").value == ""
  end

  within(new_element) do
    find(:css, "input[type=text]").set(new_row)
  end
end

And /^I add choices "([^\"]*)" for survey question$/ do |choices|
  choices_arr = choices.split(",")
  choices_arr.map(&:strip).each_with_index do |new_choice, index|
    new_element =  page.all(:css, "#common_question_choices_list_new li.cjs_quicksearch_item").find do |li|
      li.find(:css, "input[type=text]").value == ""
    end

    within(new_element) do
      find(:css, "input[type=text]").set(new_choice)
      find(:css, ".cjs_add_choice").click if choices_arr.size > 0 && index != choices_arr.size - 1
    end
  end
end

And /^I add rows "([^\"]*)" for matrix question$/ do |rows|
  rows_arr = rows.split(",")
  rows_arr.map(&:strip).each_with_index do |new_row, index|
    new_element =  page.all(:css, "#matrix_question_rows_list_new li.cjs_quicksearch_item").find do |li|
      li.find(:css, "input[type=text]").value == ""
    end

    within(new_element) do
      find(:css, "input[type=text]").set(new_row)
      find(:css, ".cjs_add_row").click if rows_arr.size > 0 && index != rows_arr.size - 1
    end
  end
end

Then /^I delete rows "([^\"]*)" for matrix question "([^\"]*)" in "([^\"]*)"$/ do |rows, question_text, program_name|
  program = Program.where(name: program_name).first
  question = program.survey_questions.find_by(question_text: question_text)
  rating_questions = question.matrix_rating_question_records
  rows.split(" ").each do |row_text|
    rq_id = rating_questions.find{|rq| rq.question_text == row_text}.id
    find(:css, "#matrix_question_#{question.id}_#{rq_id}_container .cjs_destroy_row").click
  end
end

Then /^I edit choice "([^\"]*)" inside the "([^\"]*)" survey question in "([^\"]*)" to "([^\"]*)"$/ do |choice, question_text, program_name, new_choice|
  program = Program.find_by(name: program_name)
  question = program.survey_questions.find_by(question_text: question_text)
  question_choice_id = question.question_choices.find_by(text: choice).id
  find("#common_question_#{question.id}_#{question_choice_id}_container input[type=text]").set(new_choice)
end

Then /^I delete choices "([^\"]*)" for survey question "([^\"]*)" in "([^\"]*)"$/ do |choices, question_text, program_name|
  program = Program.where(name: program_name).first
  question = program.survey_questions.find_by(question_text: question_text)
  question_choices = question.question_choices
  choices.split(" ").each do |choice|
    choice_id = question_choices.find{|q_choice| q_choice.text == choice}.id
    find(:css, "#common_question_#{question.id}_#{choice_id}_container .cjs_destroy_choice").click
  end
end

Then /^I delete choices "([^\"]*)" for survey question$/ do |choices|
  choices.split(" ").each do |choice|
    new_element =  page.all(:css, "#common_question_choices_list_new li.cjs_quicksearch_item").find do |li|
      li.find(:css, "input[type=text]").value == choice
    end
    within(new_element) do
      find(:css, ".cjs_destroy_choice").click
    end
  end
end

Then /^I delete rows "([^\"]*)" for marix question$/ do |rows|
  rows.split(" ").each do |choice|
    new_element =  page.all(:css, "#matrix_question_rows_list_new li.cjs_quicksearch_item").find do |li|
      li.find(:css, "input[type=text]").value == choice
    end
    within(new_element) do
      find(:css, ".cjs_destroy_choice").click
    end
  end
end

And /^I stubs s3 and pdf for progress reports$/ do
  Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
  ChronusS3Utils::S3Helper.stubs(:write_to_file_and_store_in_s3).returns(true)
  EngagementSurvey.stubs(:generate_progress_report_pdf).returns(File.open(File.join(Rails.root.to_s, 'test/fixtures/files/some_file.txt')))
end

private

def survey
  Program.find_by(root: "albers").surveys.of_program_type.first
end

def create_few_questions
  local_create_question
  local_create_question(:required => true)
  local_create_question(
    :question_type => CommonQuestion::Type::RATING_SCALE,
    :question_choices => "Good,Better,Best")
end

def local_create_question(options = {})
  options.reverse_merge!(
    :program => survey.program,
    :question_text => "What is your name?",
    :question_type => CommonQuestion::Type::STRING
  )
  choices = options.delete(:question_choices) || ""
  q = survey.survey_questions.create!(options)
  choices.split(",").each_with_index{|choice, pos| q.question_choices.create!(text: choice, position: pos+1)}
  q
end
