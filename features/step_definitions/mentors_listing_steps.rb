And /^I have enabled "([^"]*)" feature$/ do |feature|
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  org.enable_feature(feature,true)
end


Then /^I should not see "([^\"]*)" for my list item$/ do |text|
  p = Program.find_by(root: "albers")
  user = User.find_by_email_program("mentrostud@example.com", p)
  within "div#mentor_#{user.id}" do
    step "I should not see \"#{text}\""
  end
end

Then /^I should see "([^\"]*)" filter accordion pane$/ do |pane_title|
  filters_pane_selector = ".filter_item.accordion_pane .collapsible_header.expanded:visible:contains(\'#{pane_title}\')"
  assert page.evaluate_script("jQuery(\"#{filters_pane_selector}\").length == 1")
end

Then /^I should not see "([^\"]*)" filter accordion pane$/ do |pane_title|
  filters_pane_selector = ".filter_item.accordion_pane .collapsible_header.expanded:visible:contains(\'#{pane_title}\')"
  assert page.evaluate_script("jQuery(\"#{filters_pane_selector}\").length == 0")
end

And /^Calendar availability range controls should be visible$/ do
  within "div#availability_status_content" do
    within ".cjs_appended_controls" do
      assert page.evaluate_script("jQuery(\"#calendar_availability_range\").length > 0")
      assert page.evaluate_script("jQuery(\"button:visible:contains(\'Go\')\").length > 0")
    end
  end
end

And /^Mentor Availability block should be expanded$/ do
  header_selector = ".filter_item.accordion_pane .exp_collapse_header #availability_status_header.collapsible_header.expanded"
  assert page.evaluate_script("jQuery(\"#{header_selector}\").length > 0")
end

Then /^the calendar availability default field should be false$/ do
  within(:xpath, xpath_for_collapsible_content("Availability Status")) do
    assert page.evaluate_script("jQuery(\"#calendar_availability_default\").val() == 'false'")
  end
end

And /^"([^\"]*)" Role Term changed to "([^\"]*)"$/ do |term_name, new_term_name|
  p = Program.find_by(root: "albers")
  mentor_term = p.roles.find_by(name: term_name).customized_term
  mentor_term.term = new_term_name
  mentor_term.term_downcase = new_term_name.downcase
  mentor_term.pluralized_term = "#{new_term_name}s"
  mentor_term.pluralized_term_downcase = "#{new_term_name}s".downcase
  mentor_term.articleized_term = "a #{new_term_name}"
  mentor_term.articleized_term_downcase = "a #{new_term_name}".downcase
  mentor_term.save!
end

Then /^I change maximum connections limit of mentor with email "([^\"]*)" in program "([^\"]*)":"([^\"]*)" to "([^\"]*)"$/ do |email, organization_subdomain, program_root, connection_limit|
  program = get_program(program_root, organization_subdomain)
  member = Member.find_by(email: email)
  user = member.user_in_program(program)
  user.update_attribute(:max_connections_limit, connection_limit)
  user.reload
end

Then /^I change engagement type of program "([^\"]*)":"([^\"]*)" to "([^\"]*)"$/ do |organization_subdomain, program_root, engagement_type|
  program = get_program(program_root, organization_subdomain)
  if engagement_type == "career based"
    change_to_engagement_type = Program::EngagementType::CAREER_BASED
  elsif engagement_type == "career based and ongoing"
    change_to_engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
  end
  program.update_attribute(:engagement_type, change_to_engagement_type)
  program.reload
end

And /^I select "([^\"]*)" for the profile question "([^\"]*)"$/ do |choice, question_text|
  profile_question = ProfileQuestion.find_by(question_text: question_text)
  step "I select \"#{choice}\" from \"profile_answers_#{profile_question.id}\""
end

Then /^I scroll to and open section "([^\"]*)" in sidepane filter$/ do |question_text|
  page.execute_script("jQuery(\"a[data-toggle=collapse]:contains(#{question_text})\").click()")
end

And /^I filter by question "([^\"]*)" with choice "([^\"]*)"$/ do |question_text, choice|
  profile_question = ProfileQuestion.find_by(question_text: question_text)
  choice_index  = profile_question.default_choices.index(choice)
  page.execute_script("jQuery(\"a[data-toggle=collapse]:contains(#{question_text})\").click()")
  if choice_index > 8
    scroll_container_height = page.evaluate_script("jQuery(\"a[data-toggle=collapse]:contains(#{question_text})\").parent().find(\"[data-slim-scroll=true]\").height()")
    scroll_top = scroll_container_height * (choice_index / 8)
    page.execute_script("jQuery(\"a[data-toggle=collapse]:contains(#{question_text})\").parent().find(\"[data-slim-scroll=true]\").scrollTop(#{scroll_top})")
  end
  check("sfpq_#{profile_question.id}_#{choice_index}")
end

Then /^I request mentoring connection from "([^\"]*)"$/ do |mentor|
  xpath="//*[descendant::*/a[contains(text(),'#{mentor}')]]/../preceding-sibling::*/a[contains(text(),'Connect')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
  xpath="//*[descendant::*/a[contains(text(),'#{mentor}')]]/../preceding-sibling::*/a[contains(text(),'Connect')]/following-sibling::ul/li/a[contains(text(), 'Request Mentoring Connection')]"
  steps %{
    And I click by xpath "#{xpath}"
  }
end