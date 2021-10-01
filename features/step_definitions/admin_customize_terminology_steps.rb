Then /^I fill the custom terms in "([^\"]*)"$/ do |subdomain|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  term = organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Track"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Tracks"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Track"
  }
  term = organization.admin_custom_term
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Admin"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Admins"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "an Admin"
    Then I press "Save"
  }
end

Then /^I fill the custom program terms in "([^\"]*)":"([^\"]*)"$/ do |subdomain, program_root|
  program = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain).programs.find_by(root: program_root)
  term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Link"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Links"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Link"
  }
  term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Trainer"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Trainers"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Trainer"
  }
  term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Trainee"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Trainee"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Trainee"
  }
  if program.roles.with_name(RoleConstants::TEACHER_NAME).present?
    term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::TEACHER_NAME)
    steps %{
      Then I fill in "customized_term_#{term.id}_term" with "Coach"
      Then I fill in "customized_term_#{term.id}_pluralized_term" with "Coaches"
      Then I fill in "customized_term_#{term.id}_articleized_term" with "a Coach"
    }
  end
  term = program.term_for(CustomizedTerm::TermType::ARTICLE_TERM)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Snippet"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Snippets"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Snippet"
  }
  term = program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Helpdesk"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Helpdesks"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Helpdesk"
  }
  term = program.term_for(CustomizedTerm::TermType::MEETING_TERM)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Session"
    Then I fill in "customized_term_#{term.id}_pluralized_term" with "Sessions"
    Then I fill in "customized_term_#{term.id}_articleized_term" with "a Session"
    Then I press "Save"
  }
end

Then /^I fill the standalone custom terms in "([^\"]*)"$/ do |subdomain|
  organization = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,subdomain)
  term = organization.term_for(CustomizedTerm::TermType::PROGRAM_TERM)
  step "I fill in \"customized_term_#{term.id}_term\" with \"Track\""
  term = organization.admin_custom_term
  step "I fill in \"customized_term_#{term.id}_term\" with \"Admin\""
  program = organization.programs.ordered.first
  term = program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
  step "I fill in \"customized_term_#{term.id}_term\" with \"Link\""
  term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
  step "I fill in \"customized_term_#{term.id}_term\" with \"Trainer\""
  term = program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME)
  step "I fill in \"customized_term_#{term.id}_term\" with \"Trainee\""
  term = program.term_for(CustomizedTerm::TermType::ARTICLE_TERM)
  step "I fill in \"customized_term_#{term.id}_term\" with \"Snippet\""
  term = program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)
  step "I fill in \"customized_term_#{term.id}_term\" with \"Helpdesk\""
  term = program.term_for(CustomizedTerm::TermType::MEETING_TERM)
  steps %{
    Then I fill in "customized_term_#{term.id}_term" with "Session"
    Then I press "Save"
  }
end
