When /^I enable end users to propose groups$/ do
  prog = Program.find_by(root: "pbe")
  prog.roles.for_mentoring.each do |role|
    role.add_permission(RolePermission::PROPOSE_GROUPS)
  end
end

When /^I cleanup the existing groups in rejected and proposed state$/ do
  prog = Program.find_by(root: "pbe")
  prog.groups.where(status: [Group::Status::PROPOSED, Group::Status::REJECTED]).destroy_all
end

When /^I create sample questions for pbe program$/ do
  program = Program.find_by(root: "pbe")
  program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")
end

Then /^I fill in the last connection question with "([^"]*)"$/ do |content|
  connection_question = Connection::Question.last
  step "I fill in \"common_answers_#{connection_question.id}\" with \"#{content}\""
end

Then /^I click on the link "([^"]*)" of "([^"]*)"$/ do |sub_selector, group_name|
  # No other way, but to find_by_name, though name is not a primary key :(
  group = Group.find_by(name: group_name)
  step "I click \"##{sub_selector + group.id.to_s}\""
end

Then /^I select all group columns$/ do
  within "div.multiselect-available-list" do
    step "I click \"span.ui-icon-arrowthickstop-1-e\""
  end  
  step "I click \"#cjs_update_view .form-actions .btn-primary\""
end

Then /^I fill in "([^"]*)" field with prefix "([^"]*)" of "([^"]*)":"([^"]*)" with "([^"]*)"$/ do |role_name, prefix, organization_subdomain, program_root, content|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  step "I fill in \"#{prefix}#{role.id}\" with \"#{content}\""
end