require_relative "./../../test_helper.rb"

class GroupsController::GroupShowRedirectionsTest < ActionController::TestCase
  tests GroupsController

  def setup
    super
    @group = groups(:mygroup)
    @program = @group.program
    @mentor_membership = @group.mentor_memberships.first
    @student_membership = @group.student_memberships.first
  end

  def test_show_redirect_to_scraps_listing
    current_user_is @group.members.first
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_redirected_to group_scraps_path(@group)
  end

  def test_show_dont_redirect_to_scraps_listing
    @mentor_membership.update_attribute(:last_visited_tab, ScrapsController.controller_path)
    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id, show_plan: "true"}
    assert_response :success
  end

  def test_show_handle_last_visited_tab_non_group_member
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @group.memberships.update_all(last_visited_tab: Connection::PrivateNotesController.controller_path)

    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { id: @group.id}
    assert_false assigns(:show_private_journals_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_show_plan_param
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, Connection::PrivateNotesController.controller_path)

    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id, show_plan: "true"}
    assert assigns(:show_private_journals_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_notif_settings_param
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, Connection::PrivateNotesController.controller_path)

    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id, notif_settings: "true"}
    assert assigns(:show_private_journals_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_coach_rating_param
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, Connection::PrivateNotesController.controller_path)

    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id, coach_rating: "true"}
    assert assigns(:show_private_journals_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_notes_disabled
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, Connection::PrivateNotesController.controller_path)
    @program.update_attribute(:allow_private_journals, false)

    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_false assigns(:show_private_journals_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_notes
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, Connection::PrivateNotesController.controller_path)

    @controller.expects(:prepare_template).never
    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert assigns(:show_private_journals_tab)
    assert_redirected_to group_connection_private_notes_path(@group)
  end

  def test_show_handle_last_visited_tab_with_forum
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_forum_setup
    @mentor_membership.update_attribute(:last_visited_tab, TopicsController.controller_path)

    @controller.expects(:prepare_template).never
    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert assigns(:show_forum_tab)
    assert_redirected_to forum_path(@forum)
  end

  def test_show_handle_last_visited_tab_with_forum_disabled
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, ForumsController.controller_path)

    @controller.expects(:prepare_template).once
    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_false assigns(:show_forum_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_scraps
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @student_membership.update_attribute(:last_visited_tab, ScrapsController.controller_path)

    @controller.expects(:prepare_template).never
    current_user_is @student_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert assigns(:show_messages_tab)
    assert_redirected_to group_scraps_path(@group)
  end

  def test_show_handle_last_visited_tab_with_scraps_disabled
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @student_membership.update_attribute(:last_visited_tab, ScrapsController.controller_path)
    Group.any_instance.stubs(:scraps_enabled?).returns(false)

    @controller.expects(:prepare_template).once
    current_user_is @student_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_false assigns(:show_messages_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_goals
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    create_object_role_permission("manage_mm_goals", role: "users", object: @group)
    @mentor_membership.update_attribute(:last_visited_tab, MentoringModel::GoalsController.controller_path)
    @student_membership.update_attribute(:last_visited_tab, ScrapsController.controller_path)

    @controller.expects(:prepare_template).never
    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert assigns(:show_mentoring_model_goals_tab)
    assert_redirected_to group_mentoring_model_goals_path(@group)
  end

  def test_show_handle_last_visited_tab_with_goals_disabled
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentor_membership.update_attribute(:last_visited_tab, MentoringModel::GoalsController.controller_path)

    @controller.expects(:prepare_template).once
    current_user_is @mentor_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_false assigns(:show_mentoring_model_goals_tab)
    assert_response :success
  end

  def test_show_handle_last_visited_tab_with_meetings
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    create_object_role_permission("manage_mm_meetings", role: "users", object: @group)
    @mentor_membership.update_attribute(:last_visited_tab, Connection::PrivateNotesController.controller_path)
    @student_membership.update_attribute(:last_visited_tab, MeetingsController.controller_path)

    @controller.expects(:prepare_template).never
    current_user_is @student_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert assigns(:show_meetings_tab)
    assert_redirected_to meetings_path(group_id: @group)
  end

  def test_show_handle_last_visited_tab_with_meetings_disabled
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    @student_membership.update_attribute(:last_visited_tab, MeetingsController.controller_path)

    @controller.expects(:prepare_template).once
    current_user_is @student_membership.user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_false assigns(:show_meetings_tab)
    assert_response :success
  end
end