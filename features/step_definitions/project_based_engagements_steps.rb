And /^pbe program has custom term$/ do
  program = Program.find_by(root: "pbe")
  program.customized_terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).update_attributes!(
    term: "Project",
    pluralized_term: "Projects",
    articleized_term: "a Project",
    term_downcase: "project",
    pluralized_term_downcase: "projects",
    articleized_term_downcase: "a project")
end

When /^I hover over "([^\"]*)" subtab$/ do |tab_name|
  subtab_selector = ".subtabs_container:contains(\'#{tab_name}\')"
  page.execute_script(%Q[jQuery("#{subtab_selector}").mouseover()])
end

Then /^I add "([^\"]*)" permissions for "([^\"]*)"$/ do |permission, program|
  program = Program.find_by(root: program)
  program.roles.each { |role| role.add_permission('view_teachers')}
end

Then /^I select "([^\"]*)" as mentors and "([^\"]*)" as students$/ do |arg1, arg2|
  program = Program.find_by(root: "pbe")
  program_roles = program.roles.group_by(&:name)
  mentor_names, student_names = arg1.split(","), arg2.split(",")

  member_hash =  {}
  program.organization.members.each{|m|  member_hash[m.name] = m}
  
  mentor_names_string = mentor_names.collect do |mentor_name|
    member_hash[mentor_name].name_with_email
  end.join(",")

  student_names_string = student_names.collect do |student_name|
    member_hash[student_name].name_with_email
  end.join(",")  

  page.execute_script(%Q[jQuery("#group_members_role_id_#{program_roles[RoleConstants::MENTOR_NAME].first.id}").val("#{mentor_names_string}")])
  page.execute_script(%Q[jQuery("#group_members_role_id_#{program_roles[RoleConstants::STUDENT_NAME].first.id}").val("#{student_names_string}")])
end

Then /^I visit project new page$/ do
  steps %{
    And I follow "Manage"
    And I follow "Projects"
    When I follow "Create New Project"
    Then I should be on new group page in primary:pbe program
  }
end

Then /^I should see slot config setting for student as optional$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::STUDENT_NAME}")
  steps %{
    Then the "slot_config_enabled_#{role_id}" checkbox_id should be checked
    Then the "slot_config_required_#{role_id}" checkbox_id should not be checked
    And I should see "slot_config_required_#{role_id}" hidden
  }
end

Then /^I should see slot config setting for mentor as optional$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::MENTOR_NAME}")
  steps %{
    Then the "slot_config_enabled_#{role_id}" checkbox_id should be checked
    Then the "slot_config_required_#{role_id}" checkbox_id should not be checked
    And I should see "slot_config_required_#{role_id}" hidden
  }
end

Then /^I should see slot config setting for teacher as required$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::TEACHER_NAME}")
  steps %{
    Then the "slot_config_enabled_#{role_id}" checkbox_id should be checked
    Then the "slot_config_required_#{role_id}" checkbox_id should be checked
    And I should see "slot_config_required_#{role_id}" not hidden
  }
end

Then /^I should see slot config setting for student as disabled$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::STUDENT_NAME}")
  steps %{
    Then the "slot_config_enabled_#{role_id}" checkbox_id should not be checked
    Then the "slot_config_required_#{role_id}" checkbox_id should not be checked
    And I should see "slot_config_required_#{role_id}" hidden
  }
end

Then(/^I should see "(.*?)" for start date of project "(.*?)"$/) do |text, group_name|
  group = Group.find_by(name: group_name)
  step "I should see \"#{text}\" within \"div#group_pane_#{group.id} .cjs_circle_start_date_#{group.id}\""
end

Then(/^I make start date of project "(.*?)" in past$/) do |group_name|
  group = Group.find_by(name: group_name)
  group.update_attributes!(start_date: 2.days.ago)
end

Then(/^I click "(.*?)" for project "(.*?)"$/) do |click_text, group_name|
  group = Group.find_by(name: group_name)
  step "I follow \"#{click_text}\" within \"div#group_pane_#{group.id}\""
end

Then /^I enable slot config for teacher role$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::TEACHER_NAME}")
  step "I check \"slot_config_enabled_#{role_id}\""
end

Then /^I enable slot config as required for teacher role$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::TEACHER_NAME}")
  step "I check \"slot_config_enabled_#{role_id}\""
  step "I check \"slot_config_required_#{role_id}\""
end

Then /^I disable slot config for teacher role$/ do
  disable_slot_config_for_role("#{RoleConstants::TEACHER_NAME}")
end

Then /^I disable slot config for student role$/ do
  disable_slot_config_for_role("#{RoleConstants::STUDENT_NAME}")
end

Then /^I disable slot config for mentor role$/ do
  disable_slot_config_for_role("#{RoleConstants::MENTOR_NAME}")
end

Then /^the required checkbox for teacher role should be hidden$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::TEACHER_NAME}")
  step "I should see \"slot_config_required_#{role_id}\" hidden"
end

Then /^the required checkbox for teacher role should not be hidden$/ do
  role_id = get_role_id_in_pbe("#{RoleConstants::TEACHER_NAME}")
  step "I should see \"slot_config_required_#{role_id}\" not hidden"
end

Then /^I create scrap in "([^\"]*)" groups of "([^\"]*)" program$/ do |group_names, program_root|
  program = Program.find_by(root: program_root)
  group_names = group_names.strip.split(", ")

  group_names.each do |group_name|
    group = Group.find_by(name: group_name)
    create_scrap(group: group)
  end
end

Then /^I create topic in "([^\"]*)" groups of "([^\"]*)" program$/ do |group_names, program_root|
  program = Program.find_by(root: program_root)
  group_names = group_names.strip.split(", ")

  group_names.each do |group_name|
    group = Group.find_by(name: group_name)
    create_topic(forum: group.forum, user: group.mentors.first)
  end
end

Then /^I select to add "([^\"]*)" from the list of "([^\"]*)" in "([^\"]*)"$/ do |member_name, role_name, program_root|
  program = Program.find_by(root: program_root)
  add_class = ".cjs_add_" + role_name
  first_name, last_name = member_name.split(' ')
  member_with_email = program.organization.members.where(:first_name => first_name, :last_name => last_name).first.name_with_email 
  page.execute_script(%Q[jQuery('#{add_class}').find('#add_member').val('#{member_with_email}')])
end

Then /^I select to replace with "([^\"]*)" from the list of "([^\"]*)" in "([^\"]*)"$/ do |member_name, role_name, program_root|
  program = Program.find_by(root: program_root)
  replace_class = ".cjs_replace_member_handler"
  first_name, last_name = member_name.split(' ')
  member_with_email = program.organization.members.where(:first_name => first_name, :last_name => last_name).first.name_with_email 
  page.execute_script(%Q[jQuery('#{replace_class}').find('#replace_member').val('#{member_with_email}')])
end

Then /^I should see the placeholder text "([^\"]*)" in "([^\"]*)"$/ do |text, selector|
  assert page.evaluate_script("jQuery(\"#{selector}\").attr(\"placeholder\") == \"#{text}\"")
end

Then /^I fill in "([^\"]*)" as replaced user$/ do |text|
  step "I enter \"#{text}\" in \"replace_member\" autocomplete it with \"#{text}\""
end

When /^I visit (.*) project profile$/ do |scope|
  program = Program.find_by(root: "pbe")
  group = program.groups.send(scope).first
  unless group.present?
    status_hash = {
      "drafted" => Group::Status::DRAFTED,
      "pending" => Group::Status::PENDING,
      "published" => Group::Status::ACTIVE,
      "closed" => Group::Status::CLOSED
    }
    group = program.groups.create(name: "Sample Project", mentors: program.mentor_users.first(2), students: program.student_users.first(2))
    group.status = status_hash[scope]
    group.created_by = program.admin_users.first if group.drafted?
    group.pending_at = Time.now
    group.terminate!(program.admin_users.first, 'this is the reason', program.permitted_closure_reasons.first.id) if group.closed?
    group.save!
  end
  visit profile_group_path(group, subdomain: program.organization.subdomain, root: program.root)
end

Then /^I should see "([^\"]*)" in admin actions pane$/ do |arg1|
  admin_actions = arg1.split(",")
  admin_actions.each do |action|
    within "#admin_actions" do
      step "I should see \"#{action}\""
    end
  end
end

Then /^I should see "([^\"]*)" label beside the project name$/ do |arg1|
  within "#page_heading" do
    step "I should see \"#{arg1}\""
  end
end

And /^I click join project to join "([^\"]*)"$/ do |project_name|
  program = Program.find_by(root: "pbe")
  project = program.groups.pending.find_by(name: project_name)
  page.execute_script(%Q[jQuery(".cjs_request_group_#{project.id}").first().click()])
end

When /^I enable "([^\"]*)" for "([^\"]*)" in "([^\"]*)":"([^\"]*)"$/ do |permission, role_name, organization_subdomain, program_root|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  role.add_permission(permission)
  role.save!
end

And /^I click on actions of "([^\"]*)" project$/ do |project_name|
  page.execute_script(%Q[jQuery(".list-group-item:contains(\'#{project_name}\')").find("a.btn-primary").first().click()])
end

Then /^the help text for "([^"]*)" role in "([^"]*)":"([^"]*)" should (?:(not ))?be visible$/ do |role_name, organization_subdomain, program_root, visible_or_not|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  step "\"#limit-help-text-#{role.id}\" should #{visible_or_not.to_s}be visible"
end

Then /^I should see "([^"]*)" of "([^"]*)":"([^"]*)" with idprefix "([^"]*)" unchecked$/ do |role_name, organization_subdomain, program_root, idprefix|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  assert_false page.evaluate_script("jQuery(\"##{idprefix + role.id.to_s}\").is(':checked')")
end

Then /^I check "([^"]*)" of "([^"]*)":"([^"]*)" having idprefix as "([^"]*)"$/ do |role_name, organization_subdomain, program_root, idprefix|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  step "I check \"#{idprefix + role.id.to_s}\""
end

Then /^I should see "([^"]*)" of "([^"]*)":"([^"]*)" with idprefix "([^"]*)" checked$/ do |role_name, organization_subdomain, program_root, idprefix|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  assert page.evaluate_script("jQuery(\"##{idprefix + role.id.to_s}\").is(':checked')")
end

Then /^I uncheck "([^"]*)" of "([^"]*)":"([^"]*)" having idprefix as "([^"]*)"$/ do |role_name, organization_subdomain, program_root, idprefix|
  program = get_program(program_root, organization_subdomain)
  role = program.get_role(role_name)
  step "I uncheck \"#{idprefix + role.id.to_s}\""
end

Then /^I "([^\"]*)" member with email "([^\"]*)" in "([^\"]*)" as "([^\"]*)"$/ do |action, email, root, role_name|
  member = Member.find_by(email: email)
  program = Program.find_by(root: root)
  user_id = member.user_in_program(program).id
  role = program.get_role(role_name)
  within ".cjs_remove_replace_#{user_id}" do
    step "I click \".cjs_#{action.downcase}_member\""
    if action == "Replace"
      step "I should see the placeholder text \"Enter the #{role.customized_term.term}'s name\" in \"#replace_member_#{role_name}_#{user_id}\""
    end
  end
end

Then /^I should see the "([^\"]*)" role can(?:( not))? be added by owners in the program "([^\"]*)"$/ do |role_name, can_or_not, program_name|
  program = Program.find_by(name: program_name)
  role = program.roles.find_by(name: role_name)
  step "the \"program_role_#{role.id}_can_be_added_by_owners\" checkbox_id should#{can_or_not.to_s} be checked"
end

Then /^I (?:(un))?check "([^\"]*)" role can be added by owners in the program "([^\"]*)"$/ do |check_or_not, role_name, program_name|
  program = Program.find_by(name: program_name)
  role = program.roles.find_by(name: role_name)
  step "I #{check_or_not}check \"program_role_#{role.id}_can_be_added_by_owners\""
end

Then /^I (?:(un))?check "([^\"]*)" role can apply to join project in the program "([^\"]*)"$/ do |check_or_not, role_name, program_name|
  program = Program.find_by(name: program_name)
  role = program.roles.find_by(name: role_name)
  step "I #{check_or_not}check \"program_role_permissions_#{role.id}_send_project_request\""
end

Then /^I update allow users to leave connection setting for "([^\"]*)" program to true$/ do |program_name|
  Program.find_by(name: program_name).update_attributes!(allow_users_to_leave_connection: true)
end

Then /^apply to join for "([^\"]*)" should be disabled$/ do |role_name|
  program = get_program("pbe", "primary")
  role = program.find_role(role_name)
  step "element with id \"#dummy_send_project_request_checkbox_#{role.id}\" should be disabled"
end

Then /^I follow publish for group "([^\"]*)"$/ do |group_name|
  group_id = get_group(group_name).id
  within "#group_#{group_id}" do
    step %Q[I follow "Publish Project"]
  end
end

And /^users with roles "([^\"]*)" should( not)? be allowed to send requests to "([^\"]*)"$/ do |role_names, negate, group_name|
  group = get_group(group_name)
  role_names = role_names.split(",")
  program = get_program("pbe", "primary")
  role_ids = program.roles.for_mentoring.where(name: role_names).pluck(:id)
  available_roles = group.available_roles_for_joining(role_ids)
  if negate
    assert_equal 0, available_roles.size
  else
    assert_equal role_ids.size, available_roles.size
  end
end

And /^I clear project prequests of "([^\"]*)"$/ do |group_name|
  group = get_group(group_name)
  group.project_requests.delete_all
end

Then /^I remove join requests permission for "([^\"]*)"$/ do |role_names|
  role_names = role_names.split(",")
  program = get_program("pbe", "primary")
  role_names.each do |role_name|
    role_id = program.roles.for_mentoring.find_by(name: role_name).id
    step %Q[I uncheck "group_role_permission_#{role_id}"]
  end
  step %Q[I confirm modal]
end

When(/^I make member with email "(.*?)" as owner of project with name "(.*?)"$/) do |user_email, group_name|
  group = Group.find_by(name: group_name)
  group_user = group.members.find{|user| user.email == user_email}
  group.membership_of(group_user).update_attributes!(owner: true)
end

When(/^I change pending date of project with name "(.*?)" to "(.*?)" days ago$/) do |group_name, days_ago|
  group = Group.find_by(name: group_name)
  group.update_attributes!(pending_at: days_ago.to_i.days.ago)
end

Then(/^I should see available for info for project with name "(.*?)"$/) do |group_name|
  group = Group.find_by(name: group_name)
  pending_for_days = (Date.today - group.pending_at.to_date).to_i
  step %Q[I should see "Available for #{pending_for_days} days" within "div#cjs_publish_circles_widget"]
end

Then /^I publish group "([^\"]*)"$/ do |group_name|
  group = get_group(group_name)
  group.publish(group.program.admin_users.first, "test message")
end

Then /^default tasks must( not)? be copied to the new user$/ do |negate|
  if negate
    Group::MentoringModelCloner.any_instance.expects(:copy_template_tasks_for_memberships).never
  else
    Group::MentoringModelCloner.any_instance.expects(:copy_template_tasks_for_memberships).once
  end
end

Then /^I make the group "([^\"]*)" critical mass$/ do |group_name|
  group = get_group(group_name)
  program = group.program
  group.send(:update_members_by_role, program.roles.find_by(name: RoleConstants::TEACHER_NAME), [program.teacher_users.first], nil)
  group.update_column(:pending_at, 10.days.ago)
end

Then /^I stub project requests path for "(.*?)" for "(.*?)" group$/ do |user, group_name|
  group = Group.find_by(name: group_name)
  params = { filtered_group_ids: [group.id], from_bulk_publish: false, track_publish_ga: true, ga_src: @ga_src, src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET, root: group.program.root }
  ProjectRequest.stubs(:get_project_request_path_for_privileged_users).returns(get_project_requests_path_for_user(user, params))
end

Then /^I stub project requests path for "(.*?)" for the program "(.*?)"$/ do |user, program_root|
  ProjectRequest.stubs(:get_project_request_path_for_privileged_users).returns(get_project_requests_path_for_user(user, {root: program_root}))
end

private

def disable_slot_config_for_role(role_name)
  role_id = get_role_id_in_pbe(role_name)
  step "I uncheck \"slot_config_enabled_#{role_id}\""
end

def get_role_id_in_pbe(role_name)
  program = Program.find_by(root: "pbe")
  program.get_role(role_name).id
end

def get_group(group_name)
  program = get_program("pbe", "primary")
  program.groups.find_by(name: group_name)
end

def get_project_requests_path_for_user(user, params)
  return manage_project_requests_path(params) if user == "admin"
  project_requests_path(params)
end