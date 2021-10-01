Then /I should see match config details/ do
  assert page.has_css?(".cui_bulk_match_config_details")
end

Then /I should not see match config details/ do
  #assert !page.has_css?(".cui_bulk_match_config_details")
  assert_false page.all(".cui_bulk_match_config_details").any?
end

Then /^I should see match performance metrics as NA$/ do
  page.evaluate_script(%Q[jQuery("#deviation_score").siblings("span").andSelf().text().trim().split("  ").join() == "NA,NA,NA"])
end

Then /^I should see match performance metrics calculated$/ do
  page.evaluate_script(%Q[jQuery("#deviation_score").siblings("span").andSelf().text().trim().split("  ").join() == "90.00 %,90 % - 90 %,0.00 %"])
end

Then /^I create a few default configs$/ do
  org = Program::Domain.get_organization("#{DEFAULT_HOST_NAME}", "primary")
  pq = ProfileQuestion.where(:organization_id => org.id, :question_type => ProfileQuestion::Type::LOCATION).first
  prog = org.programs.find_by(root: "albers")
  mentor_role = prog.get_role(RoleConstants::MENTOR_NAME)
  student_role = prog.get_role(RoleConstants::STUDENT_NAME)
  mentor_question = pq.role_questions.find_by(role_id: mentor_role.id)
  student_question = pq.role_questions.find_by(role_id: student_role.id)
  MatchConfig.create!(:program => prog, :mentor_question => mentor_question, :student_question => student_question)
end

Then /^I should not see admin view details$/ do
  #assert !page.has_css?(".cjs_student_view_content")
  assert_false page.all(".cjs_student_view_content").any?
end  

Then /^I wait for the "([^\"]*)" label display$/ do |status|
  if(ENV['BS_RUN'] == 'true')
    steps %{
      And I uncheck "master_checkbox"
      And I check "master_checkbox"
    }
  end
  
  Timeout.timeout(Capybara.default_max_wait_time) do
      while (!page.evaluate_script("jQuery('#cjs_bulk_match_result .cui-td-group-status:contains(\"#{status}\")').is(':visible')")) do
      end 
  end
end    
