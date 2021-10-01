require_relative './../../test_helper.rb'

class AdminActionsHelperTest < ActionView::TestCase

  def test_admin_panel_actions_for_mentor
    program = admin_panel_action_setup[0]
    mentor = users(:f_mentor)
    mentor_member = mentor.member
    all_users_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)

    actions = admin_panel_actions(mentor, program)
    actions_html = safe_join(actions, " ")
    assert_equal 10, actions.size
    assert_select_helper_function "hr", actions_html, count: 3
    assert_select_helper_function_block "li.admin_panel_action", actions_html, count: 7 do
      assert_select "a", count: 7
      assert_select "a", text: "Work on Behalf", href: work_on_behalf_user_path(mentor)
      assert_select "a", text: "Edit #{mentor.name}'s profile", href: edit_member_path(mentor_member)
      assert_select "a", text: "Download profile as PDF", href: member_path(mentor_member, format: :pdf)
      assert_select "a", text: "Change Roles", href: "javascript:void(0)", "data-url" => fetch_change_roles_user_path(mentor)
      assert_select "a", text: "Resend Sign up Instructions", href: resend_signup_instructions_admin_view_path(all_users_view, admin_view: { users: mentor.id.to_s }, from: AdminViewsController::REFERER::MEMBER_PATH)
      assert_select "a", text: "Deactivate Membership", href: "javascript:void(0)", "data-target" => "#modal_suspend_link_#{mentor.id}", "data-toggle" => "modal"
      assert_select "a", text: "Remove #{mentor.name}", href: "javascript:void(0)", "data-target" => "#modal_remove_link_#{mentor.id}", "data-toggle" => "modal"
    end
  end

  def test_admin_panel_actions_for_student
    program = admin_panel_action_setup[0]
    student = users(:f_student)
    student_member = student.member
    all_users_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)

    actions = admin_panel_actions(student, program)
    actions_html = safe_join(actions, " ")
    assert_equal 11, actions.size
    assert_select_helper_function "hr", actions_html, count: 3
    assert_select_helper_function_block "li.admin_panel_action", actions_html, count: 8 do
      assert_select "a", count: 8
      assert_select "a", text: "Find a Trainer", href: matches_for_student_users_path(student_name: student.name_with_email, src: "students_profile")
      assert_select "a", text: "Work on Behalf", href: work_on_behalf_user_path(student)
      assert_select "a", text: "Edit #{student.name}'s profile", href: edit_member_path(student_member)
      assert_select "a", text: "Download profile as PDF", href: member_path(student_member, format: :pdf)
      assert_select "a", text: "Change Roles", href: "javascript:void(0)", "data-url" => fetch_change_roles_user_path(student)
      assert_select "a", text: "Resend Sign up Instructions", href: resend_signup_instructions_admin_view_path(all_users_view, admin_view: { users: student.id.to_s }, from: AdminViewsController::REFERER::MEMBER_PATH)
      assert_select "a", text: "Deactivate Membership", href: "javascript:void(0)", "data-target" => "#modal_suspend_link_#{student.id}", "data-toggle" => "modal"
      assert_select "a", text: "Remove #{student.name}", href: "javascript:void(0)", "data-target" => "#modal_remove_link_#{student.id}", "data-toggle" => "modal"
    end
  end

  def test_find_mentor_admin_panel_action
    program = admin_panel_action_setup[0]
    student = users(:f_student)

    content = self.send(:find_mentor_admin_panel_action, student, program)
    assert_select_helper_function_block "span", content do
      assert_select "a", text: "Find a Trainer", href: matches_for_student_users_path(student_name: student.name_with_email, src: "students_profile")
    end
    assert_nil self.send(:find_mentor_admin_panel_action, users(:f_mentor), program)

    program.stubs(:ongoing_mentoring_enabled?).returns(false)
    assert_nil self.send(:find_mentor_admin_panel_action, student, program)

    program.stubs(:ongoing_mentoring_enabled?).returns(true)
    program.stubs(:project_based?).returns(true)
    assert_nil self.send(:find_mentor_admin_panel_action, student, program)

    program.stubs(:project_based?).returns(false)
    student.stubs(:connection_limit_as_mentee_reached?).returns(true)
    content = self.send(:find_mentor_admin_panel_action, student, program)
    assert_select_helper_function_block "span", content, text: "Find a Trainer", "data-toggle" => "tooltip", "data-title" => "The user has reached the maximum connection limit set for trainees" do
      assert_no_select "a"
    end

    student.stubs(:connection_limit_as_mentee_reached?).returns(false)
    student.stubs(:suspended?).returns(true)
    content = self.send(:find_mentor_admin_panel_action, student, program)
    assert_select_helper_function_block "span", content, text: "Find a Trainer", "data-toggle" => "tooltip", "data-title" => "#{student.name} is currently inactive" do
      assert_no_select "a"
    end
  end

  def test_wob_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_mentor)

    content = self.send(:wob_admin_panel_action, user, program)
    assert_select_helper_function "a", content, text: "Work on Behalf", href: work_on_behalf_user_path(user)
    assert_match(/Click to work on behalf of.*#{user.name}/, content)
    assert_nil self.send(:wob_admin_panel_action, users(:f_admin), program)

    self.expects(:working_on_behalf?).once.returns(true)
    assert_nil self.send(:wob_admin_panel_action, user, program)

    self.expects(:working_on_behalf?).at_least(0).returns(false)
    admin.stubs(:can_work_on_behalf?).returns(false)
    assert_nil self.send(:wob_admin_panel_action, user, program)

    admin.stubs(:can_work_on_behalf?).returns(true)
    program.stubs(:has_feature?).with(FeatureName::WORK_ON_BEHALF).returns(false)
    assert_nil self.send(:wob_admin_panel_action, user, program)

    program.stubs(:has_feature?).with(FeatureName::WORK_ON_BEHALF).returns(true)
    user.member.admin = true
    admin.member.admin = false
    assert_nil self.send(:wob_admin_panel_action, user, program)
  end

  def test_view_or_edit_profile_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_student)
    member = user.member

    content = self.send(:view_or_edit_profile_admin_panel_action, user, true)
    assert_select_helper_function "a", content, text: "View #{user.name}'s profile", href: member_path(member)
    content = self.send(:view_or_edit_profile_admin_panel_action, user, false)
    assert_select_helper_function "a", content, text: "Edit #{user.name}'s profile", href: edit_member_path(member)
  end

  def test_download_profile_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_student)

    content = self.send(:download_profile_admin_panel_action, user)
    assert_select_helper_function "a", content, text: "Download profile as PDF", href: member_path(user.member, format: :pdf)
    assert_match(/Click to download profile of.*#{user.name}.*as PDF./, content)
    assert_nil self.send(:download_profile_admin_panel_action, admin)
  end

  def test_resend_signup_instructions_admin_panel_action
    program, admin = admin_panel_action_setup
    all_users_view = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    user = users(:f_mentor)

    resend_signup_url = resend_signup_instructions_admin_view_path(all_users_view, admin_view: { users: user.id.to_s }, from: AdminViewsController::REFERER::MEMBER_PATH)
    content = self.send(:resend_signup_instructions_admin_panel_action, user, program)
    assert_select_helper_function "a", content, text: "Resend Sign up Instructions", href: resend_signup_url, "data-confirm" => /An.*email.*with sign up instructions will be sent to the user even if they are already signed up, are you sure\?/
    assert_nil self.send(:resend_signup_instructions_admin_panel_action, admin, program)
  end

  def test_resend_signup_confirmation
    program, admin = admin_panel_action_setup
    user = users(:f_student)
    mailer_uid = ResendSignupInstructions.mailer_attributes[:uid]

    content = self.send(:resend_signup_confirmation, user)
    assert_select_helper_function_block "div", content, text: "An email with sign up instructions will be sent to the user even if they are already signed up, are you sure?" do
      assert_select "a", href: mailer_template_path(mailer_uid), text: "email", target: "_blank"
    end
    assert_match(/#{user.name} has.*already signed up.*in #{@current_organization.name}/, content)

    user.stubs(:requires_signup?).returns(true)
    content = self.send(:resend_signup_confirmation, user)
    assert_select_helper_function_block "div", content, text: "An email with sign up instructions will be sent to the user even if they are already signed up, are you sure?" do
      assert_select "a", href: mailer_template_path(mailer_uid), text: "email", target: "_blank"
    end
    assert_no_match(/#{user.name} has.*already signed up.*in #{@current_organization.name}/, content)
  end

  def test_change_roles_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_student)

    content = self.send(:change_roles_admin_panel_action, user)
    assert_select_helper_function "a.remote-popup-link", content, text: "Change Roles", href: "javascript:void(0)", "data-url" => fetch_change_roles_user_path(user)

    admin.stubs(:can_manage_user_states?).returns(false)
    assert_nil self.send(:change_roles_admin_panel_action, user)

    admin.stubs(:can_manage_user_states?).returns(true)
    user.member.stubs(:active?).returns(false)
    assert_nil self.send(:change_roles_admin_panel_action, user)
  end

  def test_suspend_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_student)

    self.expects(:render).with(partial: "users/suspend_user", locals: { profile_user: user } ).once
    content = self.send(:suspend_or_reactivate_admin_panel_action, user)
    assert_select_helper_function "a", content, text: "Deactivate Membership", href: "javascript:void(0)", "data-target" => "#modal_suspend_link_#{user.id}", "data-toggle" => "modal"
    assert_match(/Clicking here will deactivate the membership of.*#{user.name}.*from the track and.*#{user.name}.*will no longer have access to the track/, content)
    assert_nil self.send(:suspend_or_reactivate_admin_panel_action, admin)

    admin.expects(:can_remove_or_suspend?).with(user).at_least(0).returns(false)
    assert_nil self.send(:suspend_or_reactivate_admin_panel_action, user)

    admin.expects(:can_remove_or_suspend?).with(user).at_least(0).returns(true)
    admin.stubs(:can_manage_user_states?).returns(false)
    assert_nil self.send(:suspend_or_reactivate_admin_panel_action, user)
  end

  def test_reactivate_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_mentor)

    admin.stubs(:can_remove_or_suspend?).with(user).returns(false)
    assert_nil self.send(:suspend_or_reactivate_admin_panel_action, user)

    user.stubs(:suspended?).returns(true)
    content = self.send(:suspend_or_reactivate_admin_panel_action, user)
    assert_select_helper_function "a", content, text: "Reactivate Membership", href: change_user_state_user_path(user, new_state: User::Status::ACTIVE), "data-confirm" => /An.*email.*will be sent to the user if you complete this action. Are you sure you want to reactivate\?/
    assert_match(/Click to reactivate.*#{user.name}.*in the track/, content)

    user.member.stubs(:suspended?).returns(true)
    content = self.send(:suspend_or_reactivate_admin_panel_action, user)
    assert_select_helper_function "span", content, text: "Reactivate Membership"
    assert_match(/#{user.name}.*profile was deactivated for all tracks. The profile can only be reactivated at #{@current_organization.name}/, content)
    assert_no_match("href", content)
  end

  def test_remove_admin_panel_action
    program, admin = admin_panel_action_setup
    user = users(:f_mentor)

    self.expects(:render).with(partial: "users/remove_user", locals: { profile_user: user } ).once
    content = self.send(:remove_admin_panel_action, user)
    assert_select_helper_function "a", content, text: "Remove #{user.name}", href: "javascript:void(0)", "data-target" => "#modal_remove_link_#{user.id}", "data-toggle" => "modal"
    assert_match(/Click to remove.*#{user.name}.*from the track permanently/, content)

    admin.expects(:can_remove_or_suspend?).with(user).at_least(0).returns(false)
    assert_nil self.send(:remove_admin_panel_action, user)
  end

  def test_admin_panel_actions_wrapper
    content = self.send(:admin_panel_actions_wrapper, "Hi!")
    assert_select_helper_function "li", content, text: "Hi!", class: "admin_panel_action list-group-item no-borders"
  end

  def test_member_admin_panel_actions
    admin = member_admin_panel_action_setup
    member = members(:f_mentor)

    self.expects(:render).with(partial: "members/add_member_to_program", locals: { member: member } ).once
    self.expects(:render).with(partial: "members/add_member_to_program_as_admin", locals: { member: member } ).once
    self.expects(:render).with(partial: "members/suspend_member", locals: { member: member } ).once
    self.expects(:render).with(partial: "members/remove_member", locals: { member: member } ).once
    actions = member_admin_panel_actions(member)
    actions_html = safe_join(actions, " ")
    assert_equal 5, actions.size
    assert_select_helper_function_block "li.admin_panel_action", actions_html, count: 5 do
      assert_select "a", count: 5
      assert_select "a", text: "Invite User To Track", href: "javascript:void(0)", "data-target" => "#modal_invite_user_to_program", "data-toggle" => "modal"
      assert_select "a", text: "Add User To Track", href: "javascript:void(0)", "data-target" => "#modal_add_user_to_program", "data-toggle" => "modal"
      assert_select "a", text: "Add User as Track Admin", href: "javascript:void(0)", "data-target" => "#modal_add_user_to_program_as_admin", "data-toggle" => "modal"
      assert_select "a", text: "Suspend Membership", href: "javascript:void(0)", "data-target" => "#modal_suspend_membership_link", "data-toggle" => "modal"
      assert_select "a", text: "Remove #{member.name}", href: "javascript:void(0)", "data-target" => "#modal_remove_member_link", "data-toggle" => "modal"
    end

    assert_empty member_admin_panel_actions(admin)
  end

  def test_member_admin_panel_actions_suspended_member
    member_admin_panel_action_setup
    member = members(:f_mentor)

    member.stubs(:suspended?).returns(true)
    self.expects(:render).with(partial: "members/remove_member", locals: { member: member } ).once
    actions = member_admin_panel_actions(member)
    actions_html = safe_join(actions, " ")
    assert_equal 2, actions.size
    assert_select_helper_function_block "li.admin_panel_action", actions_html, count: 2 do
      assert_select "a", count: 2
      assert_select "a", text: "Reactivate Membership", href: update_state_member_path(member), "data-confirm" => /Are you sure you want to reactivate #{member.name}\'s membership\?.*An.*email.*will be sent to the member if you complete this action/
      assert_select "a", text: "Remove #{member.name}", href: "javascript:void(0)", "data-target" => "#modal_remove_member_link", "data-toggle" => "modal"
    end
    assert_match(/Click to reactivate.*#{member.name}.*in the organization/, actions_html)
  end

  def test_get_reactivate_member_confirmation
    member_admin_panel_action_setup
    member = members(:f_student)

    content = self.send(:get_reactivate_member_confirmation, member)
    assert_select_helper_function "a", content, text: "email", href: edit_mailer_template_path(MemberActivationNotification.mailer_attributes[:uid], src: GA_TRACKER_READ_SYSEMAIL)
    assert_match(/Are you sure you want to reactivate #{member.name}.*membership\?.*An.*email.*will be sent to the member if you complete this action/, content)
  end

  def test_group_panel_actions
    user = users(:f_admin_pbe)
    group = groups(:group_pbe)
    user.stubs(:is_only_owner_of?).returns("is_owner")

    self.expects(:current_user).at_least(0).returns(user)
    self.expects(:make_available_panel_action).with(group, "is_owner").once
    self.expects(:accept_and_mark_available_panel_action).with(group, "is_owner").once
    self.expects(:publish_group_panel_action).with(group).once
    self.expects(:edit_group_profile_action).with(group).once
    self.expects(:assign_template_panel_action).with(group, "is_owner").once
    self.expects(:project_requests_panel_action).with(group).once
    self.expects(:manage_members_panel_action).with(group).once
    self.expects(:add_remove_owners_panel_action).with(group).once
    self.expects(:allow_stop_user_requests_panel_action).with(group).once
    self.expects(:close_group_panel_action).once
    self.expects(:reactivate_group_panel_action).with(group).once
    self.expects(:discard_group_panel_action).with(group, "is_owner").once
    self.expects(:reject_project_panel_action).with(group, "is_owner").once
    self.expects(:withdraw_group_panel_action).with(group).once

    group_panel_actions(group)
  end

  def test_make_available_panel_action
    group = create_group(mentors: [users(:f_mentor_pbe)], students: [users(:f_student_pbe)], program: programs(:pbe), status: Group::Status::DRAFTED, creator_id: users(:f_admin_pbe).id)
    stub_current_program(group.program)
    assert_nil self.send(:make_available_panel_action, group, true)

    content = self.send(:make_available_panel_action, group, false)
    assert_match "Make Mentoring Connection Available", content[:label]
    assert_equal ShowQtip(fetch_bulk_actions_groups_path(individual_action: true, src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::MAKE_AVAILABLE})), content[:js]
  end

  def test_accept_and_mark_available_panel_action
    group = groups(:proposed_group_1)
    assert_nil self.send(:accept_and_mark_available_panel_action, group, true)

    content = self.send(:accept_and_mark_available_panel_action, group, false)
    assert_match "Accept & Make Available", content[:label]
    assert_equal ShowQtip(fetch_bulk_actions_groups_path(individual_action: true, src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::ACCEPT_PROPOSAL})), content[:js]
  end

  def test_publish_group_panel_action
    assert_nil publish_group_panel_action(groups(:group_pbe))
    group = groups(:group_pbe_0)

    content = publish_group_panel_action(group)
    assert_match "Publish Mentoring Connection", content[:label]
    assert_equal ShowQtip(fetch_publish_group_path(group, src: "profile")), content[:js]
  end

  def test_edit_group_profile_action
    group = groups(:group_pbe)
    stub_current_program(group.program)

    content = edit_group_profile_action(group)
    assert_match "Edit Mentoring Connection Profile", content[:label]
    assert_equal edit_answers_group_path(group), content[:url]

    group.terminate!(users(:f_admin_pbe), "Closure reason", group.get_auto_terminate_reason_id, Group::TerminationMode::INACTIVITY)
    assert_nil edit_group_profile_action(group)
  end

  def test_assign_template_panel_action
    group = groups(:group_pbe)
    stub_current_program(group.program)
    assert_nil assign_template_panel_action(group, true)
    assert_nil assign_template_panel_action(group, false)

    group = groups(:drafted_group_3)
    content = assign_template_panel_action(group, false)
    assert_match "Assign Mentoring Connection Plan Template", content[:label]
    assert_equal ShowQtip(fetch_bulk_actions_groups_path(individual_action: true, src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::ASSIGN_TEMPLATE})), content[:js]
  end

  def test_project_requests_panel_action
    group = groups(:group_pbe)
    stub_current_program(group.program)
    assert_nil project_requests_panel_action(group)
    @current_user = users(:f_admin_pbe)

    ProjectRequest.expects(:get_project_request_path_for_privileged_users).with(@current_user, filters: { project: group.name }, from_quick_link: true, from_profile: true).returns(project_requests_path(filters: { project: group.name }, from_quick_link: true, from_profile: true))
    group.stubs(:active_project_requests).returns([1,2,3])
    content = project_requests_panel_action(group)
    assert_match "Requests to Join", content[:label]
    assert_equal project_requests_path(filters: { project: group.name }, from_quick_link: true, from_profile: true), content[:url]
  end

  def test_manage_members_panel_action
    group = groups(:proposed_group_1)
    assert_nil manage_members_panel_action(group)
    self.expects(:current_user).at_least(0).returns(users(:f_admin_pbe))

    group = groups(:group_pbe)
    content = manage_members_panel_action(group)
    assert_match "Manage Members", content[:label]
    assert_equal ShowQtip(edit_group_path(group, src: "profile")), content[:js]
  end

  def test_add_remove_owners_panel_action
    group = groups(:drafted_group_3)
    self.expects(:current_user).at_least(0).returns(users(:f_admin_pbe))
    stub_current_program group.program

    assert_nil add_remove_owners_panel_action(group)
    group = groups(:group_pbe)
    content = add_remove_owners_panel_action(group)
    assert_match "Add/Remove Owners", content[:label]
    assert_equal ShowQtip(fetch_owners_group_path(group, format: :js)), content[:js]
  end

  def test_allow_stop_user_requests_panel_action
    group = groups(:group_pbe_0)
    assert_nil allow_stop_user_requests_panel_action(group)

    group = groups(:group_pbe)
    content = allow_stop_user_requests_panel_action(group)
    assert_match "Allow/Stop User requesting to join", content[:label]
    assert_equal ShowQtip(edit_join_settings_group_path(group)), content[:js]
  end

  def test_close_group_panel_action
    group = groups(:group_pbe_0)
    assert_nil close_group_panel_action(group)

    group = groups(:group_pbe)
    content = close_group_panel_action(group, source: "profile")
    assert_match "Close Mentoring Connection", content[:label]
    assert_equal ShowQtip(fetch_terminate_group_path(group, src: "profile")), content[:js]
  end

  def test_reactivate_group_panel_action
    group = groups(:group_pbe)
    assert_nil reactivate_group_panel_action(group)

    group.terminate!(users(:f_admin_pbe), "Closure reason", group.get_auto_terminate_reason_id, Group::TerminationMode::INACTIVITY)
    content = reactivate_group_panel_action(group)
    assert_match "Reactivate Mentoring Connection", content[:label]
    assert_equal ShowQtip(fetch_reactivate_group_path(group, src: "profile")), content[:js]
  end

  def test_discard_group_panel_action
    group = groups(:drafted_group_3)
    assert_nil discard_group_panel_action(group, true)

    content = discard_group_panel_action(group, false)
    assert_match "Discard Mentoring Connection", content[:label]
    assert_equal ShowQtip(fetch_discard_group_path(group, src: "profile")), content[:js]
  end

  def test_reject_project_panel_action
    group = groups(:proposed_group_1)
    assert_nil reject_project_panel_action(group, true)

    content = reject_project_panel_action(group, false)
    assert_match "Reject Mentoring Connection", content[:label]
    assert_equal ShowQtip(fetch_bulk_actions_groups_path(src: "profile", bulk_action: { group_ids: [group.id], action_type: Group::BulkAction::REJECT_PROPOSAL})), content[:js]
  end

  def test_withdraw_group_panel_action
    group = groups(:group_pbe)
    assert_nil withdraw_group_panel_action(group)

    group = groups(:group_pbe_0)
    content = withdraw_group_panel_action(group)
    assert_match "Withdraw Mentoring Connection", content[:label]
    assert_equal ShowQtip(fetch_withdraw_group_path(group, src: "profile")), content[:js]
  end

  private

  def _program
    "track"
  end

  def _Program
    "Track"
  end

  def _programs
    "tracks"
  end

  def _Admin
    "Track Admin"
  end

  def _a_Mentor
    "a Trainer"
  end

  def _mentees
    "trainees"
  end

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def admin_panel_action_setup
    admin = users(:f_admin)
    program = admin.program
    @current_organization = program.organization

    stub_current_program(program)
    stub_current_user(admin)
    self.expects(:current_member).at_least(0).returns(admin.member)
    self.expects(:current_user).at_least(0).returns(admin)
    self.expects(:working_on_behalf?).at_least(0).returns(false)
    return [program, admin]
  end

  def member_admin_panel_action_setup
    admin = members(:f_admin)
    @current_organization = admin.organization
    @programs_view_count = @current_organization.programs.size
    self.expects(:wob_member).at_least(0).returns(admin)
    return admin
  end

  def ShowQtip(url)
    %Q[jQueryShowQtip(null, null, "#{url}", {})]
  end
end