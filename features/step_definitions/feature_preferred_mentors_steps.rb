And /^I add "([^\"]*)" to preferred mentors list$/ do |email|
  member = Member.where(:email => email).first
  user = member.users.first
  within(first("#mentor_#{user.id}")) do
    steps %{
      And I click ".dropdown-toggle"
      And I follow "Add to preferred mentors"
    }
  end
end

And /^I should see "([^\"]*)" "([^\"]*)" for "([^\"]*)" mentor with email "([^\"]*)"$/ do |action, state, program_root, email|
  member = Member.where(email: email).first
  program = Program.find_by(root: program_root)
  user = member.user_in_program program
  within("#mentor_#{user.id}") do
    step "I click \".dropdown-toggle\""
    if state == "disabled"
      step "I should see disabled \"#{action}\""
    elsif state == "not present"
      step "I should not see \"#{action}\""
    else
      step "I should see \"#{action}\""
    end
  end
end

And /^I suspend "([^\"]*)" from admin users page$/ do |email|
  member = Member.find_by(email: email)
  user = member.users.first
  steps %{
    And I check "ct_admin_view_checkbox_#{user.id}"
    And I click on "cjs_suspend_membership" in Actions
    And I should see "Deactivate Membership" within "div.modal-dialog"
    And I fill in "admin_view_reason" with "Some reason"
    And I press "Submit"
  }
end

And /^I reactivate "([^\"]*)" from admin users page$/ do |email|
  member = Member.find_by(email: email)
  user = member.users.first
  programs_term = member.organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM).pluralized_term_downcase
  steps %{
    And I check "ct_admin_view_checkbox_#{user.id}"
    And I click on "cjs_reactivate_membership" in Actions
    Then I should see "Note: Users who are suspended at #{member.organization.name} cannot be reactivated in #{user.program.name} alone."
    And I press "Submit"
  }
end

And /^I remove "([^\"]*)" from admin users page$/ do |email|
  member = Member.where(:email => email).first
  user = member.users.first
  steps %{
    And I check "ct_admin_view_checkbox_#{user.id}"
    And I click on "cjs_remove_from_program" in Actions
    Then I should see "Remove User"
    And I press "Remove"
  }
end

When /^I set "([^\"]*)" state to pending$/ do |email|
  member = Member.where(:email => email).first
  member.users.each do |user| 
    user.state = User::Status::PENDING
    user.save!
  end
end

And /^I add "([^\"]*)" role to "([^\"]*)" from admin users page$/ do |role, email|
  member = Member.find_by(email: email)
  user = member.users.first
  steps %{
    And I check "ct_admin_view_checkbox_#{user.id}"
    And I click on "cjs_add_role" in Actions
    Then I should see "Note: This action does not apply for users suspended in #{member.organization.name}."
    And I check "#{role}"
    And I press "Submit"
  }
end