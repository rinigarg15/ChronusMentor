# encoding: utf-8
Given /^there is a mentoring connection between the mentor "([^\"]*)" and the students "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |mentor_emails_str, student_emails_str, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  allow_one_to_many_mentoring_for_program(program)
  student_emails = student_emails_str.split(",")
  mentor_emails = mentor_emails_str.split(",")

  assert_difference 'Group.count' do
    Group.create!(
      :mentors => mentor_emails.collect{|e| User.find_by_email_program(e, program)},
      :students => student_emails.collect{|e| User.find_by_email_program(e, program)},
      :program => program
    )
  end
end

Given /^"([^\"]*)" is a student in "([^\"]*)":"([^\"]*)"$/ do |student_email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  student = User.find_by_email_program(student_email, program)
  student.add_role(RoleConstants::STUDENT_NAME) unless student.is_student?
end

Given /^"([^\"]*)" made a post in the mentoring connection with the student "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |mentor_email, student_email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  create_group_scrap(:mentor, mentor_email, student_email, program)
end

Given /^"([^\"]*)" made a post in the mentoring connection with the mentor "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |student_email, mentor_email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  create_group_scrap(:student, mentor_email, student_email, program)
end

Given /^there is a goal named "([^\"]*)" for "([^\"]*)" in the mentoring connection with the mentor "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |goal_title, student_email, mentor_email, subdomain, prog_root|
  program = get_program(prog_root, subdomain)
  mentor = User.find_by_email_program(mentor_email, program)
  student = User.find_by_email_program(student_email, program)
  group = program.groups.involving(student, mentor).first
  task = group.tasks.new(
    :student_membership => group.membership_of(student),
    :title => goal_title, :due_date => 2.days.from_now)
  task.saver = mentor
  task.save!
end

def create_group_scrap(actor_id, mentor_email, student_email, program)
  mentor = User.find_by_email_program(mentor_email, program)
  student = User.find_by_email_program(student_email, program)
  group = program.groups.involving(student, mentor).first
  actor = (actor_id == :mentor) ? mentor : student
  group.scraps.create!(:connection_membership => group.membership_of(actor), :message => 'Hello')
end

Given /^I visit the mentoring connection between "([^\"]*)" and "([^\"]*)" with the reason "([^\"]*)"$/ do |arg1, arg2, arg3|
  student_arg = arg2.split(",")[0]
  org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
  program = org.programs.find_by(root: "albers")
  m_student = org.members.find_by(email: student_arg)
  m_mentor = org.members.find_by(email: arg1)
  u_student = m_student.user_in_program(program)
  u_mentor = m_mentor.user_in_program(program)
  g = Group.involving(u_student, u_mentor).first
  visit group_path(g, :root => "albers")
  steps %{
    And I fill in "confidentiality_audit_log_reason" with "#{arg3}"
    Then I press "Proceed »"
  }
end

Then /^I should not see edit action for feedback question of mode (\d+)$/ do |arg1|
  program = Program.find_by(root: "albers")
  survey = program.feedback_survey
  question = survey.survey_questions.find_by(question_mode: arg1)
  step "I should not see \"Edit\" within \"#common_question_value_#{question.id}\""
end

Then /^I see warning for removing feedback question of mode (\d+)$/ do |arg1|
  program = Program.find_by(root: "albers")
  survey = program.feedback_survey
  question = survey.survey_questions.find_by(question_mode: arg1)
  within "#common_question_value_#{question.id}" do
    steps %{
      Then I click ".dropdown-toggle"
      Then I follow "Remove"
    }
  end
  steps %{
    Then I should see "Program Health Report"
    Then I confirm popup
  }
end

Then /^I enable admin audit logs$/ do
  steps %{
    And I login as super user
    And I follow "Manage"
    And I follow "Program Settings"
    And I follow "Permissions"
    Then I should see "Audited access"
    Then I choose "admin_access_audited"
    And I press "Save"
    And I logout as super user
  }
end
