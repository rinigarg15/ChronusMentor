require_relative './../../../test_helper.rb'

class ConnectionFilters::CommonInclusionsTest < ActiveSupport::TestCase
  include ConnectionFilters::CommonInclusions
  include Rails.application.routes.url_helpers

  def setup
    super
    setup_params
    @current_program = programs(:albers)
  end

  def test_fetch_group
    self.expects(:load_user_membership_params).once
    fetch_group
    assert_equal groups(:mygroup), @group
  end

  def test_fetch_group_invalid
    setup_params(group_id: groups(:multi_group).id)

    self.expects(:load_user_membership_params).never
    assert_raise "ActiveRecord::RecordNotFound" do
      fetch_group
    end
  end

  def test_load_user_membership_params_mentor
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(@group.mentors.first)
    load_user_membership_params
    assert_equal true, @is_member_view
    assert_equal true, @is_mentor_in_group
  end

  def test_load_user_membership_params_student
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(@group.students.first)
    load_user_membership_params
    assert_equal true, @is_member_view
    assert_false @is_mentor_in_group
  end

  def test_load_user_membership_params_non_group_member
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(users(:f_mentor_student))
    load_user_membership_params
    assert_false @is_member_view
    assert_false @is_mentor_in_group
  end

  def test_fetch_current_connection_membership
    @group = groups(:mygroup)
    mentor_membership = @group.mentor_memberships.first

    self.expects(:current_user).at_least(0).returns(mentor_membership.user)
    fetch_current_connection_membership
    assert_equal mentor_membership, @current_connection_membership
    assert_equal true, @is_member_view
  end

  def test_fetch_current_connection_membership_no_group
    fetch_current_connection_membership
    assert_nil @current_connection_membership
    assert_nil @is_member_view
  end

  def test_fetch_current_connection_membership_non_group_member
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    fetch_current_connection_membership
    assert_nil @current_connection_membership
    assert_false @is_member_view
  end

  def test_check_group_active
    @group = groups(:mygroup)

    assert_equal true, check_group_active
  end

  def test_check_group_open
    @group = groups(:group_pbe_0)
    assert check_group_open

    @group = groups(:proposed_group_1)
    assert_false check_group_open
  end

  def test_check_group_active_inactive_group
    @group = groups(:mygroup)

    @group.expects(:active?).once.returns(false)
    assert_false check_group_active
  end

  def test_check_group_active_no_group
    assert_equal true, check_group_active
  end

  def test_check_group_open
    @group = groups(:mygroup)

    assert_equal true, check_group_open
  end

  def test_check_group_non_open_group
    @group = groups(:mygroup)

    @group.expects(:open?).once.returns(false)
    assert_false check_group_open
  end

  def test_check_group_open_no_group
    assert_equal true, check_group_open
  end

  def test_check_member_or_admin_with_member
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(@group.mentors.first)
    assert_equal true, check_member_or_admin
    assert_false @is_admin_view
  end

  def test_check_member_or_admin_with_admin
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    assert_equal true, check_member_or_admin
    assert_equal true, @is_admin_view
  end

  def test_check_member_or_admin_with_neither_member_nor_admin
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(users(:f_student))
    assert_false check_member_or_admin
    assert_false @is_admin_view
  end

  def test_check_member_or_admin_no_group
    assert_equal true, check_member_or_admin
    assert_nil @is_admin_view
  end

  def test_check_member_or_admin_for_meeting_with_member
    group = groups(:mygroup)
    @meeting = group.meetings.first
    user = group.mentors.first

    self.expects(:wob_member).at_least(0).returns(user.member)
    self.expects(:current_user).at_least(0).returns(user)
    assert_equal true, check_member_or_admin_for_meeting
    assert_false @is_admin_view
  end

  def test_check_member_or_admin_for_meeting_with_admin
    @meeting = groups(:mygroup).meetings.first
    user = users(:f_admin)

    self.expects(:wob_member).at_least(0).returns(user.member)
    self.expects(:current_user).at_least(0).returns(user)
    assert_equal true, check_member_or_admin_for_meeting
    assert_equal true, @is_admin_view
  end

  def test_check_member_or_admin_for_meeting_with_neither_member_nor_admin
    @meeting = groups(:mygroup).meetings.first
    user = users(:f_student)

    self.expects(:wob_member).at_least(0).returns(user.member)
    self.expects(:current_user).at_least(0).returns(user)
    assert_false check_member_or_admin_for_meeting
    assert_false @is_admin_view
  end

  def test_check_action_access
    @is_member_view = true

    Group.any_instance.expects(:has_member?).never
    assert_equal true, check_action_access
  end

  def test_check_action_access_group_member
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(@group.members.first)
    assert_equal true, check_action_access
  end

  def test_check_action_access_non_group_member
    @group = groups(:mygroup)

    self.expects(:current_user).at_least(0).returns(users(:f_admin))
    assert_false check_action_access
  end

  def test_prepare_template_base
    @group = groups(:mygroup)
    user = @group.members.first
    @is_admin_view = false
    @is_member_view = true

    self.expects(:current_user).once.returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:initialize_overdue_engagement_survey).once
    self.expects(:initialize_feedback_survey).once
    self.expects(:working_on_behalf?).returns(false)
    self.expects(:set_circle_start_date_params).once
    @group.expects(:mark_visit).with(user).once
    prepare_template_base
    assert_equal true, @page_controls_allowed
    assert_equal true, @surveys_controls_allowed
    assert_equal true, @past_meeting_controls_allowed
    assert @new_scrap.is_a?(Scrap) && @new_scrap.new_record?
    assert_nil @new_meeting
  end

  def test_prepare_template_base_expects_page_and_meeting_computations
    @group = groups(:mygroup)
    user = @group.members.first

    self.stubs(:current_user).returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:initialize_overdue_engagement_survey).once
    self.expects(:initialize_feedback_survey).once
    self.expects(:compute_page_controls_allowed).once
    self.expects(:compute_past_meeting_controls_allowed).once
    self.expects(:compute_surveys_controls_allowed).once
    self.expects(:working_on_behalf?).returns(false)
    @group.expects(:mark_visit).with(user).once
    prepare_template_base
    assert_false @user_is_member_or_can_join_pending_group
  end

  def test_prepare_template_base_for_pending_group_member_view
    @group = groups(:group_pbe_0)
    user = @group.members.first

    self.stubs(:current_user).returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:working_on_behalf?).returns(false)
    prepare_template_base
    assert @user_is_member_or_can_join_pending_group
  end

  def test_prepare_template_base_for_pending_group_admin_view
    @group = groups(:group_pbe_0)
    user = users(:f_admin_pbe)

    self.stubs(:current_user).returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:working_on_behalf?).returns(false)
    prepare_template_base
    assert_false @user_is_member_or_can_join_pending_group
  end

  def test_prepare_template_base_for_pending_group_outsider_view_eligible_to_join
    @group = groups(:group_pbe_0)
    user = users(:f_admin_pbe)

    @group.expects(:available_roles_for_user_to_join).returns(true)
    self.stubs(:current_user).returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:working_on_behalf?).returns(false)
    prepare_template_base
    assert @user_is_member_or_can_join_pending_group
  end

  def test_prepare_template_skipping_survey_initialization
    @group = groups(:mygroup)
    user = @group.members.first
    @is_admin_view = false
    @is_member_view = true

    self.expects(:current_user).once.returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:initialize_overdue_engagement_survey).never
    self.expects(:initialize_feedback_survey).never
    self.expects(:working_on_behalf?).returns(false)

    prepare_template_base(skip_survey_initialization: true)
    assert_nil @oldest_overdue_survey
    assert_nil @feedback_survey
  end

  def test_prepare_template_base_with_admin
    @group = groups(:mygroup)
    user = users(:f_admin)
    @is_admin_view = true

    self.expects(:current_user).once.returns(user)
    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(false)
    self.expects(:prepare_side_pane).once
    self.expects(:prepare_tabs).once
    self.expects(:fetch_random_tip).once
    self.expects(:initialize_overdue_engagement_survey).once
    self.expects(:initialize_feedback_survey).once
    self.expects(:working_on_behalf?).returns(false)
    @group.expects(:mark_visit).with(user).once
    prepare_template_base
    assert_false @page_controls_allowed
    assert_false @surveys_controls_allowed
    assert_false @past_meeting_controls_allowed
    assert_nil @new_scrap
    assert_nil @new_meeting
  end

  def test_prepare_template_base_confidential_access
    @group = groups(:mygroup)

    self.expects(:prepare_navigation).once
    self.expects(:handle_confidential_access).once.returns(true)
    self.expects(:prepare_side_pane).never
    self.expects(:prepare_tabs).never
    self.expects(:fetch_random_tip).never
    self.expects(:initialize_overdue_engagement_survey).never
    self.expects(:initialize_feedback_survey).never
    self.expects(:working_on_behalf?).never
    @group.expects(:mark_visit).never
    prepare_template_base
    assert_nil @page_controls_allowed
    assert_nil @surveys_controls_allowed
    assert_nil @past_meeting_controls_allowed
    assert_nil @new_scrap
    assert_nil @new_meeting
  end

  def test_prepare_template_base_no_group
    self.expects(:prepare_navigation).never
    self.expects(:handle_confidential_access).never
    self.expects(:prepare_side_pane).never
    self.expects(:prepare_tabs).never
    self.expects(:fetch_random_tip).never
    self.expects(:initialize_overdue_engagement_survey).never
    self.expects(:initialize_feedback_survey).never
    self.expects(:working_on_behalf?).never
    prepare_template_base
    assert_nil @page_controls_allowed
    assert_nil @surveys_controls_allowed
    assert_nil @past_meeting_controls_allowed
    assert_nil @new_scrap
    assert_nil @new_meeting
  end

  def test_prepare_navigation_with_member
    @group = groups(:mygroup)
    tab_info = { "Circles" => { label: "Circles" }, "My Circles" => { label: "My Circles" }, TabConstants::MANAGE => { label: "Manage" } }

    @current_program.stubs(:connection_profiles_enabled?).returns(true)
    self.stubs(:tab_info).returns(tab_info)
    self.expects(:current_user).once.returns(@group.members.first)
    self.expects(:back_mark).with("Circle").once
    self.expects(:deactivate_tabs).once
    self.send(:prepare_navigation)
    assert_not_nil @logo_url
  end

  def test_prepare_navigation_with_non_group_member
    @group = groups(:mygroup)
    tab_info = { "Circles" => { label: "Circles" }, "My Circles" => { label: "My Circles" }, TabConstants::MANAGE => { label: "Manage" } }

    self.stubs(:tab_info).returns(tab_info)
    self.expects(:current_user).once.returns(users(:f_admin))
    self.expects(:back_mark).with("Circle").once
    self.expects(:activate_tab).with(tab_info[TabConstants::MANAGE]).once
    self.send(:prepare_navigation)
    assert_nil @logo_url
  end

  def test_handle_confidential_access
    setup_request
    @group = groups(:mygroup)
    @is_admin_view = true
    # Different admin
    ConfidentialityAuditLog.create!(
      program_id: @group.program_id,
      user_id: users(:ram).id,
      reason: "Weekly Monitoring!",
      group_id: @group.id
    )

    @current_program.stubs(:confidentiality_audit_logs_enabled?).returns(true)
    self.expects(:current_user).once.returns(users(:f_admin))
    self.expects(:redirect_to).with(new_confidentiality_audit_log_path(group_id: @group.id)).once
    self.expects(:render).never
    assert_equal true, self.send(:handle_confidential_access)
    assert_nil @latest_log
  end

  def test_handle_confidential_access_xhr_request
    setup_request(true)
    @group = groups(:mygroup)
    @is_admin_view = true
    admin_user = users(:f_admin)
    audit_log = nil
    time_traveller(125.minutes.ago) do
      audit_log = ConfidentialityAuditLog.create!(
        program_id: @group.program_id,
        user_id: admin_user.id,
        reason: "Weekly Monitoring!",
        group_id: @group.id
      )
    end

    @current_program.stubs(:confidentiality_audit_logs_enabled?).returns(true)
    self.expects(:current_user).once.returns(admin_user)
    self.expects(:redirect_to).never
    self.expects(:render).with(:update).once.returns(true)
    assert_equal true, self.send(:handle_confidential_access)
    assert_equal audit_log, @latest_log
  end

  def test_handle_confidential_access_log_exists
    setup_request
    @group = groups(:mygroup)
    admin_user = users(:f_admin)
    @is_admin_view = true
    audit_log = ConfidentialityAuditLog.create!(
      program_id: @group.program_id,
      user_id: admin_user.id,
      reason: "Weekly Monitoring!",
      group_id: @group.id
    )

    @current_program.stubs(:confidentiality_audit_logs_enabled?).returns(true)
    self.expects(:current_user).once.returns(admin_user)
    self.expects(:redirect_to).never
    self.expects(:render).never
    assert_nil self.send(:handle_confidential_access)
    assert_equal audit_log, @latest_log
  end

  def test_handle_confidential_access_non_admin_view
    @is_admin_view = false

    @current_program.stubs(:confidentiality_audit_logs_enabled?).returns(true)
    self.expects(:redirect_to).never
    self.expects(:render).never
    assert_nil self.send(:handle_confidential_access)
    assert_nil @latest_log
  end

  def test_handle_confidential_access_feature_disabled
    @is_admin_view = true
    assert_false @current_program.confidentiality_audit_logs_enabled?

    self.expects(:redirect_to).never
    self.expects(:render).never
    assert_nil self.send(:handle_confidential_access)
    assert_nil @latest_log
  end

  def test_prepare_tabs_for_published_group
    @group = groups(:mygroup)
    @is_member_view = false
    @is_admin_view = true
    Connection::Question.expects(:get_viewable_or_updatable_questions).returns("Connection Questions")
    self.stubs(:current_user).returns(users(:f_admin_pbe))
    self.expects(:show_messages).once.returns("Show Messages")
    self.expects(:show_forum).once.returns("Show Forum")
    self.expects(:show_meetings).once.returns("Show Meetings")
    self.expects(:show_mentoring_model_goals).once.returns("Show Goals")
    self.expects(:show_private_journals).once.returns("Show Journals")
    self.send(:prepare_tabs)

    assert @can_access_tabs
    assert @show_plan_tab
    assert @can_show_tabs
    assert @is_tab_or_connection_questions_present_in_page
    assert_equal "Connection Questions", @connection_questions
    assert_equal "Show Messages", @show_messages_tab
    assert_equal "Show Forum", @show_forum_tab
    assert_equal "Show Meetings", @show_meetings_tab
    assert_equal "Show Goals", @show_mentoring_model_goals_tab
    assert_equal "Show Journals", @show_private_journals_tab
  end

  def test_prepare_tabs_for_pending_group
    @group = groups(:group_pbe_0)
    @is_member_view = false
    @is_admin_view = true
    Connection::Question.expects(:get_viewable_or_updatable_questions).returns("Connection Questions")
    self.stubs(:current_user).returns(users(:f_admin_pbe))
    self.expects(:show_messages).once.returns("Show Messages")
    self.expects(:show_forum).once.returns("Show Forum")
    self.expects(:mentoring_model_template_objects_present?).once.returns(true)
    self.expects(:show_meetings).never
    self.expects(:show_mentoring_model_goals).never
    self.expects(:show_private_journals).never
    self.send(:prepare_tabs)

    assert_equal true, @can_access_tabs
    assert_equal "Connection Questions", @connection_questions
    assert_equal "Show Messages", @show_messages_tab
    assert_equal "Show Forum", @show_forum_tab
    assert_equal true, @show_profile_tab
    assert_equal true, @show_plan_tab
    assert_equal true, @can_show_tabs
    assert @is_tab_or_connection_questions_present_in_page
  end

  def test_prepare_tabs_for_pending_group_can_show_tabs
    @group = groups(:group_pbe_0)
    @is_member_view = false
    @is_admin_view = false
    Connection::Question.expects(:get_viewable_or_updatable_questions).returns(nil)
    @group.expects(:global?).once.returns(true)
    self.stubs(:current_user).returns(users(:f_admin_pbe))
    self.expects(:show_messages).once.returns(false)
    self.expects(:show_forum).once.returns(true)
    self.expects(:mentoring_model_template_objects_present?).once.returns(true)
    self.send(:prepare_tabs)

    assert_false @can_access_tabs
    assert_nil @connection_questions
    assert_false @show_messages_tab
    assert @show_forum_tab
    assert_false @show_profile_tab
    assert @show_plan_tab
    assert @can_show_tabs
    assert @is_tab_or_connection_questions_present_in_page
  end

  def test_prepare_tabs_for_pending_group_cannot_show_tabs
    @group = groups(:group_pbe_0)
    @is_member_view = false
    @is_admin_view = true
    Connection::Question.expects(:get_viewable_or_updatable_questions).returns(nil)
    self.stubs(:current_user).returns(users(:f_admin_pbe))
    self.expects(:show_messages).once.returns(false)
    self.expects(:show_forum).once.returns(true)
    self.expects(:mentoring_model_template_objects_present?).once.returns(false)
    self.send(:prepare_tabs)

    assert @can_access_tabs
    assert_nil @connection_questions
    assert_false @show_messages_tab
    assert @show_forum_tab
    assert_false @show_profile_tab
    assert_false @show_plan_tab
    assert_false @can_show_tabs
    assert @is_tab_or_connection_questions_present_in_page
  end

  def test_prepare_tabs_for_pending_group_is_tab_or_connection_questions_present_in_page
    @group = groups(:group_pbe_0)
    @is_member_view = false
    @is_admin_view = true
    Connection::Question.expects(:get_viewable_or_updatable_questions).returns(nil)
    self.stubs(:current_user).returns(users(:f_admin_pbe))
    self.expects(:show_messages).once.returns(false)
    self.expects(:show_forum).once.returns(false)
    self.expects(:mentoring_model_template_objects_present?).once.returns(false)
    self.send(:prepare_tabs)

    assert @can_access_tabs
    assert_nil @connection_questions
    assert_false @show_messages_tab
    assert_false @show_forum_tab
    assert_false @show_profile_tab
    assert_false @show_plan_tab
    assert_false @can_show_tabs
    assert_false @is_tab_or_connection_questions_present_in_page
  end


  def test_mentoring_model_template_objects_present
    @group = groups(:group_pbe_0)

    @group.stubs(:mentoring_model).returns(nil)
    assert_false mentoring_model_template_objects_present?
    @group.unstub(:mentoring_model)

    MentoringModel.any_instance.stubs(:mentoring_model_task_templates).returns("Task Template objects")
    MentoringModel.any_instance.stubs(:mentoring_model_milestone_templates).returns(nil)
    assert mentoring_model_template_objects_present?
    assert_equal "Task Template objects", @mentoring_model_tasks
    assert_nil @mentoring_model_milestones

    MentoringModel.any_instance.stubs(:mentoring_model_milestone_templates).returns("Milestone Template objects")
    MentoringModel.any_instance.stubs(:mentoring_model_task_templates).returns(nil)
    assert mentoring_model_template_objects_present?
    assert_equal "Milestone Template objects", @mentoring_model_milestones
    assert_nil @mentoring_model_tasks

    MentoringModel.any_instance.stubs(:mentoring_model_milestone_templates).returns(nil)
    MentoringModel.any_instance.stubs(:mentoring_model_task_templates).returns(nil)
    assert_false mentoring_model_template_objects_present?
    assert_nil @mentoring_model_milestones
    assert_nil @mentoring_model_tasks
  end

  def test_set_group_profile_view
    assert_nil set_group_profile_view

    @group = groups(:group_pbe_0)
    assert @group.pending?
    assert set_group_profile_view

    @group.stubs(:pending?).returns(false)
    assert_false set_group_profile_view

    group_params[:action] = "profile"
    assert set_group_profile_view
  end

  def test_set_src
    set_src
    assert_nil @src

    setup_params(src: "source")
    set_src
    assert_equal "source", @src_path
  end

  def test_set_circle_start_date_params
    set_circle_start_date_params
    assert_false @manage_circle_members
    assert_false @show_set_start_date_popup

    setup_params(manage_circle_members: "true", show_set_start_date_popup: "true")
    set_circle_start_date_params
    assert @manage_circle_members
    assert @show_set_start_date_popup
  end

  def test_set_from_find_new
    set_from_find_new
    assert_nil @from_find_new

    setup_params(from_find_new: "true")
    set_from_find_new
    assert_equal "true", @from_find_new
  end

  def test_show_messages
    @group = groups(:mygroup)
    assert @group.scraps_enabled?
    @can_access_tabs = false
    assert_false self.send(:show_messages)

    @can_access_tabs = true
    assert_equal true, self.send(:show_messages)

    @group.stubs(:scraps_enabled?).returns(false)
    assert_false self.send(:show_messages)
  end

  def test_show_forum
    @group = groups(:mygroup)
    assert_false @group.forum_enabled?
    @can_access_tabs = true
    assert_false self.send(:show_forum)

    @can_access_tabs = true
    assert_false self.send(:show_forum)

    @group.stubs(:forum_enabled?).returns(true)
    assert_equal true, self.send(:show_forum)
  end

  def test_show_meetings
    @group = groups(:mygroup)

    self.expects(:manage_mm_meetings_at_end_user_level?).never
    @current_program.expects(:mentoring_connection_meeting_enabled?).never
    @current_program.expects(:mentoring_connections_v2_enabled?).never
    @can_access_tabs = false
    assert_false self.send(:show_meetings)

    @can_access_tabs = true
    @current_program.expects(:mentoring_connection_meeting_enabled?).once.returns(false)
    assert_false self.send(:show_meetings)

    @current_program.expects(:mentoring_connection_meeting_enabled?).times(3).returns(true)
    @current_program.expects(:mentoring_connections_v2_enabled?).once.returns(false)
    assert_equal true, self.send(:show_meetings)

    @current_program.expects(:mentoring_connections_v2_enabled?).twice.returns(true)
    self.expects(:manage_mm_meetings_at_end_user_level?).with(@group).once.returns(false)
    assert_false self.send(:show_meetings)

    self.expects(:manage_mm_meetings_at_end_user_level?).with(@group).once.returns(true)
    assert_equal true, self.send(:show_meetings)
  end

  def test_show_mentoring_model_goals
    @group = groups(:mygroup)

    self.expects(:manage_mm_goals_at_admin_level?).never
    self.expects(:manage_mm_goals_at_end_user_level?).never
    @current_program.expects(:mentoring_connections_v2_enabled?).never
    @can_access_tabs = false
    assert_false self.send(:show_mentoring_model_goals)

    @can_access_tabs = true
    @current_program.expects(:mentoring_connections_v2_enabled?).once.returns(false)
    assert_false self.send(:show_mentoring_model_goals)

    @current_program.expects(:mentoring_connections_v2_enabled?).times(3).returns(true)
    self.expects(:manage_mm_goals_at_admin_level?).with(@group).once.returns(true)
    assert_equal true, self.send(:show_mentoring_model_goals)

    self.expects(:manage_mm_goals_at_admin_level?).with(@group).twice.returns(false)
    self.expects(:manage_mm_goals_at_end_user_level?).once.returns(true)
    assert_equal true, self.send(:show_mentoring_model_goals)

    self.expects(:manage_mm_goals_at_end_user_level?).once.returns(false)
    assert_false self.send(:show_mentoring_model_goals)
  end

  def test_show_private_journals
    @can_access_tabs = false
    @current_program.expects(:allow_private_journals).never
    self.expects(:working_on_behalf?).never
    assert_false self.send(:show_private_journals)

    @can_access_tabs = true
    @is_admin_view = true
    assert_false self.send(:show_private_journals)

    @is_admin_view = false
    @current_program.expects(:allow_private_journals?).once.returns(false)
    assert_false self.send(:show_private_journals)

    @current_program.expects(:allow_private_journals?).times(2).returns(true)
    self.expects(:working_on_behalf?).once.returns(true)
    assert_false self.send(:show_private_journals)

    self.expects(:working_on_behalf?).once.returns(false)
    assert_equal true, self.send(:show_private_journals)
  end

  def test_fetch_random_tip
    @current_program.mentoring_tips.update_all(enabled: true)

    @is_member_view = false
    @current_program.expects(:mentoring_insights_enabled?).never
    self.send(:fetch_random_tip)
    assert_nil @random_tip

    @is_member_view = true
    @current_program.expects(:mentoring_insights_enabled?).once.returns(false)
    self.send(:fetch_random_tip)
    assert_nil @random_tip

    @current_program.expects(:mentoring_insights_enabled?).once.returns(true)
    @current_connection_membership = Connection::MentorMembership.first
    self.send(:fetch_random_tip)
    assert @random_tip.is_a?(MentoringTip)
    assert @random_tip.role_names.include?(RoleConstants::MENTOR_NAME)
  end

  def test_initialize_feedback_survey
    feedback_survey = @current_program.feedback_survey
    @group = groups(:mygroup)
    user = @group.members.first
    @is_member_view = true

    self.expects(:session).once.returns({})
    self.expects(:working_on_behalf?).once.returns(false)
    self.expects(:current_user).at_least(0).returns(user)
    @group.expects(:time_for_feedback_from?).with(user).once.returns(true)
    @group.expects(:can_be_activated?).never
    @current_program.expects(:allow_connection_feedback?).once.returns(false)
    @current_program.expects(:connection_feedback_enabled?).once.returns(true)
    @current_program.expects(:feedback_survey).at_least(0).returns(feedback_survey)
    self.send(:initialize_feedback_survey)

    assert_equal feedback_survey, @feedback_survey
    assert_equal feedback_survey.survey_questions, @feedback_questions
    assert @feedback_response.is_a?(Survey::SurveyResponse)
    assert_equal true, @show_feedback_form
  end

  def test_initialize_feedback_survey_wob
    feedback_survey = @current_program.feedback_survey
    @group = groups(:mygroup)
    user = @group.members.first
    @is_member_view = true

    self.expects(:session).never
    self.expects(:working_on_behalf?).once.returns(true)
    self.expects(:current_user).at_least(0).returns(user)
    @group.expects(:time_for_feedback_from?).never
    @group.expects(:can_be_activated?).never
    @current_program.expects(:allow_connection_feedback?).once.returns(false)
    @current_program.expects(:connection_feedback_enabled?).once.returns(true)
    @current_program.expects(:feedback_survey).at_least(0).returns(feedback_survey)
    self.send(:initialize_feedback_survey)

    assert_equal feedback_survey, @feedback_survey
    assert_equal feedback_survey.survey_questions, @feedback_questions
    assert @feedback_response.is_a?(Survey::SurveyResponse)
    assert_false @show_feedback_form
  end

  def test_initialize_feedback_survey_non_member
    @group = groups(:mygroup)
    @is_member_view = false

    @current_program.expects(:allow_connection_feedback?).never
    @current_program.expects(:connection_feedback_enabled?).never
    @current_program.expects(:feedback_survey).never
    self.send(:initialize_feedback_survey)
    assert_nil (@feedback_survey || @feedback_questions || @feedback_response || @show_feedback_form)
  end

  def test_initialize_feedback_survey_member_feedback_disabled
    feedback_survey = @current_program.feedback_survey
    @group = groups(:mygroup)
    @is_member_view = true

    @current_program.expects(:allow_connection_feedback?).once.returns(false)
    @current_program.expects(:connection_feedback_enabled?).once.returns(false)
    @current_program.expects(:feedback_survey).once.returns(feedback_survey)
    self.send(:initialize_feedback_survey)
    assert_nil (@feedback_survey || @feedback_questions || @feedback_response || @show_feedback_form)
  end

  def test_initialize_overdue_engagement_survey
    cookies = setup_cookie
    @group = groups(:mygroup)
    @current_connection_membership = @group.mentor_memberships.first
    user = @current_connection_membership.user
    engagement_survey = surveys(:two)
    task = create_mentoring_model_task(
      action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,
      action_item_id: engagement_survey.id,
      user: user
    )

    self.expects(:cookies).at_least(0).returns(cookies)
    self.expects(:working_on_behalf?).once.returns(false)
    self.expects(:current_user).once.returns(user)
    @current_connection_membership.expects(:get_last_outstanding_survey_task).once.returns(task)
    self.send(:initialize_overdue_engagement_survey)
    assert_equal engagement_survey, @oldest_overdue_survey
    assert_equal edit_answers_survey_path(engagement_survey, task_id: task.id, format: :js, src: Survey::SurveySource::POPUP), @survey_answer_url
    assert_equal true, cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{@current_connection_membership.id}"]
  end

  def test_initialize_overdue_engagement_survey_cookie_exists
    cookies = setup_cookie
    @group = groups(:mygroup)
    @current_connection_membership = @group.mentor_memberships.first
    user = @current_connection_membership.user
    engagement_survey = surveys(:two)
    task = create_mentoring_model_task(
      action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,
      action_item_id: engagement_survey.id,
      user: user
    )

    cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{@current_connection_membership.id}"] = true
    self.expects(:cookies).at_least(0).returns(cookies)
    self.expects(:working_on_behalf?).once.returns(false)
    self.expects(:current_user).never
    @current_connection_membership.expects(:get_last_outstanding_survey_task).once.returns(task)
    self.send(:initialize_overdue_engagement_survey)
    assert_nil @oldest_overdue_survey
    assert_nil @survey_answer_url
    assert_equal true, cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{@current_connection_membership.id}"]
  end

  def test_initialize_overdue_engagement_survey_wob
    @group = groups(:mygroup)
    @current_connection_membership = @group.mentor_memberships.first
    user = @current_connection_membership.user
    engagement_survey = surveys(:two)
    task = create_mentoring_model_task(
      action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,
      action_item_id: engagement_survey.id,
      user: user
    )

    self.expects(:cookies).never
    self.expects(:working_on_behalf?).once.returns(true)
    self.expects(:current_user).never
    @current_connection_membership.expects(:get_last_outstanding_survey_task).once.returns(task)
    self.send(:initialize_overdue_engagement_survey)
    assert_nil @oldest_overdue_survey
    assert_nil @survey_answer_url
  end

  def test_initialize_overdue_engagement_survey_no_membership
    Connection::Membership.any_instance.expects(:get_last_outstanding_survey_task).never
    self.send(:initialize_overdue_engagement_survey)
    assert_nil @oldest_overdue_survey
    assert_nil @survey_answer_url
  end

  def test_initialize_overdue_engagement_survey_closed_group
    cookies = setup_cookie
    @group = groups(:mygroup)
    @current_connection_membership = @group.mentor_memberships.first
    user = @current_connection_membership.user
    engagement_survey = surveys(:two)
    task = create_mentoring_model_task(
      action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,
      action_item_id: engagement_survey.id,
      user: user
    )
    @group.update_attributes(status: Group::Status::CLOSED)

    self.expects(:cookies).at_least(0).returns(cookies)
    self.expects(:working_on_behalf?).once.returns(false)
    self.expects(:current_user).once.returns(user)
    @current_connection_membership.expects(:get_last_outstanding_survey_task).once.returns(task)
    self.send(:initialize_overdue_engagement_survey)
    assert_equal engagement_survey, @oldest_overdue_survey
    assert_equal edit_answers_survey_path(engagement_survey, task_id: task.id, format: :js, src: Survey::SurveySource::POPUP), @survey_answer_url
    assert_equal true, cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{@current_connection_membership.id}"]
  end

  def test_initialize_overdue_engagement_survey_non_published_group
    @group = groups(:mygroup)
    @current_connection_membership = @group.memberships.first

    @current_connection_membership.expects(:get_last_outstanding_survey_task).never
    @group.expects(:published?).once.returns(false)
    self.send(:initialize_overdue_engagement_survey)
    assert_nil @oldest_overdue_survey
    assert_nil @survey_answer_url
  end

  def test_initialize_overdue_engagement_survey_no_outstanding_task
    @group = groups(:mygroup)
    @current_connection_membership = @group.memberships.first

    @current_connection_membership.expects(:get_last_outstanding_survey_task).once.returns(nil)
    self.send(:initialize_overdue_engagement_survey)
    assert_nil @oldest_overdue_survey
    assert_nil @survey_answer_url
  end

  def test_prepare_template
    setup_request
    self.expects(:prepare_template_base).once
    prepare_template
  end

  def test_prepare_template_ajax_request
    setup_request(true)
    self.expects(:prepare_template_base).never
    prepare_template
  end

  def test_prepare_template_for_ajax
    self.expects(:prepare_template_base).once
    prepare_template_for_ajax
  end

  def test_compute_page_controls_allowed
    @group = groups(:group_pbe_0)
    @is_admin_view = false
    @is_member_view = true
    assert_instance_variables(page_controls_allowed: true) do
      compute_page_controls_allowed
    end

    @is_admin_view = true
    assert_instance_variables(page_controls_allowed: false) do
      compute_page_controls_allowed
    end

    @is_admin_view = false
    @is_member_view = false
    assert_instance_variables(page_controls_allowed: false) do
      compute_page_controls_allowed
    end

    @is_member_view = true
    @group.stubs(:pending?).returns(false)
    @group.stubs(:active?).returns(false)
    assert_instance_variables(page_controls_allowed: false) do
      compute_page_controls_allowed
    end

    @group.stubs(:pending?).returns(false)
    @group.stubs(:active?).returns(true)
    @group.stubs(:expired?).returns(true)
    assert_instance_variables(page_controls_allowed: false) do
      compute_page_controls_allowed
    end

    @group.stubs(:expired?).returns(false)
    assert_instance_variables(page_controls_allowed: true) do
      compute_page_controls_allowed
    end
  end

  def test_compute_past_meeting_controls_allowed
    @group = groups(:mygroup)
    @is_admin_view = false
    @is_member_view = true
    assert_instance_variables(past_meeting_controls_allowed: true) do
      compute_past_meeting_controls_allowed
    end

    @is_admin_view = true
    assert_instance_variables(past_meeting_controls_allowed: false) do
      compute_past_meeting_controls_allowed
    end

    @is_admin_view = false
    @is_member_view = false
    assert_instance_variables(past_meeting_controls_allowed: false) do
      compute_past_meeting_controls_allowed
    end

    @is_member_view = true
    @group.stubs(:active?).returns(false)
    assert_instance_variables(past_meeting_controls_allowed: false) do
      compute_past_meeting_controls_allowed
    end

    @group.stubs(:expired?).returns(true)
    assert_instance_variables(past_meeting_controls_allowed: true) do
      compute_past_meeting_controls_allowed
    end

    @group.stubs(:expired?).returns(false)
    assert_instance_variables(past_meeting_controls_allowed: false) do
      compute_past_meeting_controls_allowed
    end
  end

  def test_compute_surveys_controls_allowed
    @group = groups(:mygroup)
    @is_admin_view = false
    @is_member_view = true
    assert_instance_variables(surveys_controls_allowed: true) do
      compute_surveys_controls_allowed
    end

    @is_admin_view = true
    assert_instance_variables(surveys_controls_allowed: false) do
      compute_surveys_controls_allowed
    end

    @is_admin_view = false
    @is_member_view = false
    assert_instance_variables(surveys_controls_allowed: false) do
      compute_surveys_controls_allowed
    end

    @is_member_view = true
    @group.stubs(:published?).returns(false)
    assert_instance_variables(surveys_controls_allowed: false) do
      compute_surveys_controls_allowed
    end
  end

  def test_compute_coaching_goals_side_pane
    @group = groups(:mygroup)
    assert_instance_variables(side_pane_coaching_goals: []) do
      compute_coaching_goals_side_pane
    end

    completed_coaching_goal = create_coaching_goal(progress_value: CoachingGoalActivity::END_PROGRESS_VALUE)
    create_coaching_goal_activity(completed_coaching_goal, progress_value: CoachingGoalActivity::END_PROGRESS_VALUE, initiator: @group.mentors.first)
    overdue_coaching_goal = create_coaching_goal(due_date: 2.days.ago.to_date)
    in_progress_coaching_goal = create_coaching_goal
    @group.reload
    assert_instance_variables(side_pane_coaching_goals: [overdue_coaching_goal, in_progress_coaching_goal, completed_coaching_goal]) do
      compute_coaching_goals_side_pane
    end
  end

  def test_compute_mentoring_model_goals_side_pane
    @group = groups(:mygroup)
    assert_instance_variables(mentoring_model_goals: [], required_tasks: []) do
      compute_mentoring_model_goals_side_pane
    end

    milestone = create_mentoring_model_milestone
    goal = create_mentoring_model_goal
    create_mentoring_model_task(milestone_id: milestone.id, required: true)
    create_mentoring_model_task(milestone_id: milestone.id, goal_id: goal.id)
    task_1 = create_mentoring_model_task(milestone_id: milestone.id, goal_id: goal.id, required: true)
    create_mentoring_model_task(goal_id: goal.id)
    task_2 = create_mentoring_model_task(goal_id: goal.id, required: true)
    create_mentoring_model_task(required: true)
    assert_instance_variables( { mentoring_model_goals: [goal], required_tasks: [task_1, task_2] }, :assert_equal_unordered) do
      compute_mentoring_model_goals_side_pane
    end
  end

  def test_can_access_mentoring_area
    @group = groups(:mygroup)
    user = users(:f_student)

    self.expects(:current_user).once.returns(user)
    self.expects(:super_console?).once.returns("Super Console")
    @group.expects(:admin_enter_mentoring_connection?).with(user, "Super Console").returns(true)
    assert_equal true, can_access_mentoring_area?
  end

  def test_can_access_mentoring_area_no_group
    assert_equal true, can_access_mentoring_area?
  end

  def test_update_login_count
    @current_connection_membership = Connection::Membership.first
    @group = @current_connection_membership.group
    assert_equal 0, @current_connection_membership.login_count
    cookies = setup_cookie

    self.expects(:cookies).at_least(0).returns(cookies)
    self.expects(:working_on_behalf?).returns(true)
    update_login_count
    assert_equal 0, @current_connection_membership.login_count
    self.expects(:working_on_behalf?).returns(false)
    update_login_count
    assert_equal 1, @current_connection_membership.login_count
    assert_equal "#{@group.id}", cookies[CookiesConstants::MENTORING_AREA_VISITED]
  end

  def test_update_login_count_cookie_present
    @current_connection_membership = Connection::Membership.first
    @group = @current_connection_membership.group
    assert_equal 0, @current_connection_membership.login_count
    cookies = setup_cookie
    cookies[CookiesConstants::MENTORING_AREA_VISITED] = "#{@group.id}"

    self.expects(:cookies).at_least(0).returns(cookies)
    self.expects(:working_on_behalf?).returns(false)
    update_login_count
    assert_equal 0, @current_connection_membership.login_count
    assert_equal "#{@group.id}", cookies[CookiesConstants::MENTORING_AREA_VISITED]
  end

  def test_update_login_count_no_membership
    cookies = setup_cookie

    self.expects(:cookies).at_least(0).returns(cookies)
    self.expects(:working_on_behalf?).returns(false)
    update_login_count
    assert_nil cookies[CookiesConstants::MENTORING_AREA_VISITED]
  end

  def test_update_last_visited_tab
    setup_params(controller: ScrapsController.controller_path)
    @current_connection_membership = Connection::Membership.first
    assert_nil @current_connection_membership.last_visited_tab

    update_last_visited_tab
    assert_equal ScrapsController.controller_path, @current_connection_membership.last_visited_tab
  end

  def test_upate_last_visited_tab_no_membership
    assert_nothing_raised do
      update_last_visited_tab
    end
  end

  def test_handle_connection_tab
    @group = groups(:mygroup)
    self.expects(:current_user).at_least(0).returns(@group.mentors.first)
    @badge_counts = {unread_message_count: 2, unread_posts_count: 3, tasks_count: 3}
    handle_connection_tab
    assert_equal Group::Tabs::MESSSAGES, @tab_to_open
    @tab_to_open = nil
    @badge_counts = {unread_message_count: 0, unread_posts_count: 3, tasks_count: 3}
    handle_connection_tab
    assert_equal Group::Tabs::FORUMS, @tab_to_open
    @tab_to_open = nil
    @badge_counts = {unread_message_count: 0, unread_posts_count: 0, tasks_count: 3}
    handle_connection_tab
    assert_equal Group::Tabs::TASKS, @tab_to_open
    @group.stubs(:scraps_enabled?).returns(false)
    @group.stubs(:forum_enabled?).returns(true)
    @tab_to_open = nil
    @badge_counts = {unread_message_count: 0, unread_posts_count: 0, tasks_count: 0}
    @group.create_group_forum
    create_topic(forum: @group.forum, user: @group.mentors.first)
    handle_connection_tab
    assert_equal Group::Tabs::FORUMS, @tab_to_open
  end

  def test_get_side_pane_meetings
    group = groups(:mygroup)
    mentor = Member.find_by(id: group.mentors.first.id)
    student = Member.find_by(id: group.students.first.id)
    program = programs(:albers)
    is_admin_view = false
    arbit_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    self.stubs(:wob_member).returns(mentor)

    #Initial check for newly created meetings
    update_recurring_meeting_start_end_date(arbit_meeting, (Time.now + 1.day), (Time.now + 1.day + 1.hour), {duration: 1.hour})
    upcoming_meetings, upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(group, is_admin_view)
    initial_count = upcoming_meetings.length
    initial_count_next_seven_days = upcoming_meetings_in_next_seven_days.length
    assert check_only_upcoming_and_attending_meeting(upcoming_meetings, mentor, group.id)
    assert check_meeting_matches(upcoming_meetings, arbit_meeting, arbit_meeting.occurrences.first)

    #Rejected meetings should not come in the result
    #Check for empty cases for both the vars
    mentor.mark_attending!(arbit_meeting, attending: MemberMeeting::ATTENDING::NO)
    upcoming_meetings, upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(group, is_admin_view)
    assert_equal initial_count-1, upcoming_meetings.length
    assert_equal initial_count_next_seven_days-1, upcoming_meetings_in_next_seven_days.length
    assert check_only_upcoming_and_attending_meeting(upcoming_meetings, mentor, group.id)
    assert_false check_meeting_matches(upcoming_meetings, arbit_meeting, arbit_meeting.occurrences.first)

    mentor.mark_attending!(arbit_meeting, attending: MemberMeeting::ATTENDING::YES)
    student.mark_attending!(arbit_meeting, attending: MemberMeeting::ATTENDING::NO)
    upcoming_meetings, upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(group, is_admin_view)
    assert_equal initial_count, upcoming_meetings.length
    assert_equal initial_count_next_seven_days, upcoming_meetings_in_next_seven_days.length
    assert check_only_upcoming_and_attending_meeting(upcoming_meetings, mentor, group.id)
    assert check_meeting_matches(upcoming_meetings, arbit_meeting, arbit_meeting.occurrences.first)

    #Checking the admin case when mentor is not attending
    mentor.mark_attending!(arbit_meeting, attending: MemberMeeting::ATTENDING::NO)
    student.mark_attending!(arbit_meeting, attending: MemberMeeting::ATTENDING::YES)
    is_admin_view = true
    upcoming_meetings, upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(group, is_admin_view)
    assert_equal initial_count, upcoming_meetings.length
    assert_equal initial_count_next_seven_days, upcoming_meetings_in_next_seven_days.length
    assert check_meeting_matches(upcoming_meetings, arbit_meeting, arbit_meeting.occurrences.first)

    #Only next 7 days meetings should come in next seven days
    mentor.mark_attending!(arbit_meeting, attending: MemberMeeting::ATTENDING::YES)
    is_admin_view = false
    update_recurring_meeting_start_end_date(arbit_meeting, (Time.now + 8.days), (Time.now + 8.days + 1.hour), {duration: 1.hour})
    upcoming_meetings, upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(group, is_admin_view)
    assert_equal initial_count, upcoming_meetings.length
    assert_equal initial_count_next_seven_days-1, upcoming_meetings_in_next_seven_days.length
    assert_false check_meeting_matches(upcoming_meetings_in_next_seven_days, arbit_meeting, arbit_meeting.occurrences.first)

    #Checking the limit
    #Past meetings should not come and more than 2 upcoming meetings should not come
    update_recurring_meeting_start_end_date(arbit_meeting, (Time.now - 2.days), (Time.now + 8.days + 1.hour), {duration: 1.hour})
    upcoming_meetings, upcoming_meetings_in_next_seven_days = get_meetings_for_sidepanes(group, is_admin_view)
    assert_equal OrganizationsController::MY_MEETINGS_COUNT-1, upcoming_meetings.length
    meetings_to_be_present = Meeting.upcoming_recurrent_meetings(group.meetings)
    assert check_meeting_matches(upcoming_meetings, meetings_to_be_present[0][:meeting], meetings_to_be_present[0][:current_occurrence_time])
    assert check_meeting_matches(upcoming_meetings, meetings_to_be_present[1][:meeting], meetings_to_be_present[1][:current_occurrence_time])
  end

  private

  #This method checks if a meeting with single occurrence should be present or not based on the value of present.
  def check_meeting_matches(upcoming_meetings, meeting, occurrence)
    is_present = false
    if(!upcoming_meetings.nil?)
      upcoming_meetings.each do |upcoming_meeting|
        if (upcoming_meeting[:meeting] == meeting && upcoming_meeting[:current_occurrence_time] == occurrence)
          is_present = true and break
        end
      end
    end
    is_present
  end

  def check_only_upcoming_and_attending_meeting(upcoming_meetings, member, group_id)
    upcoming_meetings.each do |upcoming_meeting|
      if((!member.is_attending?(upcoming_meeting[:meeting],upcoming_meeting[:current_occurrence_time]) || (upcoming_meeting[:current_occurrence_time] < Time.now)) || (upcoming_meeting[:meeting][:group_id] != group_id))
        return false
      end
    end
  end

  def setup_params(params_hash = {})
    params_hash = { group_id: groups(:mygroup).id }.merge(params_hash)

    self.stubs(:params).returns(params_hash)
    self.stubs(:group_params).returns(params_hash)
  end

  def setup_request(ajax = false)
    request = ActionController::TestRequest.create(self.class)
    request.stubs(:xhr?).returns(ajax)
    self.stubs(:request).returns(request)
  end

  def _Mentoring_Connection
    "Circle"
  end

  def _Mentoring_Connections
    "Circles"
  end
end