require_relative './../../test_helper.rb'

class GroupsController::GroupsControllerTest < ActionController::TestCase
  tests GroupsController

  include ApplicationHelper

  def setup
    super
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @program_roles = program.roles.group_by(&:name)
    GroupsController.class_eval do
      def group_params
        if @_params[:filters_applied].present?
          @_params
        elsif @_params[:abstract_view_id] && @_abstract_view.nil?
          @_abstract_view = current_program.abstract_views.find(@_params[:abstract_view_id])
          @_abstract_view.filter_params_hash[:params].each do |key, value|
            @_params[key] = value unless @_params.has_key?(key)
          end
          @_group_params_with_abstract_view_params = @_params
        elsif @_params[:abstract_view_id] && @_abstract_view
          @_group_params_with_abstract_view_params
        else
          @_params
        end
      end
      def params
        if caller[0].match(/back_mark|tab_configuration_helper|application_controller|feature_manager|analytics_helper|remotipart|actionpack|set_view_mode|action_view|authentication_extensions/)
          super
        else
          raise "Groups controller 'params' method is getting called, please use 'group_params' instead of 'params'"
        end
      end
    end
  end

  def test_setup_meeting
    current_user_is :f_mentor

    get :setup_meeting, xhr: true, params: { id: users(:f_mentor).groups.active.first, past_meeting: true, common_form: true }
    assert_response :success

    assert assigns(:past_meeting)
    assert assigns(:common_form)
    assert_equal users(:f_mentor).groups.active.first, assigns(:group)
  end

  def test_index_closed_connections
    current_user_is :f_admin

    get :index, params: { :tab => Group::Status::CLOSED, :view => Group::View::DETAILED}
    assert_response :success

    assert_equal [groups(:group_4)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal Group::Status::CLOSED, assigns(:filter_field)
    assert_equal Group::View::DETAILED, assigns(:view)
    assert_select 'ul.nav' do
      assert_select 'li.ct_active', :text => /Closed/
      assert_select "a[href=?]", groups_path(:tab => Group::Status::CLOSED, :view => Group::View::DETAILED)
    end
    assert_select "div#group_pane_#{groups(:group_4).id}" do
      assert_select "a[href=?]", member_path(groups(:group_4).closed_by.member)
    end
    assert_select 'div.actions_box' do
      assert_select "a[href=?]", group_path(groups(:group_4))
      assert_select 'ul.dropdown-menu' do
        assert_select 'li' do
          assert_select 'a', :text => /Reactivate Mentoring Connection/
        end
      end
    end
    assert_select "ul#tab-box" do
      assert_select "li#drafted_tab"
      assert_no_select "li#proposed_tab"
      assert_no_select "li#pending_tab"
      assert_select "li#ongoing_tab"
      assert_select "li#closed_tab"
      assert_no_select "li#rejected_tab"
    end
  end

  def test_index_with_src
    current_user_is :f_admin
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_index_no_src
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_profile_with_from_find_new
    current_user_is :f_student_pbe
    group = groups(:group_pbe_0)

    get :profile, params: { id: group.id, from_find_new: "true"}
    assert_equal "true", assigns(:from_find_new)
    assert assigns(:is_group_profile_view)
    assert_false assigns(:manage_circle_members)
    assert_false assigns(:show_set_start_date_popup)
  end

  def test_profile_without_from_find_new
    current_user_is :f_student_pbe
    group = groups(:group_pbe_0)

    get :profile, params: { id: group.id, manage_circle_members: "true", show_set_start_date_popup: "true"}

    assert_nil assigns(:from_find_new)
    assert assigns(:is_group_profile_view)
    assert assigns(:manage_circle_members)
    assert assigns(:show_set_start_date_popup)
  end

  def test_index_for_find_new
    current_user_is :f_admin
    get :index, params: { from_find_new: "true"}
    assert_nil assigns(:from_find_new)
    assert_nil assigns(:is_group_profile_view)
  end

  def test_first_group_redirect
    current_user_is :f_mentor
    assert users(:f_mentor).groups.active.first
    get :index, params: { first_group: true}
    assert_redirected_to group_path(users(:f_mentor).groups.active.first)
    get :index, params: { first_group: true, announcement: true}
    assert_redirected_to group_path(users(:f_mentor).groups.active.first, src: EngagementIndex::Src::Announcement)
  end

  def test_first_group_redirect_when_no_group
    current_user_is :f_admin
    assert_nil users(:f_admin).groups.active.first
    get :index, params: { first_group: true}
    assert_redirected_to groups_path(show: 'my')
    get :index, params: { first_group: true, announcement: true}
    assert_redirected_to groups_path(show: 'my', src: EngagementIndex::Src::Announcement)
  end

  def test_index_connections_count_for_global_view
    current_user_is :f_admin
    p = programs(:albers)
    allow_one_to_many_mentoring_for_program(p)
    mentor = users(:f_mentor)
    student = users(:f_student)
    group = create_group(:students => [student], :mentor => mentor, :program => p)

    org = programs(:org_primary)
    org.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    assert org.connection_profiles_enabled?
    assert org.programs.ordered.first.connection_profiles_enabled?

    group.global = true
    group.status = Group::Status::CLOSED
    group.closed_at = Time.now
    group.closed_by = users(:f_admin)
    group.termination_mode = Group::TerminationMode::ADMIN
    group.closure_reason_id = group.get_auto_terminate_reason_id
    group.save!
    get :index, params: { :show => 'global'}
    assert_equal true, assigns(:is_global_connections_view)
    assert_false assigns(:is_manage_connections_view)
    assert_equal 'global', assigns(:show_params)
    assert group.global?
    assert_equal 2, assigns(:tab_counts)[:ongoing]
    assert_equal 1, assigns(:tab_counts)[:closed]
  end

  def test_index_connections_count_for_current_user_view
    current_user_is :f_mentor
    p = programs(:albers)
    allow_one_to_many_mentoring_for_program(p)
    mentor = users(:f_mentor)
    student = users(:f_student)
    group = create_group(:students => [student], :mentor => mentor, :program => p)

    group.global = true
    group.status = Group::Status::CLOSED
    group.closed_at = Time.now
    group.closed_by = users(:f_admin)
    group.termination_mode = Group::TerminationMode::ADMIN
    group.closure_reason_id = group.get_auto_terminate_reason_id
    group.save!

    get :index, params: { :show => 'my'}
    assert_false assigns(:is_global_connections_view)
    assert_false assigns(:is_manage_connections_view)
    assert_equal 'my', assigns(:show_params)
    assert_equal 1, assigns(:tab_counts)[:ongoing]
    assert_equal 1, assigns(:tab_counts)[:closed]
  end

  def test_index_should_not_show_lock_icon_when_audit_log_disabled
    current_user_is :f_admin
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::OPEN
    programs(:albers).save!
    get :index, params: { :filter => GroupsController::StatusFilters::Code::ACTIVE}
    assert_equal Group::View::DETAILED, assigns(:view)
    assert_select 'div#groups' do
      assert_select "div#group_2" do
        assert_select 'div.actions_box' do
          assert_no_select 'a.lock'
        end
      end
    end
  end

  def test_index_active_with_start_new_params
    role = create_role(:name => 'connection_admin', :program => programs(:moderated_program))
    @connection_admin = create_user(:name => 'connection_admin_name',:role_names => ['connection_admin'], :program => programs(:moderated_program))
    current_user_is @connection_admin
    add_role_permission(role, 'manage_connections')

    get :index, params: { :show_new => "true"}

    assert assigns(:group)
    assert_match "#{GroupCreationNotificationToMentor.mailer_attributes[:uid]}", @response.body
    assert_match "#{GroupCreationNotificationToStudents.mailer_attributes[:uid]}", @response.body
    assert_match "group_new", @response.body
  end

  def test_index_drafted_connections_with_status
    current_user_is :f_admin
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)

    get :index, params: { :tab => Group::Status::DRAFTED}
    assert_response :success
    assert_equal_unordered [
      groups(:drafted_group_1),
      groups(:drafted_group_2),
      groups(:drafted_group_3)
    ].collect(&:id), assigns(:groups).collect(&:id)
    assert_select 'ul.nav' do
      assert_select 'li.ct_active', :text => /Drafted/
      assert_select "a[href=?]", groups_path(:tab => Group::Status::DRAFTED, :view => Group::View::DETAILED)
    end
    assert_select "div#group_pane_#{groups(:drafted_group_1).id}" do
      assert_select "a[href=?]", member_path(groups(:drafted_group_1).created_by.member)
      assert_select "span.font-bold", text: "Drafted:"
    end
    assert_select "ul#tab-box" do
      assert_select "li#drafted_tab"
      assert_no_select "li#proposed_tab"
      assert_no_select "li#pending_tab"
      assert_select "li#ongoing_tab"
      assert_select "li#closed_tab"
      assert_no_select "li#rejected_tab"
    end
  end

  def test_no_listing_if_no_privilege
    current_program_is :moderated_program
    current_user_is make_member_of(:moderated_program, :f_student)

    get :index
    assert !users(:f_student).can_manage_connections?
    assert_false assigns(:is_manage_connections_view)
    assert_false assigns(:is_global_connections_view)
    assert assigns(:is_my_connections_view)
  end

  def test_no_listing_for_mentor
    current_program_is :moderated_program
    current_user_is make_member_of(:moderated_program, :f_mentor)

    get :index
    assert_false assigns(:is_manage_connections_view)
    assert_false assigns(:is_global_connections_view)
    assert assigns(:is_my_connections_view)
  end

  def test_listing_for_admin
    current_user_is :f_admin

    get :index
    assert_equal_unordered [groups(:group_5), groups(:group_inactive), groups(:group_3), groups(:group_2), groups(:old_group), groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)
    assert assigns(:is_manage_connections_view)
    assert_false assigns(:is_my_connections_view)
    assert_false assigns(:is_global_connections_view)
    assert_template 'index'

    # Assert that 'Manage' tab is the selected tab
    assert_select 'ul#side-menu' do
      assert_select 'li.active', :text => 'Home', :count => 0
      assert_select 'li.active', :text => 'Manage'
    end
    assert_tab("Manage")
    # Do not show summary for admins
    assert_select 'dt', :text => 'Summary', :count => 0
  end

  def test_listing_of_my_connections
    u = users(:not_requestable_mentor)
    current_user_is u

    get :index, params: { :show => 'my'}
    assert_equal true, assigns(:is_my_connections_view)
    assert_false assigns(:is_manage_connections_view)
    assert_equal 2, assigns(:groups).size

    # Assert that 'My Mentoring Connections' tab is the selected tab
    assert_select 'ul#side-menu' do
      assert_select 'li.active', :text => 'Home', :count => 0
      assert_select 'li.active', :text => /mentor & example/
      assert_select 'li.active', :text => 'Manage', :count => 0
    end

    # Assert filters
    assert_page_title "Mentoring Connections"

    # Assert sort filters
    assert_select 'select#sort_by' do
      assert_select 'option', :count => 4
      assert_select 'option', :text => 'Recently active'
      assert_select 'option', :text => 'Most active'
      assert_select 'option', :text => 'Recently connected'
      assert_select 'option', :text => 'Expiration time'
    end

    assert_select "div#group_#{u.groups.first.id}" do
      # Admin actions should not be shown
      assert_no_select 'Goal Progress'
      assert_select 'ul.dropdown-menu'
    end
  end

  def test_index_mobile
    user = users(:f_mentor)

    current_user_is user
    get :index_mobile
    assert_response :success
    assert_equal [Group::Status::ACTIVE, Group::Status::INACTIVE], assigns(:with_options)[:status]
    assert_equal [Group::Status::ACTIVE, Group::Status::INACTIVE], assigns(:es_filter_hash)[:must_filters][:status]
    assert_equal user.member_id, assigns(:with_options)["members.id"]
    assert_equal user.program_id, assigns(:es_filter_hash)[:must_filters][:program_id]
    assert_equal "desc", assigns(:es_filter_hash)[:sort]["last_member_activity_at"]
  end

  def test_index_ongoing_connections_with_status
    current_user_is :not_requestable_mentor

    get :index, params: { :show => 'my', :filter => GroupsController::StatusFilters::Code::ONGOING}
    assert_response :success

    assert_equal true, assigns(:is_my_connections_view)
    assert_false assigns(:is_manage_connections_view)
    assert_equal [Group::Status::ACTIVE, Group::Status::INACTIVE], assigns(:filter_field)
    assert_equal 2, assigns(:groups).size

    # Assert filters
    assert_page_title "Mentoring Connections"
  end

  def test_listing_of_all_global_connections
    u = users(:mentor_1)
    org = programs(:org_primary)
    org.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    assert org.connection_profiles_enabled?
    assert org.programs.ordered.first.connection_profiles_enabled?

    current_user_is u

    get :index, params: { :show => 'global'}

    assert_equal true, assigns(:is_global_connections_view)
    assert_false assigns(:is_manage_connections_view)
    assert_equal 2, assigns(:groups).size

    # Assert filters
    assert_page_title "Mentoring Connections"
    assert_select 'div.filter_links', :count => 0

    # Assert sort filters
    assert_select 'select#sort_by' do
      assert_select 'option', :count => 4
      assert_select 'option', :text => 'Recently active'
      assert_select 'option', :text => 'Most active'
      assert_select 'option', :text => 'Recently connected'
      assert_select 'option', :text => 'Expiration time'
    end

    assert_select "div#group_#{u.program.groups.global.first.id}" do
      assert_select 'a', :href => profile_group_path(u.program.groups.global.first.id)
      assert_select 'div.col-sm-3', :text => 'Active since'
    end
  end

  def test_groups_list_view_no_columns_to_display
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    program.group_view.group_view_columns.destroy_all

    get :index, params: { view: Group::View::LIST}
    assert_response :success
    assert_template partial: '_no_columns'
    assert_match "No columns to display", response.body
  end

  def test_sort_by_teacher_name_asc
    current_user_is :f_admin_pbe
    program = programs(:pbe)

    session[:groups_view] = Group::View::LIST
    get :index, params: { sort: 'role_users_full_name.teacher_name', order: 'asc', tab: Group::Status::REJECTED, view: Group::View::LIST}
    assert_response :success
    assert_equal [groups(:rejected_group_1).id, groups(:rejected_group_2).id], assigns(:groups).collect(&:id)
    assert_equal 'role_users_full_name.teacher_name', assigns(:sort_field)
    assert_equal 'asc', assigns(:sort_order)
  end

  def test_sort_by_teacher_name_desc
    current_user_is :f_admin_pbe
    session[:groups_view] = Group::View::LIST

    get :index, params: { sort: 'role_users_full_name.teacher_name', order: 'desc', tab: Group::Status::REJECTED, view: Group::View::LIST}
    assert_response :success
    assert_equal [groups(:rejected_group_2).id, groups(:rejected_group_1).id], assigns(:groups).collect(&:id)
    assert_equal 'role_users_full_name.teacher_name', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
  end

  def test_sort_by_activity_least
    current_user_is :f_admin

    # Least active
    get :index, params: { :sort => 'activity', :order => 'asc'}
    assert_response :success
    assert_equal_unordered [groups(:group_2), groups(:group_5), groups(:group_inactive), groups(:old_group), groups(:group_3), groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'activity', assigns(:sort_field)
    assert_equal 'asc', assigns(:sort_order)
  end

  def test_sort_by_activity_most
    current_user_is :f_admin

    # Most active
    get :index, params: { :sort => 'activity', :order => 'desc'}
    assert_response :success
    assert_equal_unordered [groups(:mygroup), groups(:group_3), groups(:group_2), groups(:group_5), groups(:group_inactive), groups(:old_group)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'activity', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
  end

  def test_user_profile_fields_filter
    program = programs(:pbe)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    profile_question = profile_questions(:profile_questions_3)
    location_profile_answer_member_ids = ProfileAnswer.where(profile_question_id: profile_question.id).collect(&:ref_obj_id)
    location_profile_answer_user_ids = User.where(member_id: location_profile_answer_member_ids, program_id: program.id).pluck(:id)
    filtered_group_ids = program.connection_memberships.where(role_id: mentor_role.id, user_id: location_profile_answer_user_ids).collect(&:group_id)

    current_user_is :f_admin_pbe
    get :index, params: { member_profile_filters: { mentor_role.id.to_s => [ { "field" => "column#{profile_question.id}", "operator" => "answered", "value" => "" } ] } }
    assert_equal "Mentor profile fields", assigns(:my_filters).first[:label]
    assert_equal_unordered filtered_group_ids, assigns(:with_options)[:id]
  end

  def test_select_all_ids_profile_fields_filter
    program = programs(:pbe)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    profile_question = profile_questions(:profile_questions_3)
    location_profile_answer_member_ids = ProfileAnswer.where(profile_question_id: profile_question.id).collect(&:ref_obj_id)
    location_profile_answer_user_ids = User.where(member_id: location_profile_answer_member_ids, program_id: program.id).pluck(:id)
    filtered_group_ids = program.connection_memberships.where(role_id: mentor_role.id, user_id: location_profile_answer_user_ids).collect(&:group_id)

    current_user_is :f_admin_pbe
    get :select_all_ids, params: { member_profile_filters: { mentor_role.id.to_s => [ { "field" => "column#{profile_question.id}", "operator" => "answered", "value" => "" } ] } }
    assert_equal "Mentor profile fields", assigns(:my_filters).first[:label]
    assert_equal_unordered filtered_group_ids, assigns(:with_options)[:id]
  end

  def test_select_all_ids_handles_filters
    current_user_is :f_admin
    @controller.expects(:handle_filters_and_init_connections_questions)
    get :select_all_ids, params: { member_profile_filters: { "92" => [ { "field" => "column3", "operator" => "answered", "value" => "" } ] } }
  end

  def test_user_profile_fields_filter_does_not_contain
    program = programs(:albers)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    profile_question = profile_questions(:single_choice_q)
    question_choice = question_choices(:single_choice_q_1)
    profile_answer_ids = AnswerChoice.where(question_choice_id: question_choice.id).collect(&:ref_obj_id)
    profile_answer_member_ids = ProfileAnswer.where(id: profile_answer_ids).collect(&:ref_obj_id)
    profile_answer_user_ids = User.where(member_id: profile_answer_member_ids, program_id: program.id).pluck(:id)
    filtered_group_ids = program.group_ids - (program.connection_memberships.where(role_id: mentor_role.id, user_id: profile_answer_user_ids).collect(&:group_id))

    current_user_is :f_admin
    get :index, params: { member_profile_filters: { mentor_role.id.to_s => [ { "field" => "column#{profile_question.id}", "operator" => "not_eq", "value" => question_choice.id.to_s } ] } }
    assert_equal_unordered filtered_group_ids, assigns(:with_options)[:id]
    assert_equal "Mentor profile fields", assigns(:my_filters).first[:label]
  end

  def test_index_not_accessible_at_org_level
    current_member_is :f_admin

    get :index
    assert_redirected_to programs_list_path
  end

  def test_remove_upcoming_meetings_of_group_on_closing_group
    time_now = Time.now
    current_user_is :f_admin
    group = groups(:mygroup)
    meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(group.meetings, with_starttime_in: true, start_time: time_now, end_time: group.expiry_time)
    assert meetings_to_be_held.any?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    post :destroy, xhr: true, params: { :group => {:termination_reason => "Test reason", closure_reason: groups(:mygroup).get_auto_terminate_reason_id}, :id => groups(:mygroup).id}
    group.reload
    assert_false group.active?
    assert_equal "Test reason", group.termination_reason
    assert_equal users(:f_admin), group.closed_by
    assert_not_nil group.closed_at
    meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(group.meetings, with_starttime_in: true, start_time: time_now, end_time: group.expiry_time)
    assert_empty meetings_to_be_held
  end

  def test_destroy_group_only_by_admin
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    assert_permission_denied  do
      post :destroy, xhr: true, params: { :group => {:termination_reason => "Test reason", closure_reason: groups(:mygroup).get_auto_terminate_reason_id}, :id => groups(:mygroup).id}
    end
  end

  def test_destroy_group_by_owner
    current_user_is :f_mentor
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).once
    post :destroy, xhr: true, params: { :group => {:termination_reason => "Test reason", closure_reason: groups(:mygroup).get_auto_terminate_reason_id}, :id => groups(:mygroup).id}

    group = groups(:mygroup).reload
    assert_false group.active?
    assert_equal "Test reason", group.termination_reason
    assert_equal users(:f_mentor), group.closed_by
    assert_not_nil group.closed_at
  end

  def test_should_reactivate_group
    new_expiry_date = groups(:mygroup).expiry_time + 4.months
    current_user_is :f_admin
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert_emails 2 do
      assert_difference "RecentActivity.count" do
        post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Restart", :mentoring_period => new_expiry_date}
      end
    end
    group = groups(:mygroup).reload
    assert group.active?
    assert_equal new_expiry_date.utc.to_s, group.expiry_time.utc.to_s

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::GROUP_REACTIVATION, ra.action_type
    assert_equal users(:f_admin), ra.get_user(group.program)
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_equal "Restart", ra.message
  end

  def test_manage_connection_redirect_for_reactivate_connection
    current_user_is :f_admin
    g=groups(:group_4)
    new_expiry_date = g.expiry_time + 4.months
    post :update, params: { :id => g.id, :revoking_reason => "Restart", :mentoring_period => new_expiry_date,
      :manage_connections_member => g.members.first.id, :filter =>GroupsController::StatusFilters::Code::ACTIVE}
    assert_redirected_to member_path(:id => g.members.first.id, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS,
      :filter => GroupsController::StatusFilters::Code::ACTIVE)
  end

  def test_should_not_reactivate_group_if_connections_limit_for_mentor_is_reached
    new_expiry_date = groups(:mygroup).expiry_time + 4.months

    current_user_is :f_admin
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    users(:f_mentor).update_attribute(:max_connections_limit, 0)

    post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Restart", :mentoring_period => new_expiry_date}

    # Connection is still closed since the action failed.
    assert groups(:mygroup).reload.closed?
    assert_equal "#{users(:f_mentor).name} preferred not to have more than 0 students", flash[:error]
  end

  def test_should_not_reactivate_group_without_extension_period
    current_user_is :f_admin
    expiry_time = 2.months.from_now.beginning_of_day
    groups(:mygroup).update_attribute(:expiry_time, expiry_time)
    assert_equal expiry_time, groups(:mygroup).expiry_time
    groups(:mygroup).terminate!(users(:f_admin),"Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert_no_emails do
      assert_no_difference "RecentActivity.count" do
        post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Restart"}
      end
    end
    group = groups(:mygroup).reload
    assert group.closed?
    assert_time_string_equal expiry_time, group.expiry_time

    assert_redirected_to groups_path
    assert_equal "Please provide a reason for changing the expiration date.", flash[:error]
  end

  def test_should_change_expiry_date
    current_user_is :f_admin

    expiry_time = 1.week.from_now.beginning_of_day
    new_expiry_date = groups(:mygroup).expiry_time + 4.months

    groups(:mygroup).update_attribute(:expiry_time, expiry_time)
    assert_equal expiry_time.utc.to_s, groups(:mygroup).expiry_time.utc.to_s
    assert_pending_notifications 2 do
      assert_difference "RecentActivity.count" do
        post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Extension Reason", :mentoring_period => new_expiry_date}
      end
    end

    group = groups(:mygroup).reload
    assert group.active?
    assert_equal new_expiry_date.utc.to_s, group.expiry_time.utc.to_s

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, ra.action_type
    assert_equal members(:f_admin), ra.member
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_equal "Extension Reason", ra.message
  end

  def test_manage_connection_redirect_for_set_expiry_date
    current_user_is :f_admin
    new_expiry_date = groups(:mygroup).expiry_time + 4.months
    post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Extension Reason", :mentoring_period => new_expiry_date,
      :manage_connections_member =>2, :filter => GroupsController::StatusFilters::Code::INACTIVE}
    assert_redirected_to member_path(:id => 2, :tab => MembersController::ShowTabs::MANAGE_CONNECTIONS,
      :filter => GroupsController::StatusFilters::Code::INACTIVE)
  end

  def test_manage_connection_redirect_for_close_connection
    current_user_is :f_admin
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    post :destroy, xhr: true, params: { :id => groups(:mygroup).id, :group => {:group_termination_reason =>"Gen", closure_reason: groups(:mygroup).get_auto_terminate_reason_id},
      :manage_connections_member =>2, :filter => GroupsController::StatusFilters::Code::INACTIVE}
    assert_response :success
  end

  def test_should_extend_group
    new_expiry_date = groups(:mygroup).expiry_time + 4.months
    current_user_is :f_admin
    expiry_time = 1.week.from_now.beginning_of_day
    groups(:mygroup).update_attribute(:expiry_time, expiry_time)
    assert_equal expiry_time, groups(:mygroup).expiry_time
    assert_pending_notifications 2 do
      assert_difference "RecentActivity.count" do
        post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Extension Reason", :mentoring_period => new_expiry_date}
      end
    end
    group = groups(:mygroup).reload
    assert group.active?
    assert_equal new_expiry_date.utc.to_s, group.expiry_time.utc.to_s

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, ra.action_type
    assert_equal users(:f_admin), ra.get_user(group.program)
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_equal "Extension Reason", ra.message
  end

  def test_should_not_extend_group_without_extension_period
    current_user_is :f_admin
    expiry_time = 2.months.from_now.beginning_of_day
    groups(:mygroup).update_attribute(:expiry_time, expiry_time)
    assert_equal expiry_time, groups(:mygroup).expiry_time
    assert_no_emails do
      assert_no_difference "RecentActivity.count" do
        post :update, params: { :id => groups(:mygroup).id, :revoking_reason => "Restart"}
      end
    end

    group = groups(:mygroup).reload
    assert_time_string_equal expiry_time, group.expiry_time

    assert_redirected_to groups_path
    assert_equal "Please provide a reason for changing the expiration date.", flash[:error]
  end

  def test_new_member_auto_complete_field
    current_user_is :f_admin

    get :new_member_auto_complete_field, xhr: true
  end

  def test_new
    current_user_is :f_admin
    users(:f_admin).program.roles.find_by(name: RoleConstants::STUDENT_NAME).customized_term.update_attribute :term, 'Apple'

    p = programs(:albers)
    allow_one_to_many_mentoring_for_program(p)
    assert p.allow_one_to_many_mentoring?

    get :new, xhr: true, params: { :format => :js}
    assert assigns(:group).new_record?
    assert_equal programs(:albers), assigns(:group).program
    assert_match 'group_new', @response.body
    assert_match(/An email will be sent to the users \(.*#{GroupCreationNotificationToMentor.mailer_attributes[:uid]}.*mentors.*and.*#{GroupCreationNotificationToStudents.mailer_attributes[:uid]}.*students.*\) if you complete this action./, @response.body)
  end

  def test_edit
    allow_one_to_many_mentoring_for_program(programs(:albers))
    current_user_is users(:f_admin)
    g = Group.first

    get :edit, xhr: true, params: { :id => g.id}
    assert_match GroupMemberAdditionNotificationToNewMember.mailer_attributes[:uid], @response.body
    assert_match GroupMemberRemovalNotificationToRemovedMember.mailer_attributes[:uid], @response.body
    assert_match "edit_group_#{g.id}", @response.body
    assert_match "update_group_members_#{g.id}", @response.body
  end

  def test_edit_permission_denied_for_non_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    current_user_is users(:f_mentor)
    g = Group.first

    assert_permission_denied do
      get :edit, xhr: true, params: { :id => g.id}
    end
  end

  def test_add_new_member
    group = groups(:mygroup)
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    get :add_new_member, xhr: true, params: { id: group.id,
      add_member: "adfas safdas f", group: { add_member_option: Group::AddOption::ADD_TASKS }, role_id: role_name_id_map[RoleConstants::MENTOR_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_nil assigns(:new_user)
    assert_nil assigns(:student_ids_mentor_ids)
    assert_equal "Please enter a valid user", assigns(:error_flash)
  end

  def test_add_new_member_invalid_member
    group = groups(:mygroup)
    program = group.program
    admin = program.admin_users.first
    role_name_id_map = get_mentoring_role_id_name_map(program)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is admin
    get :add_new_member, xhr: true, params: { id: group.id, add_member: "#{admin.name}<#{admin.email}>", group: { add_member_option: Group::AddOption::ADD_TASKS },
      role_id: role_name_id_map[RoleConstants::MENTOR_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_equal admin, assigns(:new_user)
    assert_nil assigns(:student_ids_mentor_ids)
    assert_equal "Please enter a valid user", assigns(:error_flash)
  end

  def test_add_new_member_valid_member
    group = groups(:mygroup)
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)
    new_user = users(:f_student)
    assert group.members.exclude?(new_user)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    get :add_new_member, xhr: true, params: { id: group.id, add_member: "#{new_user.name}<#{new_user.email}>", group: { add_member_option: Group::AddOption::ADD_TASKS },
      role_id: role_name_id_map[RoleConstants::STUDENT_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::STUDENT_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_equal new_user, assigns(:new_user)
    assert_equal [group.student_ids + [new_user.id], group.mentor_ids], assigns(:student_ids_mentor_ids)
    assert_nil assigns(:error_flash)
  end

  def test_add_new_member_valid_member_without_existing_groups_alert
    group = groups(:mygroup)
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)
    new_user = users(:f_student)
    assert group.members.exclude?(new_user)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(false)
    current_user_is program.admin_users.first
    get :add_new_member, xhr: true, params: { id: group.id, add_member: "#{new_user.name}<#{new_user.email}>", group: { add_member_option: Group::AddOption::ADD_TASKS },
      role_id: role_name_id_map[RoleConstants::STUDENT_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::STUDENT_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_equal new_user, assigns(:new_user)
    assert_nil assigns(:student_ids_mentor_ids)
    assert_nil assigns(:error_flash)
  end

  def test_replace_member
    group = groups(:mygroup)
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    get :replace_member, xhr: true, params: { id: group.id, user_id: group.mentors.first,
      replace_member: "adfas safdas f", role_id: role_name_id_map[RoleConstants::MENTOR_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_nil assigns(:new_user)
    assert_nil assigns(:student_ids_mentor_ids)
    assert_equal "Please enter a valid user", assigns(:error_flash)
  end

  def test_replace_member_invalid_member
    group = groups(:mygroup)
    program = group.program
    admin = program.admin_users.first
    role_name_id_map = get_mentoring_role_id_name_map(program)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is admin
    get :replace_member, xhr: true, params: { id: group.id, user_id: group.mentors.first,
      replace_member: "#{admin.name}<#{admin.email}>", role_id: role_name_id_map[RoleConstants::MENTOR_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_equal admin, assigns(:new_user)
    assert_nil assigns(:student_ids_mentor_ids)
    assert_equal "Please enter a valid user", assigns(:error_flash)
  end

  def test_replace_member_valid_member
    group = groups(:mygroup)
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)
    student = group.students.first
    new_user = users(:f_student)
    assert group.members.exclude?(new_user)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    get :replace_member, xhr: true, params: { id: group.id, user_id: student.id,
      replace_member: "#{new_user.name}<#{new_user.email}>", role_id: role_name_id_map[RoleConstants::STUDENT_NAME], group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal RoleConstants::STUDENT_NAME, assigns(:role).name
    assert_equal group, assigns(:group)
    assert_equal new_user, assigns(:new_user)
    assert_equal [group.student_ids + [new_user.id] - [student.id], group.mentor_ids], assigns(:student_ids_mentor_ids)
    assert_nil assigns(:error_flash)
  end

  def test_remove_new_member
    group = groups(:mygroup)
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)
    student = group.students.first

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    get :remove_new_member, xhr: true, params: { id: group.id, user_id: student.id, role_id: role_name_id_map[RoleConstants::STUDENT_NAME],
      group: { remove_member_option: Group::RemoveOption::REMOVE_TASKS }, group_id: group.id,
      selected_user_ids: { role_name_id_map[RoleConstants::MENTOR_NAME].to_s => group.mentor_ids.join(","), role_name_id_map[RoleConstants::STUDENT_NAME].to_s => group.student_ids.join(",") }}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_nil assigns(:new_user) || assigns(:role) || assigns(:error_flash)
    assert_equal [[], group.mentor_ids], assigns(:student_ids_mentor_ids)
  end

  def test_edit_for_non_admin_owner
    current_user_is :f_mentor
    group = groups(:mygroup)
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)

    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    get :edit, xhr: true, params: { :id => g.id}
    assert_equal group, assigns(:group)
  end

  def test_set_expiry_date
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    current_user_is  :f_admin
    g = groups(:mygroup)
    get :index, params: { filter: GroupsController::StatusFilters::Code::ACTIVE}
    assert_response :success
    assert_select 'div#groups' do
      assert_select "div#group_#{g.id}" do
        assert_select "div#group_pane_#{g.id}" do
          assert_select "div.col-sm-3", :text => "Expires in"
        end
        assert_select "div.actions_box" do
          assert_select "ul.dropdown-menu" do
            assert_select "a#set_expiry_date_#{g.id}"
          end
        end
      end
    end
  end

  #=============================================================================
  # CREATE
  #=============================================================================

  def test_create_success_one_to_one
    group_setup
    current_user_is :f_admin
    @mentor.update_attribute(:max_connections_limit, 3)

    assert_emails 2 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group_members => {
            :role_id => {
              @program_roles[RoleConstants::MENTOR_NAME].first.id => @mentor.name_with_email,
              @program_roles[RoleConstants::STUDENT_NAME].first.id => users(:rahim).name_with_email
            }
          }, :group => {}}
      end
    end

    assert !assigns(:mentor_request_params)
    delivered_email = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered [users(:rahim).email], delivered_email[0].to
    assert_equal_unordered [@mentor.email], delivered_email[1].to

    assert_equal @program, assigns(:group).program
    assert_equal [@mentor], assigns(:group).mentors
    assert_equal [users(:rahim)], assigns(:group).students
    assert_match "groups_listing", @response.body
    assert_nil assigns(:existing_groups_alert)
    assert assigns(:is_manage_connections_view)
  end

  def test_create_failure_with_out_mentor_one_to_one
    current_user_is :f_admin

    assert_emails 0 do
      assert_no_difference "Group.count" do
        post :create, xhr: true, params: { :group => {}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => "",
            @program_roles[RoleConstants::STUDENT_NAME].first.id => users(:rahim).name_with_email
          }
        }}
      end
    end
    assert_response :success
  end

  def test_create_failure_with_mentor_from_different_program_one_to_one
    current_user_is :f_admin

    assert_emails 0 do
      assert_no_difference "Group.count" do
        post :create, xhr: true, params: { :group => {}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => "<Aweomse Dude> xyz@chronus.com",
            @program_roles[RoleConstants::STUDENT_NAME].first.id => users(:rahim).name_with_email
          }
        }}
      end
    end
    assert !assigns(:mentor_request_params)
    assert_response :success
  end

  def test_create_failure_with_out_student_one_to_one
    current_user_is :f_admin

    assert_emails 0 do
      assert_no_difference "Group.count" do
        post :create, xhr: true, params: { :group => {}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => users(:f_mentor).name_with_email,
            @program_roles[RoleConstants::STUDENT_NAME].first.id => ""
          }
        }}
      end
    end
    assert !assigns(:mentor_request_params)
    assert_response :success
  end

  def test_create_from_request_success
    current_user_is :moderated_admin

    mentor = users(:moderated_mentor)
    student = users(:moderated_student)
    assert mentor.mentoring_groups.empty?
    mentor_request = mentor_requests(:moderated_request_with_favorites)

    assert_emails 2 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group => {
          :mentor_name => mentor.name_with_email},
          :mentor_request_id => mentor_request.id
        }
      end
    end

    assert_response :success
    assert assigns(:mentor_request_params)
    assert_equal mentor_request, assigns(:mentor_request)

    # Request accepted
    assert_equal AbstractRequest::Status::ACCEPTED, mentor_request.reload.status

    group = Group.last
    assert_equal programs(:moderated_program), group.program
    assert_equal [mentor], group.mentors
    assert_equal [student], group.students
    assert_match "results_pane", @response.body
    assert_match("#modal_preferred_mentors_for_1\"\).modal\('hide'\)", @response.body)
    assert_equal 1, assigns(:page)
    assert_equal [], assigns(:mentor_requests)
    assert_nil assigns(:existing_groups_alert)
  end

  def test_create_from_request_success_with_pagination
    current_user_is :moderated_admin
    mentor = users(:moderated_mentor)

    request = programs(:moderated_program).mentor_requests.first

    assert_emails 2 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group => {:mentor_name => mentor.name_with_email}, :mentor_request_id => request.id, page: 2}
      end
    end

    assert_response :success
    assert_equal AbstractRequest::Status::ACCEPTED, request.reload.status
    assert_match "results_pane", @response.body
    assert_match("#modal_preferred_mentors_for_1\"\).modal\('hide'\)", @response.body)
    assert_equal 1, assigns(:page)
    assert_equal [], assigns(:mentor_requests)
    assert_false assigns(:match_results_per_mentor).present?
  end

  def test_create_with_mentoring_model
    current_user_is :moderated_admin
    mentor = users(:moderated_mentor)
    program = programs(:moderated_program)
    request = program.mentor_requests.first
    mentoring_model = programs(:moderated_program).mentoring_models.last
    post :create, xhr: true, params: { :group => {:mentor_name => mentor.name_with_email}, mentor_request_id: request.id, mentoring_model_id: mentoring_model.id}
    assert_equal program.groups.last.mentoring_model, mentoring_model
    assert program.groups.last.mentors.include?(mentor)
  end

  # Test to cover the exception http://chronus.airbrake.io/projects/14592/errors/707378
  def test_create_from_request_success_when_a_other_request_with_pref_mentors_present
    current_user_is :moderated_admin

    # Making sure that program has other requests with favorites
    assert programs(:moderated_program).mentor_requests.first.request_favorites.any?

    request_1 = create_mentor_request(:student => users(:moderated_student),
      :program => programs(:moderated_program))
    assert_equal 2, programs(:moderated_program).reload.mentor_requests.count

    assert_emails 2 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group => {:mentor_name => users(:moderated_mentor).name_with_email}, :mentor_request_id => request_1.id}
      end
    end

    assert_response :success
    assert_match "results_pane", @response.body
  end

  def test_create_from_request_where_mentor_has_existing_connections
    current_user_is :moderated_admin
    p = programs(:moderated_program)
    make_member_of(:moderated_program, :student_3)
    allow_one_to_many_mentoring_for_program(p)

    mentor = users(:moderated_mentor)
    student = users(:student_3)
    group = create_group(:students => [student], :mentor => mentor, :program => p)
    assert_equal [group], mentor.mentoring_groups.reload
    mentor_request = create_mentor_request(:student => student, :program => p)
    assert_no_difference "Group.count" do
      post :create, xhr: true, params: { :group => {
        :mentor_name => mentor.name_with_email},
        :mentor_request_id => mentor_request.id
      }
    end

    assert_response :success
    assert assigns(:mentor_request_params)
    assert_equal mentor_request, assigns(:mentor_request)
    assert_equal [group], assigns(:existing_connections_of_mentor)
  end

  def test_create_from_request_and_assign_to_given_connection
    current_user_is :moderated_admin
    allow_one_to_many_mentoring_for_program(programs(:moderated_program))

    # Making sure that program has other requests with favorites
    request = programs(:moderated_program).mentor_requests.first
    assert request.request_favorites.any?

    users(:moderated_admin).add_role(RoleConstants::STUDENT_NAME)

    student = users(:moderated_student)
    student_1 = users(:moderated_admin)
    mentor = users(:moderated_mentor)

    group = create_group(:students => [student_1], :mentor => mentor, :program => programs(:moderated_program))
    assert_equal [group], mentor.mentoring_groups.reload
    mentor_request = create_mentor_request(:student => student, :program => programs(:moderated_program))

    assert_no_difference "Group.count" do
      put :update, xhr: true, params: { :id => group.id, :mentor_request_id => mentor_request.id, :mentor_group_id => group.id}
    end

    assert_response :success
    assert_equal mentor_request, assigns(:mentor_request)
    #Match result for the student of request is available, so there will be match hash available
    assert_equal [request], assigns(:match_results_per_mentor).keys
    group.reload
    assert_equal_unordered [student, student_1], group.students
  end

  def test_create_from_request_and_assign_to_new_connection
    current_user_is :moderated_admin
    p = programs(:moderated_program)
    make_member_of(:moderated_program, :student_3)
    allow_one_to_many_mentoring_for_program(p)

    mentor = users(:moderated_mentor)
    student = users(:student_3)
    group = create_group(:students => [student], :mentor => mentor, :program => p)
    assert_equal [group], mentor.mentoring_groups.reload
    mentor_request = mentor_requests(:moderated_request_with_favorites)
    assert_difference "Group.count" do
      post :create, xhr: true, params: { :group => {
        :mentor_name => mentor.name_with_email},
        :mentor_request_id => mentor_request.id,
        :assign_new => true
      }
    end

    assert_response :success
    assert_equal mentor_request, assigns(:mentor_request)
    group = Group.last
    assert_equal_unordered [users(:moderated_student)], group.students
    assert_equal [mentor], group.mentors
  end

  def test_create_from_request_with_empty_mentor_name
    current_user_is :moderated_admin
    mentor_request = mentor_requests(:moderated_request_with_favorites)

    assert_nothing_raised do
      assert_no_emails do
        assert_no_difference "Group.count" do
          post :create, xhr: true, params: { :group => {
            :mentor_name => ""},
            :mentor_request_id => mentor_request.id
          }
        end
      end
    end

    assert_response :success
    assert_equal mentor_request, assigns(:mentor_request)

    # Request not accepted
    assert_equal AbstractRequest::Status::NOT_ANSWERED, mentor_request.reload.status

    assert assigns(:mentor_request_params)
    assert_response :success
    assert_match "group_error_#{mentor_request.id}", @response.body
  end

  def test_create_from_request_with_empty_mentor_name_in_group_mentoring
    current_user_is :moderated_admin
    p = programs(:moderated_program)
    mentor_request = mentor_requests(:moderated_request_with_favorites)

    allow_one_to_many_mentoring_for_program(p)
    assert p.reload.allow_one_to_many_mentoring?

    assert_nothing_raised do
      assert_no_emails do
        assert_no_difference "Group.count" do
          post :create, xhr: true, params: { :group => {
            :mentor_name => ""},
            :mentor_request_id => mentor_request.id
          }
        end
      end
    end

    assert_response :success
    assert_equal mentor_request, assigns(:mentor_request)

    # Request not accepted
    assert_equal AbstractRequest::Status::NOT_ANSWERED, mentor_request.reload.status

    assert assigns(:mentor_request_params)
    assert_response :success
    assert_match "group_error_#{mentor_request.id}", @response.body
  end

  def test_create_from_request_success_in_group_mentoring
    current_user_is :moderated_admin
    p = programs(:moderated_program)
    mentor_request = mentor_requests(:moderated_request_with_favorites)

    allow_one_to_many_mentoring_for_program(p)
    assert p.reload.allow_one_to_many_mentoring?

    mentor = users(:moderated_mentor)
    assert_emails 2 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group => {
          :mentor_name => mentor.name_with_email},
          :mentor_request_id => mentor_request.id
        }
      end
    end

    group = Group.last
    assert_response :success
    assert assigns(:mentor_request_params)
    assert_equal mentor_request, assigns(:mentor_request)

    # Request accepted
    assert_equal AbstractRequest::Status::ACCEPTED, mentor_request.reload.status

    assert_equal [mentor], group.mentors
    assert_equal_unordered [users(:moderated_student)], group.students
    assert_match "results_pane", @response.body
  end

  def test_create_existing_groups_alert_not_shown
    group = groups(:mygroup)
    student = group.students.first
    mentor = group.mentors.first
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    assert_no_emails do
      assert_no_difference "Group.count" do
        post :create, xhr: true, params: { group: { mentoring_model_id: program.default_mentoring_model.id }, group_members: {
          role_id: {
            role_name_id_map[RoleConstants::STUDENT_NAME] => student.name_with_email,
            role_name_id_map[RoleConstants::MENTOR_NAME] => mentor.name_with_email
          }
        }, groups_alert_flag_shown: "false"}
      end
    end
    assert_response :success
    assert_not_nil assigns(:existing_groups_alert)
    assert_match /#{mentor.name} is a mentor to #{student.name} in .*#{h group.name}/, @response.body
  end

  def test_create_existing_groups_alert_shown
    group = groups(:mygroup)
    student = group.students.first
    mentor = group.mentors.first
    program = group.program
    role_name_id_map = get_mentoring_role_id_name_map(program)

    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is program.admin_users.first
    assert_emails 2 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { group: { mentoring_model_id: program.default_mentoring_model.id }, group_members: {
          role_id: {
            role_name_id_map[RoleConstants::STUDENT_NAME] => student.name_with_email,
            role_name_id_map[RoleConstants::MENTOR_NAME] => mentor.name_with_email
          }
        }, groups_alert_flag_shown: "true"}
      end
    end
    assert_response :success
    assert_nil assigns(:existing_groups_alert)
  end

  # In one to many supported program, add student to existing group of the
  # mentor.
  def test_update_from_request_adds_student_to_existing_group
    current_user_is :moderated_admin
    p = programs(:moderated_program)

    allow_one_to_many_mentoring_for_program(p)
    assert p.reload.allow_one_to_many_mentoring?

    mentor = users(:moderated_mentor)
    users(:moderated_admin).add_role(RoleConstants::STUDENT_NAME)
    student_1 = users(:moderated_admin)
    student_2 = users(:moderated_student)
    group = create_group(:mentor => mentor, :student => student_1, :program => p)
    mentor_request = mentor_requests(:moderated_request_with_favorites)

    assert_pending_notifications 2 do
      assert_emails do
        # No new group. Only update of existing group.
        assert_no_difference "Group.count" do
          put :update, xhr: true, params: { :id => group.id, :mentor_request_id => mentor_request.id}
        end
      end
    end

    assert_response :success
    assert_equal mentor_request, assigns(:mentor_request)

    # Request accepted
    assert_equal AbstractRequest::Status::ACCEPTED, mentor_request.reload.status

    group.reload
    assert_equal [mentor], group.mentors
    assert_equal_unordered [student_1, student_2], group.students
    assert_match "results_pane", @response.body
  end

  def test_create_from_request_failure
    current_user_is :moderated_admin
    p = programs(:moderated_program)
    assert !p.allow_one_to_many_mentoring?
    mentor = users(:no_mreq_mentor)
    mentor_request = mentor_requests(:moderated_request_with_favorites)

    # Assign a mentor from other program.
    assert_no_emails do
      assert_no_difference 'Group.count' do
        post :create, xhr: true, params: { :group => {
          :mentor_name => mentor.name_with_email},
          :mentor_request_id => mentor_request.id
        }
      end
    end

    # Request not accepted
    assert_equal AbstractRequest::Status::NOT_ANSWERED, mentor_request.reload.status
    assert assigns(:mentor_request_params)
    assert_response :success
    assert_match "#group_error_#{mentor_request.id}", @response.body
  end

  # One to many mentoring
  def test_create_success_one_to_many
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(@program)

    assert_emails 3 do
      assert_difference "RecentActivity.count" do
        assert_difference "Group.count" do
          post :create, xhr: true, params: { :group => {}, :group_members => {
            :role_id => {
              @program_roles[RoleConstants::MENTOR_NAME].first.id => users(:f_mentor_student).name_with_email,
              @program_roles[RoleConstants::STUDENT_NAME].first.id => [users(:f_student).name_with_email, users(:rahim).name_with_email].join(",")
            }
          }}
        end
      end
    end

    delivered_email = ActionMailer::Base.deliveries.last(3)
    assert_equal_unordered [users(:f_mentor_student).email,users(:f_student).email, users(:rahim).email], delivered_email.collect(&:to).flatten

    assert_equal programs(:albers), assigns(:group).program
    assert_equal [users(:f_mentor_student)], assigns(:group).mentors
    assert_equal [users(:f_student), users(:rahim)], assigns(:group).students
    assert_equal users(:f_admin), assigns(:group).actor
    assert_nil assigns(:group).mentoring_model
    assert_nil assigns(:group).mentoring_model_id
  end

  def test_create_success_with_default_mentoring_models
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(@program)
    program = programs(:albers)

    assert_emails 3 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group => {}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => users(:f_mentor_student).name_with_email,
            @program_roles[RoleConstants::STUDENT_NAME].first.id => [users(:f_student).name_with_email, users(:rahim).name_with_email].join(","),
          }
        }}
      end
    end

    delivered_email = ActionMailer::Base.deliveries.last(3)
    assert_equal_unordered [users(:f_mentor_student).email,users(:f_student).email, users(:rahim).email], delivered_email.collect(&:to).flatten

    assert_equal programs(:albers), assigns(:group).program
    assert_equal [users(:f_mentor_student)], assigns(:group).mentors
    assert_equal [users(:f_student), users(:rahim)], assigns(:group).students
    assert_equal users(:f_admin), assigns(:group).actor
    assert_equal program.default_mentoring_model, assigns(:group).mentoring_model
  end

  def test_create_success_with_custom_mentoring_models
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(@program)
    program = programs(:albers)
    new_mentoring_model = create_mentoring_model

    assert_emails 3 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :group => {:mentoring_model_id => new_mentoring_model.id}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => users(:f_mentor_student).name_with_email,
            @program_roles[RoleConstants::STUDENT_NAME].first.id => [users(:f_student).name_with_email, users(:rahim).name_with_email].join(",")
          }
        }}
      end
    end

    delivered_email = ActionMailer::Base.deliveries.last(3)
    assert_equal_unordered [users(:f_mentor_student).email,users(:f_student).email, users(:rahim).email], delivered_email.collect(&:to).flatten

    assert_equal programs(:albers), assigns(:group).program
    assert_equal [users(:f_mentor_student)], assigns(:group).mentors
    assert_equal [users(:f_student), users(:rahim)], assigns(:group).students
    assert_equal users(:f_admin), assigns(:group).actor
    assert_equal new_mentoring_model, assigns(:group).mentoring_model
  end

  def test_create_success_one_to_many_repeated_entry_of_users
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(@program)

    assert_emails 2 do
      assert_difference "RecentActivity.count" do
        assert_difference "Group.count" do
          post :create, xhr: true, params: { :group => {}, :group_members => {
            role_id: {
              @program_roles[RoleConstants::MENTOR_NAME].first.id => users(:f_mentor_student).name_with_email,
              @program_roles[RoleConstants::STUDENT_NAME].first.id => [users(:f_student).name_with_email, users(:f_student).name_with_email].join(",")
            }
          }}
        end
      end
    end

    delivered_email = ActionMailer::Base.deliveries.last(2)
    assert_equal [users(:f_student).email], delivered_email[0].to
    assert_equal [users(:f_mentor_student).email], delivered_email[1].to

    assert_equal programs(:albers), assigns(:group).program
    assert_equal [users(:f_mentor_student)], assigns(:group).mentors
    assert_equal [users(:f_student)], assigns(:group).students
    assert_equal users(:f_admin), assigns(:group).actor
  end

  def test_create_failure_with_mentor_already_having_group_one_to_many
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(@program)

    assert_emails 0 do
      assert_no_difference "Group.count" do
        post :create, xhr: true, params: { :group => {}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => @mentor.name_with_email,
            @program_roles[RoleConstants::STUDENT_NAME].first.id => users(:rahim).name_with_email
          }
        }}
      end
    end
    assert_response :success
  end

  def test_create_one_to_one_draft_success
    group_setup
    current_user_is :f_admin
    @mentor.update_attribute(:max_connections_limit, 3)

    assert_emails 0 do
      assert_difference "Group.count" do
        post :create, xhr: true, params: { :draft => true, :group => {}, :group_members => {
          role_id: {
            @program_roles[RoleConstants::MENTOR_NAME].first.id => @mentor.name_with_email,
            @program_roles[RoleConstants::STUDENT_NAME].first.id => users(:rahim).name_with_email
          }
        }}
      end
    end

    assert !assigns(:mentor_request_params)

    assert_equal @program, assigns(:group).program
    assert_equal [@mentor], assigns(:group).mentors
    assert_equal [users(:rahim)], assigns(:group).students
    assert assigns(:group).drafted?
    assert_match "groups_listing", @response.body
    assert assigns(:is_manage_connections_view)
  end

  def test_create_one_to_many_draft_success
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert_emails 0 do
      assert_no_difference "RecentActivity.count" do
        assert_difference "Group.count" do
          post :create, xhr: true, params: { draft: true, group: {}, :group_members => {
            role_id: {
              @program_roles[RoleConstants::MENTOR_NAME].first.id => users(:f_mentor_student).name_with_email,
              @program_roles[RoleConstants::STUDENT_NAME].first.id => [users(:f_student).name_with_email, users(:rahim).name_with_email].join(",")
            }
          }}
        end
      end
    end

    assert_equal programs(:albers), assigns(:group).program
    assert_equal [users(:f_mentor_student)], assigns(:group).mentors
    assert_equal [users(:f_student), users(:rahim)], assigns(:group).students
    assert_equal users(:f_admin), assigns(:group).actor
    assert assigns(:group).drafted?
  end

  #================================================================================

  def test_fetch_non_existing_group
    mentor = users(:f_mentor)
    current_user_is mentor
    term = mentor.program.customized_terms.find_by(term_type: CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    term.update_attributes!(:term_downcase => "connection")
    non_existent_group_id = 123
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    assert_nothing_raised do
      get :show, params: { :id => non_existent_group_id}
    end
    assert_redirected_to program_root_path
    assert_equal "The connection you are looking for does not exist.", flash[:error]
  end

  def test_fetch_publish_non_admin
    current_user_is :f_mentor
    assert_permission_denied  do
      get :fetch_publish, params: { :id => groups(:drafted_group_1).id}
    end
  end

  def test_fetch_publish_non_admin_owner
    current_user_is :pbe_student_0
    student_user = users(:pbe_student_0)
    groups(:group_pbe_0).membership_of(student_user).update_attributes!(owner: true)

    assert student_user.can_manage_or_own_group?(groups(:group_pbe_0))
    assert_false student_user.can_manage_connections?

    get :fetch_publish, params: { :id => groups(:group_pbe_0).id}
    assert_equal groups(:group_pbe_0), assigns(:group)
  end

  def test_fetch_publish_admin
    current_user_is :f_admin
    get :fetch_publish, params: { :id => groups(:drafted_group_1).id}
    assert_match /#{GroupCreationNotificationToMentor.mailer_attributes[:uid]}/, @response.body
    assert_match /#{GroupCreationNotificationToStudents.mailer_attributes[:uid]}/, @response.body
    assert_equal groups(:drafted_group_1), assigns(:group)
  end

  def test_fetch_discard_non_admin
    current_user_is :f_mentor
    assert_permission_denied  do
      get :fetch_discard, params: { :id => groups(:drafted_group_1).id}
    end
  end

  def test_fetch_discard_admin
    current_user_is :f_admin
    get :fetch_discard, params: { :id => groups(:drafted_group_1).id}
    assert_equal groups(:drafted_group_1), assigns(:group)
  end

  def test_publish_drafted_connection_only_by_admin
    current_user_is :f_mentor
    assert_permission_denied  do
      put :publish, xhr: true, params: { :id => groups(:drafted_group_1).id}
    end
  end

  def test_publish_pending_connection_by_owner
    current_user_is :pbe_student_0
    student_user = users(:pbe_student_0)
    groups(:group_pbe_0).membership_of(student_user).update_attributes!(owner: true)

    assert student_user.can_manage_or_own_group?(groups(:group_pbe_0))
    assert_false student_user.can_manage_connections?
    assert groups(:group_pbe_0).pending?

    put :publish, params: { :id => groups(:group_pbe_0).id, group: {message: "Test notes", membership_settings: {allow_join: "true"}}, :src => EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET }

    assert assigns(:group).active_project_requests.present?
    assert_equal groups(:group_pbe_0), assigns(:group)
    organization = programs(:pbe).organization
    assert_redirected_to Rails.application.routes.url_helpers.project_requests_url(host: organization.domain, subdomain: organization.subdomain, root: programs(:pbe).root, filtered_group_ids: [groups(:group_pbe_0).id], from_bulk_publish: false, track_publish_ga: true, ga_src: assigns(:ga_src), src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET)
    assert_equal "flash_message.group_flash.draft_actions".translate(mentoring_connection: _mentoring_connection, action: "display_string.published".translate), flash[:notice]
  end

  def test_publish_drafted_connection_success
    g1 = groups(:drafted_group_1)
    org = programs(:org_primary)
    current_user_is :f_admin
    assert g1.drafted?
    assert_emails 2 do
      assert_no_difference "Group.count" do
        put :publish, xhr: true, params: { :id => g1.id, group: {message: "Test notes", membership_settings: {allow_join: "true"}}}
      end
    end
    assert_response :success
    assert g1.reload.active?
    assert_equal "Test notes", assigns(:group).message
    assert_false g1.reload.drafted?
  end


  def test_discard_drafted_connection_only_by_admin
    current_user_is :f_mentor
    assert_no_difference "Group.count" do
      assert_permission_denied  do
        put :discard, xhr: true, params: { :id => groups(:drafted_group_1).id}
      end
    end
  end

  def test_discard_drafted_connection_success
    g1 = groups(:drafted_group_1)
    org = programs(:org_primary)
    current_user_is :f_admin
    assert g1.drafted?
    assert_emails 0 do
      assert_difference "Group.count", -1 do
        put :discard, xhr: true, params: { :id => g1.id}
      end
    end
    assert_response :success
  end

  def test_individual_action_should_not_contain_add_remove_member_for_one_on_mentoring_connection
    current_user_is :f_admin
    current_program_is :albers
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, false)
    get :index, params: { :tab => Group::Status::ACTIVE, :view => Group::View::DETAILED}
    assert_select "div#group_elements ul.dropdown-menu a" do |links|
      links.each {|link| assert_select link, "Add Remove Members", count: 0}
    end
  end

  def test_drafted_connection_add_remove_member_update_success
    group = groups(:drafted_group_1)
    current_user_is :f_admin
    program = programs(:albers)
    program_roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).group_by(&:name)
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    assert_false group.has_member?(users(:mentor_5))
    assert group.has_member?(users(:robert))
    assert_equal 2, group.members.count
    assert_equal 1, group.mentors.count
    assert_equal 1, group.students.count

    assert_no_difference('RecentActivity.count') do
      assert_emails 0 do
        post :update, xhr: true, params: {
          :id => group.id,
          :connection => {
            :users => {
              users(:mentor_5).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:robert).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:robert).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
              group.students.first.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          }, tab: Group::Status::DRAFTED}
      end
    end

    assert_response :success
    group.reload
    assert group.has_member?(users(:mentor_5))
    assert_false group.has_member?(users(:robert))
    assert group.has_member?(users(:student_4))
    assert_equal [users(:mentor_5)], group.mentors
    assert_equal [users(:student_4)], group.students
  end

  def test_drafted_groups_filtering_with_mentor_name
    current_user_is :f_admin
    org = programs(:org_primary)
    org.enable_feature(FeatureName::CONNECTION_PROFILE , true)
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    get :index, xhr: true, params: {
      :member_filters => { "#{mentor_role.id}" => users(:mentor_1).name},
      :tab => Group::Status::DRAFTED}
    # Sort order is "last_member_activity_at" and both the groups have null as value for the field.
    # Since we are testing if drafted groups alone are being returned, we ignore testing the sort order since it is not problematic.
    assert_equal_unordered [groups(:drafted_group_2), groups(:drafted_group_3)].collect(&:id), assigns(:groups).collect(&:id)
  end

  def test_groups_filtering_with_mentor_name
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE , true)
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)

    current_user_is :f_admin
    get :index, xhr: true, params: { :member_filters => { "#{mentor_role.id}" => users(:not_requestable_mentor).name}}
    assert_equal [groups(:group_3), groups(:group_2)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
  end

  def test_groups_filtering_with_name_with_email
    current_user_is :f_admin
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    get :index, xhr: true, params: { :member_filters => { "#{mentor_role.id}" => "Non requestable mentor <non_request@example.com>"}}
    assert_equal [groups(:group_3), groups(:group_2)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
  end

  def test_groups_filtering_with_mentee_name
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE , true)
    mentee_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    current_user_is :f_admin
    get :index, xhr: true, params: { :member_filters => { "#{mentee_role.id}" => users(:mkr_student).name}}
    assert_equal [groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*Student/, response.body
  end

  def test_groups_filtering_with_profile_name
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE , true)

    get :index, xhr: true, params: { :show => "global", :search_filters => {:milestone_status => "", :profile_name => "mentor"}}
    assert_equal [groups(:group_2)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'active', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*Mentoring Connection Name/, response.body
  end

  def test_groups_filtering_with_v2_task_status_true
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :index, xhr: true, params: { :search_filters => {:milestone_status => "", :profile_name => "", :v2_tasks_status => GroupsController::TaskStatusFilter::OVERDUE}}
    assert assigns(:my_filters).present?
    assert assigns(:v2_tasks_overdue_filter)
    assert_equal "Task Status", assigns(:my_filters).first[:label]
    assert_equal "v2_tasks_status", assigns(:my_filters).first[:reset_suffix]
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*#{"Task Status".truncate(30)}/, response.body
    assert_equal true, assigns(:es_filter_hash)[:must_filters][:has_overdue_tasks]
  end

  def test_groups_filtering_with_v2_task_status_false
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :index, xhr: true, params: { :search_filters => {:milestone_status => "", :profile_name => "", :v2_tasks_status => GroupsController::TaskStatusFilter::NOT_OVERDUE}}
    assert assigns(:my_filters).present?
    assert assigns(:v2_tasks_overdue_filter)
    assert_equal "Task Status", assigns(:my_filters).first[:label]
    assert_equal "v2_tasks_status", assigns(:my_filters).first[:reset_suffix]
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*#{"Task Status".truncate(30)}/, response.body
    assert_equal false, assigns(:es_filter_hash)[:must_filters][:has_overdue_tasks]
  end

  def test_groups_filtering_with_expiry_date
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE , true)

    start_date = 2.days.from_now.utc

    g1 = groups(:group_2)
    g2 = groups(:mygroup)
    start_date_input = start_date.strftime("%m/%d/%Y")
    members(:f_admin).update_attribute(:time_zone, "Asia/Kolkata")
    get :index, xhr: true, params: { :show => "global", :search_filters => {:milestone_status => "", :profile_name => "", :expiry_date =>  start_date_input}, :src => "mail"}
    assert_equal [g1].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal programs(:albers).groups.active.select(&:expiring_next_week?).size, 1
    assert_equal 'active', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert_equal '+05:30', assigns(:expiry_start_time).zone
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*Closes on/, response.body
  end

  def test_groups_filtering_with_closed_date
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE , true)
    g1 = groups(:group_4)

    start_date = (5.days.ago).to_time
    end_date = (10.days.from_now).to_time

    date_input = start_date.strftime("%m/%d/%Y") + " - " + end_date.strftime("%m/%d/%Y")
    members(:f_admin).update_attribute(:time_zone, "Asia/Tokyo")
    get :index, xhr: true, params: { :tab => Group::Status::CLOSED, :search_filters => {:milestone_status => "", :profile_name => "", :closed_date =>  date_input}}
    assert_equal [g1].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert_equal '+09:00', assigns(:closed_start_time).zone
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*Closed on/, response.body

    start_date = (5.days.from_now).to_time
    date_input = start_date.strftime("%m/%d/%Y") + " - " + end_date.strftime("%m/%d/%Y")
    get :index, xhr: true, params: { :tab => Group::Status::CLOSED, :search_filters => {:milestone_status => "", :profile_name => "", :closed_date =>  date_input}}
    assert_equal [].collect(&:id), assigns(:groups).collect(&:id)

  end

  def test_groups_filtering_with_started_date
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE , true)

    start_date = (5.days.ago).to_time
    end_date = (10.days.from_now).to_time
    # Filter based on start date for active groups.
    expected_groups = [groups(:mygroup),groups(:group_2),groups(:group_3),groups(:group_5),groups(:group_inactive)]
    date_input = start_date.strftime("%m/%d/%Y") + " - " + end_date.strftime("%m/%d/%Y")

    members(:f_admin).update_attribute(:time_zone, "Asia/Kolkata")
    get :index, xhr: true, params: { :search_filters => {:milestone_status => "", :profile_name => "", :started_date =>  date_input}}
    assert_equal_unordered expected_groups.collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert_equal '+05:30', assigns(:started_start_time).zone
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*Started on/, response.body
  end

  def test_groups_index_with_filter_but_inactive
    current_user_is :f_admin
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    get :index, xhr: true, params: { :sub_filter => {"inactive" => GroupsController::StatusFilters::Code::INACTIVE},
      :member_filters => { "#{mentor_role.id}" => users(:mentor_1).name}}

    assert_equal [groups(:group_inactive)].select{|grp| grp.connection_activities.size > 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_false assigns(:not_started_filter)
    assert_equal 'desc', assigns(:sort_order)
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /div.*class=\\\"panel-body p-t-0 item/, response.body
    assert_match /span.*class=\\\"text.*Status/, response.body
  end

  def test_status_filters_inactive
    current_user_is :f_admin
    program = programs(:albers)
    get :index, xhr: true, params: { :sub_filter => {"inactive" => GroupsController::StatusFilters::Code::INACTIVE}}
    assert_equal_unordered [groups(:group_inactive)].select{|grp| grp.connection_activities.size > 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert_false assigns(:not_started_filter)
  end

  def test_status_filters_active
    current_user_is :f_admin
    program = programs(:albers)
    get :index, xhr: true, params: { :sub_filter => {"active" => GroupsController::StatusFilters::Code::ACTIVE}}
    assert_equal_unordered program.groups.where(:status => Group::Status::ACTIVE).select{|grp| grp.connection_activities.size > 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert_false assigns(:not_started_filter)
  end

  def test_status_filters_active_with_abstract_view_V2
    current_user_is :f_admin
    current_program_is :pbe
    program = programs(:pbe)
    view = program.abstract_views.where(default_view: [AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS]).first
    assert_not_nil view
    get :index, params: { abstract_view_id: view.id}
    assert_equal view, assigns(:_abstract_view)
    assert_equal_unordered program.groups.where(:status => Group::Status::ACTIVE).select{|grp| grp.connection_activities.size > 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert_false assigns(:not_started_filter)
    assert assigns(:my_filters).present?
    assert assigns(:v2_tasks_overdue_filter)
    assert_equal "Task Status", assigns(:my_filters)[1][:label]
    assert_equal "v2_tasks_status", assigns(:my_filters)[1][:reset_suffix]
    assert_select "#your_filters" do
      assert_select "div.item" do
        assert_select "span span.text", :text => "Task Status".truncate(30)
      end
    end
    assert_equal true, assigns(:es_filter_hash)[:must_filters][:has_overdue_tasks]
  end

  def test_slots_availability_filter
    current_user_is :f_admin
    current_program_is :pbe
    program = programs(:pbe)
    get :index, params: {"from"=>"filters", "page"=>"1", "src"=>"", "tab"=>"4", "view"=>"1", "filters_applied"=>"true", "search_filters"=>{"profile_name"=>"", "slots_available"=>["mentor", "student"]}, "sort"=>"membership_setting_slots_remaining.mentor", "order"=>"asc", "root"=>"pbe"}
    assert assigns(:es_filter_hash)[:should_filters][0]["membership_setting_slots_remaining.mentor"]
    assert_equal [{:label=>"Slots Available For Any Of", :reset_suffix=>:slots_available}], assigns(:my_filters)
  end

  def test_slots_unavailability_filter
    current_user_is :f_admin
    current_program_is :pbe
    program = programs(:pbe)
    get :index, params: {"from"=>"filters", "page"=>"1", "src"=>"", "tab"=>"4", "view"=>"1", "filters_applied"=>"true", "search_filters"=>{"profile_name"=>"", "slots_unavailable"=>["mentor", "student"]}, "sort"=>"membership_setting_slots_remaining.mentor", "order"=>"asc", "root"=>"pbe"}
    assert assigns(:es_filter_hash)[:should_filters][0]["membership_setting_slots_remaining.mentor"]
    assert_equal [{:label=>"Slots Unavailable For Any Of", :reset_suffix=>:slots_unavailable}], assigns(:my_filters)
  end

  def test_slots_both_avaiablity_and_unavailability_filter
    current_user_is :f_admin
    current_program_is :pbe
    program = programs(:pbe)
    get :index, params: {"from"=>"filters", "page"=>"1", "src"=>"", "tab"=>"4", "view"=>"1", "filters_applied"=>"true", "search_filters"=>{"profile_name"=>"", "slots_available"=>["student"], "slots_unavailable"=>["mentor"]}, "sort"=>"membership_setting_slots_remaining.mentor", "order"=>"asc", "root"=>"pbe"}
    assert assigns(:es_filter_hash)[:should_filters][0]["membership_setting_slots_remaining.student"]
    assert assigns(:es_filter_hash)[:should_filters][1]["membership_setting_slots_remaining.mentor"]
    assert_equal [{:label=>"Slots Available For Any Of", :reset_suffix=>:slots_available}, {:label=>"Slots Unavailable For Any Of", :reset_suffix=>:slots_unavailable}], assigns(:my_filters)
  end

  def test_status_filters_active_inactive
    current_user_is :f_admin
    program = programs(:albers)
    get :index, xhr: true, params: { :sub_filter => {"active" => GroupsController::StatusFilters::Code::ACTIVE, "inactive" => GroupsController::StatusFilters::Code::INACTIVE}}
    assert_equal_unordered program.groups.active.select{|grp| grp.connection_activities.size > 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert_false assigns(:not_started_filter)
    end

  def test_status_filters_active_inactive_from_abstratc_view_V2
    current_user_is :f_admin
    current_program_is :pbe
    program = programs(:pbe)
    view = program.abstract_views.where(default_view: [AbstractView::DefaultType::INACTIVE_CONNECTIONS]).first
    assert_not_nil view
    get :index, params: { abstract_view_id: view.id}
    assert_equal view, assigns(:_abstract_view)
    assert_equal_unordered program.groups.active.select{|grp| grp.connection_activities.size > 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert_false assigns(:not_started_filter)
  end

  def test_status_filters_not_started
    current_user_is :f_admin
    program = programs(:albers)
    get :index, xhr: true, params: { :sub_filter => {"not_started" => GroupsController::StatusFilters::NOT_STARTED}}
    assert_equal_unordered program.groups.active.select{|grp| grp.connection_activities.size == 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert assigns(:not_started_filter)
  end

  def test_status_filters_not_started_from_abstract_view_V2
    current_user_is :f_admin
    program = programs(:pbe)
    current_program_is :pbe
    view = program.abstract_views.where(default_view: [AbstractView::DefaultType::CONNECTIONS_NEVER_GOT_GOING]).first
    assert_not_nil view
    get :index, params: { abstract_view_id: view.id}
    assert_equal view, assigns(:_abstract_view)
    assert_equal_unordered program.groups.active.select{|grp| grp.connection_activities.size == 0}.collect(&:id), assigns(:groups).collect(&:id)
    assert assigns(:not_started_filter)
  end

  def test_status_filters_active_inactive_not_started
    current_user_is :f_admin
    program = programs(:albers)
    grps = (program.groups.active.select{|grp| grp.connection_activities.size > 0} + program.groups.active.select{|grp| grp.connection_activities.size == 0})
    get :index, xhr: true, params: { :sub_filter => {"active" => GroupsController::StatusFilters::Code::ACTIVE, "inactive" => GroupsController::StatusFilters::Code::INACTIVE, "not_started" => GroupsController::StatusFilters::NOT_STARTED}}
    assert_equal_unordered grps.collect(&:id), assigns(:groups).collect(&:id)
    assert assigns(:not_started_filter)
    end

  def test_status_filters_none
    current_user_is :f_admin
    program = programs(:albers)
    grps = (program.groups.active.select{|grp| grp.connection_activities.size > 0} + program.groups.active.select{|grp| grp.connection_activities.size == 0})
    get :index, xhr: true
    assert_equal_unordered grps.collect(&:id), assigns(:groups).collect(&:id)
    assert assigns(:not_started_filter)
  end

  def test_groups_filtering_with_both_names
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    mentee_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    current_user_is :f_admin
    get :index, xhr: true, params: { :member_filters => { "#{mentor_role.id}" => users(:f_mentor).name, "#{mentee_role.id}" => users(:mkr_student).name}}
    assert_equal_unordered [groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)
    assert_equal 'connected_time', assigns(:sort_field)
    assert_equal 'desc', assigns(:sort_order)
    assert assigns(:my_filters).present?
    assert_match /div id=\\\"your_filters/, response.body
    assert_match /span.*class=\\\"text.*Mentor/, response.body
    assert_match /span.*class=\\\"text.*Student/, response.body
  end

  def test_groups_filtering_with_blank_names
    current_user_is :f_admin
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    mentee_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)
    get :index, xhr: true, params: { :member_filters => { "#{mentor_role.id}" => "", "#{mentee_role.id}" => ""}}
    assert_equal_unordered [groups(:group_5), groups(:group_inactive), groups(:old_group), groups(:group_3), groups(:group_2), groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)
  end

  def test_should_not_initialize_my_filters_for_get_requests
    current_user_is :f_admin

    get :index
    assert_response :success

    assert_false assigns(:my_filters).present?
  end

  def test_groups_filtering_with_invalid_names
    current_user_is :f_admin
    mentor_role = programs(:albers).get_role(RoleConstants::MENTOR_NAME)
    mentee_role = programs(:albers).get_role(RoleConstants::STUDENT_NAME)

    # testing with random names
    get :index, xhr: true, params: { :member_filters => { "#{mentor_role.id}" => "bbbb", "#{mentee_role.id}" => "aaaa"}}
    assert assigns(:groups).empty?
  end

  def test_export_mentoring_area
    group = groups(:mygroup)

    current_user_is group.members.first
    request.env["HTTP_REFERER"] = '/'
    assert_emails 1 do
      get :export, params: { id: group.id, export: "true", format: :html}
    end
    assert_equal group, assigns(:group)
    assert_equal "This mentoring connection is being exported. You will receive an email shortly with the exported information.", flash[:notice]
  end

  def test_export_mentoring_area_for_admin
    group = groups(:mygroup)
    Group.any_instance.stubs(:forum_enabled?).returns(true)

    current_user_is :f_admin
    request.env["HTTP_REFERER"] = '/'
    assert_emails 1 do
      get :export, params: { id: group.id, export: "true", format: :html}
    end
    assert_equal group, assigns(:group)
    assert_equal "This mentoring connection is being exported. You will receive an email shortly with the exported information. Please note that the discussion board information will not be exported.", flash[:notice]
  end

  def test_assign_from_match_permissions
    current_user_is :f_mentor

    assert_permission_denied do
      post :assign_from_match
    end
  end

  def test_assign_from_match_new_connection
    current_user_is :f_admin
    mentor = users(:f_mentor)
    student = users(:f_student)

    assert_emails 2 do
      assert_difference "Group.count" do
        assert_difference "Connection::Membership.count", 2 do
          post :assign_from_match, params: { :student_id => student.id, :mentor_id => mentor.id, :group_id => "", :message => "Hi"}
        end
      end
    end

    group = assigns(:group)
    assert_equal "Hi", group.message
    assert_equal [mentor], group.mentors
    assert_equal [student], group.students
    assert_nil group.assigned_from_match
    assert_redirected_to matches_for_student_users_path
    assert_equal "<b>#{student.name}</b> has been assigned to the mentoring connection", flash[:notice]

    delivered_email = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered [mentor.email, student.email], delivered_email.collect(&:to).flatten
  end

  def test_assign_from_match_existing_connection
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    mentor = users(:f_mentor)
    student = users(:f_student)
    group = groups(:mygroup)

    assert_emails 1 do
      assert_no_difference "Group.count" do
        assert_difference "Connection::Membership.count", 1 do
          post :assign_from_match, params: { :student_id => student.id, :mentor_id => mentor.id, :group_id => group.id, :message => "Please connect."}
        end
      end
    end

    group = assigns(:group)
    assert_equal [mentor], group.mentors
    assert_equal [users(:mkr_student), student], group.students
    assert group.assigned_from_match
    assert_redirected_to matches_for_student_users_path
    assert_equal "<b>#{student.name}</b> has been assigned to the mentoring connection", flash[:notice]

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal [student.email], delivered_email.to
    assert_equal "You have been added as a student to name & madankumarrajan", delivered_email.subject
    assert_match /Your mentoring connection will end on #{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}/, get_text_part_from(delivered_email)
  end

  def test_assign_from_match_save_as_draft
    current_user_is :f_admin
    mentor = users(:f_mentor)
    student = users(:f_student)
    assert_difference "Group.count" do
      assert_difference "Connection::Membership.count", 2 do
        post :assign_from_match, params: { :student_id => student.id, :mentor_id => mentor.id, :group_id => "", :notes => "Hi", :group_status => "draft"}
      end
    end
    group = assigns(:group)
    assert_equal "Hi", group.notes
    assert_equal [mentor], group.mentors
    assert_equal [student], group.students
    assert_nil group.assigned_from_match
    assert_redirected_to matches_for_student_users_path
    assert_equal "The mentoring connection has been saved as a draft. <a href=\"/p/albers/groups?tab=3\">Click here</a> to view the draft.", flash[:notice]
  end

  def test_update_add_mentor_success
    programs(:albers).enable_feature(FeatureName::CONNECTION_PROFILE, true)
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    assert_false @group.has_member?(users(:mentor_3))
    program = programs(:albers)
    program_roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).group_by(&:name)
    assert_difference('RecentActivity.count') do
      assert_pending_notifications 2 do
        assert_emails 1 do
          post :update, xhr: true, params: {
            :id => @group.id,
            :connection => {
              :users => {
                users(:mentor_3).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_3).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
              }
            }
          }
        end
      end
    end

    email = ActionMailer::Base.deliveries[-1]
    assert_equal users(:mentor_3).email, email.to[0]
    assert_match(/You have been added as a mentor to name & example/, email.subject)

    notif_1 = PendingNotification.all[-2]
    assert_equal @user, notif_1.ref_obj_creator.user
    assert_equal notif_1.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    notif_2 = PendingNotification.all[-1]
    assert_equal @mentor, notif_2.ref_obj_creator.user
    assert_equal notif_2.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    assert_response :success
    @group.reload
    assert @group.has_member?(users(:mentor_3))
    assert_equal [@mentor, users(:mentor_3)], @group.mentors
    assert_equal [@user], @group.students
    assert_nil assigns(:connection_questions)
  end

  def test_update_replace_mentor_success
    programs(:albers).enable_feature(FeatureName::CONNECTION_PROFILE, true)
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    program = programs(:albers)
    program_roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).group_by(&:name)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    mentor_membership = @group.mentor_memberships.first
    user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [mentor_membership].collect(&:id))
    user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end
    task = user_tasks.first
    task.update_attribute(:status, MentoringModel::Task::Status::DONE)

    assert_difference('RecentActivity.count', 2) do
      assert_pending_notifications 1 do
        assert_emails 2 do
          post :update, xhr: true, params: {
            :id => @group.id,
            :connection => {
              :users => {
                @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@mentor.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:mentor_3).id.to_s}}
              }
            }
          }
        end
      end
    end

    email = ActionMailer::Base.deliveries[-1]
    assert_equal @mentor.email, email.to[0]
    assert_match(/You have been removed from name & example by the program administrator/, email.subject)

    email = ActionMailer::Base.deliveries[-2]
    assert_equal users(:mentor_3).email, email.to[0]
    assert_match(/You have been added as a mentor to name & example/, email.subject)

    notif_1 = PendingNotification.all[-1]
    assert_equal @user, notif_1.ref_obj_creator.user
    assert_equal notif_1.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    assert_response :success
    @group.reload

    completed_tasks_ids = [user_tasks.first.id]
    pending_tasks_ids = user_tasks.collect(&:id) - completed_tasks_ids
    assert user_tasks.reload.blank?

    completed_tasks = @group.mentoring_model_tasks.where(:id => completed_tasks_ids)

    completed_tasks.each do |task|
      assert_false task.reload.connection_membership_id?
      assert task.from_template?
      assert task.unassigned_from_template?
    end

    new_mentor_membership = @group.mentor_memberships.first
    pending_tasks = @group.mentoring_model_tasks.where(:id => pending_tasks_ids)
    pending_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
      assert_equal new_mentor_membership.id, task.connection_membership_id
    end

    assert @group.has_member?(users(:mentor_3))
    assert_equal [users(:mentor_3)], @group.mentors
    assert_equal [@user], @group.students
    assert_nil assigns(:connection_questions)
  end

  def test_update_add_mentee_success
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert programs(:albers).reload.allow_one_to_many_mentoring?
    assert_false @group.has_member?(users(:student_3))
    @mentor.update_attribute(:max_connections_limit, 5)
    assert_equal 5, @mentor.reload.max_connections_limit
    program = programs(:albers)
    program_roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).group_by(&:name)
    assert_difference('RecentActivity.count') do
      assert_emails 1 do
        assert_pending_notifications 2 do
          post :update, xhr: true, params: {
            :id => @group.id,
            :connection => {
              :users => {
                users(:student_3).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_3).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
              }
            }
          }
        end
      end
    end

    email = ActionMailer::Base.deliveries[-1]
    assert_equal users(:student_3).email, email.to[0]
    assert_match(/You have been added as a student to name & example/, email.subject)

    notif_1 = PendingNotification.all[-2]
    assert_equal @user, notif_1.ref_obj_creator.user
    assert_equal notif_1.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    notif_2 = PendingNotification.all[-1]
    assert_equal @mentor, notif_2.ref_obj_creator.user
    assert_equal notif_2.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    assert_response :success
    @group.reload
    assert @group.has_member?(users(:student_3))
    assert_equal [@mentor], @group.mentors
    assert_equal [@user, users(:student_3)], @group.students

    assert assigns(:is_manage_connections_view)
  end

  def test_update_replace_mentee_success
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    @mentor.update_attribute(:max_connections_limit, 5)
    program = programs(:albers)
    program_roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).group_by(&:name)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    student_membership = @group.student_memberships.first
    user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [student_membership].collect(&:id))
    user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end
    task = user_tasks.first
    task.update_attribute(:status, MentoringModel::Task::Status::DONE)

    assert_difference('RecentActivity.count', 2) do
      assert_emails 2 do
        assert_pending_notifications 1 do
          post :update, xhr: true, params: {
            :id => @group.id,
            :connection => {
              :users => {
                @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@user.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:student_3).id.to_s}}
              }
            }
          }
        end
      end
    end


    email = ActionMailer::Base.deliveries[-1]
    assert_equal @user.email, email.to[0]
    assert_match(/You have been removed from name & example by the program administrator/, email.subject)

    email = ActionMailer::Base.deliveries[-2]
    assert_equal users(:student_3).email, email.to[0]
    assert_match(/You have been added as a student to name & example/, email.subject)

    notif_2 = PendingNotification.all[-1]
    assert_equal @mentor, notif_2.ref_obj_creator.user
    assert_equal notif_2.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    assert_response :success
    @group.reload

    completed_tasks_ids = [user_tasks.first.id]
    pending_tasks_ids = user_tasks.collect(&:id) - completed_tasks_ids
    assert user_tasks.reload.blank?

    completed_tasks = @group.mentoring_model_tasks.where(:id => completed_tasks_ids)

    completed_tasks.each do |task|
      assert_false task.reload.connection_membership_id?
      assert task.from_template?
      assert task.unassigned_from_template?
    end

    new_student_membership = @group.student_memberships.first
    pending_tasks = @group.mentoring_model_tasks.where(:id => pending_tasks_ids)
    pending_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
      assert_equal new_student_membership.id, task.connection_membership_id
    end

    assert @group.has_member?(users(:student_3))
    assert_equal [@mentor], @group.mentors
    assert_equal [users(:student_3)], @group.students

    assert assigns(:is_manage_connections_view)
  end


  def test_update_replace_mentor_and_mentee_success
    group_setup
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    @mentor.update_attribute(:max_connections_limit, 5)
    program = programs(:albers)
    program_roles = program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).group_by(&:name)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    student_membership = @group.student_memberships.first
    student_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [student_membership].collect(&:id))
    student_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end
    task = student_tasks.first
    task.update_attribute(:status, MentoringModel::Task::Status::DONE)

    mentor_membership = @group.mentor_memberships.first
    mentor_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [mentor_membership].collect(&:id))
    mentor_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end
    task = mentor_tasks.first
    task.update_attribute(:status, MentoringModel::Task::Status::DONE)

    assert_difference('RecentActivity.count', 4) do
      assert_emails 4 do
        assert_pending_notifications 0 do
          post :update, xhr: true, params: {
            :id => @group.id,
            :connection => {
              :users => {
                @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@mentor.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:mentor_3).id.to_s}},
                @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@user.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:student_3).id.to_s}}
              }
            }
          }
        end
      end
    end

    email = ActionMailer::Base.deliveries[-1]
    assert_equal @user.email, email.to[0]
    assert_match(/You have been removed from name & example by the program administrator/, email.subject)

    email = ActionMailer::Base.deliveries[-2]
    assert_equal @mentor.email, email.to[0]
    assert_match(/You have been removed from name & example by the program administrator/, email.subject)

    email = ActionMailer::Base.deliveries[-3]
    assert_equal users(:student_3).email, email.to[0]
    assert_match(/You have been added as a student to name & example/, email.subject)

    email = ActionMailer::Base.deliveries[-4]
    assert_equal users(:mentor_3).email, email.to[0]
    assert_match(/You have been added as a mentor to name & example/, email.subject)

    assert_response :success
    @group.reload

    completed_tasks_ids = [mentor_tasks.first.id]
    pending_tasks_ids = mentor_tasks.collect(&:id) - completed_tasks_ids
    assert mentor_tasks.reload.blank?

    completed_tasks = @group.mentoring_model_tasks.where(:id => completed_tasks_ids)

    completed_tasks.each do |task|
      assert_false task.reload.connection_membership_id?
      assert task.from_template?
      assert task.unassigned_from_template?
    end

    new_mentor_membership = @group.mentor_memberships.first
    pending_tasks = @group.mentoring_model_tasks.where(:id => pending_tasks_ids)
    pending_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
      assert_equal new_mentor_membership.id, task.connection_membership_id
    end

    completed_tasks_ids = [student_tasks.first.id]
    pending_tasks_ids = student_tasks.collect(&:id) - completed_tasks_ids
    assert student_tasks.reload.blank?

    completed_tasks = @group.mentoring_model_tasks.where(:id => completed_tasks_ids)

    completed_tasks.each do |task|
      assert_false task.reload.connection_membership_id?
      assert task.from_template?
      assert task.unassigned_from_template?
    end

    new_student_membership = @group.student_memberships.first
    pending_tasks = @group.mentoring_model_tasks.where(:id => pending_tasks_ids)
    pending_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
      assert_equal new_student_membership.id, task.connection_membership_id
    end

    assert @group.has_member?(users(:student_3))
    assert @group.has_member?(users(:mentor_3))
    assert_equal [users(:mentor_3)], @group.mentors
    assert_equal [users(:student_3)], @group.students

    assert assigns(:is_manage_connections_view)
  end

  def test_update_add_two_mentors_success
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    assert_false @group.has_member?(users(:mentor_3))
    assert_false @group.has_member?(users(:mentor_4))
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    assert_difference('RecentActivity.count', 2) do
      assert_pending_notifications 2 do
        assert_emails 2 do
          post :update, xhr: true, params: {
            :id => @group.id,
            :connection => {
              :users => {
                users(:mentor_3).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_3).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
                users(:mentor_4).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
              }
            }
          }
        end
      end
    end

    email = ActionMailer::Base.deliveries[-2]
    assert_equal users(:mentor_3).email, email.to[0]
    assert_match(/You have been added as a mentor to name & example/, email.subject)

    email = ActionMailer::Base.deliveries[-1]
    assert_equal users(:mentor_4).email, email.to[0]
    assert_match(/You have been added as a mentor to name & example/, email.subject)

    notif_1 = PendingNotification.all[-2]
    assert_equal @user, notif_1.ref_obj_creator.user
    assert_equal notif_1.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    notif_2 = PendingNotification.all[-1]
    assert_equal @mentor, notif_2.ref_obj_creator.user
    assert_equal notif_2.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE

    assert_response :success
    @group.reload
    assert @group.has_member?(users(:mentor_3))
    assert @group.has_member?(users(:mentor_4))
    assert_equal [@mentor, users(:mentor_3), users(:mentor_4)], @group.mentors
    assert_equal [@user], @group.students
  end

  def test_update_add_members_with_actor_dont_have_permissions_should_not_get_updated
    pbe_group_setup
    current_user_is :f_mentor_pbe
    make_user_owner_of_group(@group, @mentor)
    @program.roles.find_by(name: RoleConstants::STUDENT_NAME).update_attributes!(can_be_added_by_owners: false)
    assert_false @program.roles.find_by(name: RoleConstants::STUDENT_NAME).can_be_added_by_owners?
    assert_false @group.has_member?(users(:pbe_student_1))

    program_roles = @program.roles.for_mentoring.group_by(&:name)
    post :update, params: {
      :id => @group.id,
      :src => "profile",
      :connection => {
        :users => {
          @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>"", "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"", "'option'"=>"", "'replacement_id'"=>""}},
          @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@user.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:pbe_student_1).id.to_s}},
        }
      }
    }
    @group.reload
    assert_false @group.has_member?(users(:pbe_student_1))
    assert @group.has_member?(@user)
    assert @group.has_member?(@mentor)
  end

  def test_update_add_members_with_actor_have_permissions_should_get_updated
    pbe_group_setup
    current_user_is :f_mentor_pbe
    make_user_owner_of_group(@group, @mentor)
    assert @program.roles.find_by(name: RoleConstants::STUDENT_NAME).can_be_added_by_owners?
    assert_false @group.has_member?(users(:pbe_student_1))

    program_roles = @program.roles.for_mentoring.group_by(&:name)
    post :update, params: {
      :id => @group.id,
      :src => "profile",
      :connection => {
        :users => {
          @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>"", "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"", "'option'"=>"", "'replacement_id'"=>""}},
          @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@user.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:pbe_student_1).id.to_s}},
        }
      }
    }
    @group.reload
    assert @group.has_member?(users(:pbe_student_1))
    assert_false @group.has_member?(@user)
    assert @group.has_member?(@mentor)
  end

  def test_update_add_members_with_default_tasks_and_removal_of_existing_members_leaving_tasks_unassigned
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    mentor_membership = @group.mentor_memberships.first
    student_membership = @group.student_memberships.first
    user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [mentor_membership, student_membership].collect(&:id))
    user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end

    assert_equal 2, @group.members.count
    assert_equal 1, @group.mentors.count
    assert_equal 1, @group.students.count

    program_roles = program.roles.group_by(&:name)
    post :update, xhr: true, params: {
      :id => @group.id,
      :connection => {
        :users => {
          users(:mentor_5).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
          users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
          @group.mentors.first.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@group.mentors.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"1", "'replacement_id'"=>""}},
          @group.students.first.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"1", "'replacement_id'"=>""}}
        }
      }
    }
    assert_response :success
    @group.reload
    assert @group.has_member?(users(:mentor_5))
    assert @group.has_member?(users(:student_4))
    assert_equal [users(:mentor_5)], @group.mentors
    assert_equal [users(:student_4)], @group.students

    user_tasks.each do |task|
      assert_false task.reload.connection_membership_id?
      assert task.from_template?
      assert task.unassigned_from_template?
    end

    new_mentor_membership = @group.mentor_memberships.first
    new_student_membership = @group.student_memberships.first
    new_user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [new_mentor_membership, new_student_membership].collect(&:id))

    new_user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end
  end

  def test_update_add_members_without_default_tasks_and_removal_of_existing_members_with_tasks_removed
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    mentor_membership = @group.mentor_memberships.first
    student_membership = @group.student_memberships.first
    user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [mentor_membership, student_membership].collect(&:id))
    user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end

    completed_task = user_tasks.first
    completed_task.update_attribute(:status, MentoringModel::Task::Status::DONE)

    assert_equal 2, @group.members.count
    assert_equal 1, @group.mentors.count
    assert_equal 1, @group.students.count

    program_roles = program.roles.group_by(&:name)
    post :update, xhr: true, params: {
      :id => @group.id,
      :connection => {
        :users => {
          users(:mentor_5).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"1", "'replacement_id'"=>""}},
          users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"1", "'replacement_id'"=>""}},
          @group.mentors.first.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@group.mentors.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
          @group.students.first.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
        }
      }
    }
    assert_response :success
    @group.reload
    assert @group.has_member?(users(:mentor_5))
    assert @group.has_member?(users(:student_4))
    assert_equal [users(:mentor_5)], @group.mentors
    assert_equal [users(:student_4)], @group.students

    user_tasks.reload
    assert user_tasks.blank?
    assert_false completed_task.reload.connection_membership_id?
    assert completed_task.from_template?
    assert completed_task.unassigned_from_template?

    new_mentor_membership = @group.mentor_memberships.first
    new_student_membership = @group.student_memberships.first
    new_user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [new_mentor_membership, new_student_membership].collect(&:id))
    assert new_user_tasks.blank?
  end

  def test_update_add_members_with_default_tasks_and_removal_of_existing_members_with_tasks_removed
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    mentor_membership = @group.mentor_memberships.first
    student_membership = @group.student_memberships.first
    user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [mentor_membership, student_membership].collect(&:id))
    user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end

    completed_task = user_tasks.first
    completed_task.update_attribute(:status, MentoringModel::Task::Status::DONE)

    assert_equal 2, @group.members.count
    assert_equal 1, @group.mentors.count
    assert_equal 1, @group.students.count

    program_roles = program.roles.group_by(&:name)
    post :update, xhr: true, params: {
      :id => @group.id,
      :connection => {
        :users => {
          users(:mentor_5).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
          users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
          @group.mentors.first.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@group.mentors.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
          @group.students.first.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
        }
      }
    }
    assert_response :success
    @group.reload
    assert @group.has_member?(users(:mentor_5))
    assert @group.has_member?(users(:student_4))
    assert_equal [users(:mentor_5)], @group.mentors
    assert_equal [users(:student_4)], @group.students

    user_tasks.reload
    assert user_tasks.blank?
    assert_false completed_task.reload.connection_membership_id?
    assert completed_task.from_template?
    assert completed_task.unassigned_from_template?

    new_mentor_membership = @group.mentor_memberships.first
    new_student_membership = @group.student_memberships.first
    new_user_tasks = @group.mentoring_model_tasks.where(connection_membership_id: [new_mentor_membership, new_student_membership].collect(&:id))
    new_user_tasks.each do |task|
      assert task.from_template?
      assert_false task.unassigned_from_template?
    end
  end

  def test_update_add_members_without_default_tasks_and_removal_of_existing_members_leaving_tasks_unassigned
    group_setup
    program = programs(:albers)
    program.update_attribute(:allow_one_to_many_mentoring, true)
    program_roles = program.roles.group_by(&:name)
    mentoring_model = program.default_mentoring_model
    import_mentoring_model(mentoring_model, skip_increment_version_and_trigger_sync: true)
    Group::MentoringModelCloner.new(@group, program, mentoring_model.reload).copy_mentoring_model_objects
    tasks = @group.mentoring_model_tasks.select(:connection_membership_id, :from_template, :unassigned_from_template)
    assert_equal_unordered (@group.membership_ids + [nil]), tasks.map(&:connection_membership_id).uniq
    assert_equal [true], tasks.map(&:from_template).uniq
    assert_equal_unordered [false, true], tasks.map(&:unassigned_from_template).uniq

    current_user_is :f_admin
    assert_no_difference "MentoringModel::Task.count" do
      post :update, xhr: true, params: { id: @group.id, connection: {
        users: {
          users(:mentor_5).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"1", "'replacement_id'"=>""}},
          users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"1", "'replacement_id'"=>""}},
          @group.mentors.first.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@group.mentors.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"1", "'replacement_id'"=>""}},
          @group.students.first.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"1", "'replacement_id'"=>""}}
        }
      } }
    end
    assert_response :success
    @group.reload
    tasks = @group.mentoring_model_tasks.select(:connection_membership_id, :from_template, :unassigned_from_template)
    assert_equal [nil], tasks.map(&:connection_membership_id).uniq
    assert_equal [true], tasks.map(&:from_template).uniq
    assert_equal [true], tasks.map(&:unassigned_from_template).uniq
  end

  def update_custom_term_for_connection(program)
    custom_connection_id = program.customized_terms.where(term_type: "Mentoring_Connection").first.id
    CustomizedTerm.find_by(id: custom_connection_id).update_attributes(term: "Mentoring Connection", term_downcase: "mentoring connection", pluralized_term: "Mentoring Connections", pluralized_term_downcase: "mentoring connections", articleized_term: "a Mentoring Connection", articleized_term_downcase: "a mentoring connection")
  end

  def test_update_add_mentor_empty
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    assert_false @group.has_member?(users(:mentor_3))
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    update_custom_term_for_connection(program)
    assert_no_difference('RecentActivity.count') do
      assert_no_emails do
        post :update, xhr: true, params: { :id => @group.id,
        :connection => {
          :users => {
            @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@mentor.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
          }
        }}
      end
    end

    assert_response :success
    assert_equal "A mentoring connection needs at least one mentor. Try closing the mentoring connection instead of removing the mentor.", assigns(:error_flash)

    @group.reload
    assert_equal [@mentor], @group.mentors
    assert_equal [@user], @group.students
  end

  def test_update_add_student_empty
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    assert_false @group.has_member?(users(:mentor_3))
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    update_custom_term_for_connection(program)
    assert_no_difference('RecentActivity.count') do
      assert_no_emails do
        post :update, xhr: true, params: {
          :id => @group.id,
          :connection => {
            :users => {
              @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@user.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          }
        }
      end
    end

    assert_response :success
    assert_equal "A mentoring connection needs at least one student. Try closing the mentoring connection instead of removing the student.", assigns(:error_flash)

    @group.reload
    assert_equal [@mentor], @group.mentors
    assert_equal [@user], @group.students
  end

  def test_update_add_student_and_mentor_empty
    group_setup
    current_user_is :f_admin
    programs(:albers).update_attribute(:allow_one_to_many_mentoring, true)
    assert_false @group.has_member?(users(:mentor_3))
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    update_custom_term_for_connection(program)
    assert_no_difference('RecentActivity.count') do
      assert_no_emails do
        post :update, xhr: true, params: {
          :id => @group.id,
          :connection => {
            :users => {
              @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@mentor.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
              @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@user.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          },
          :role => RoleConstants::STUDENT_NAME
        }
      end
    end

    assert_response :success
    assert_equal "A mentoring connection needs at least one mentor and student. Try closing the mentoring connection instead of removing the mentor and student.", assigns(:error_flash)

    @group.reload
    assert_equal [@mentor], @group.mentors
    assert_equal [@user], @group.students
  end

  def test_show_permissions_not_global
    current_user_is :f_student
    assert_false groups(:group_3).global?
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)

    assert_permission_denied do
      get :profile, params: { :id => groups(:group_3)}
    end
  end

  def test_show_permissions_global
    current_user_is :f_student
    groups(:mygroup).update_attribute(:global , true)
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    groups(:mygroup).program.update_attributes!(:allow_users_to_mark_connection_public => true)

    assert groups(:mygroup).global?

    get :profile, params: { :id => groups(:mygroup), src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST}

    assert_response :success
    assert assigns(:outsider_view)
    assert_equal groups(:mygroup), assigns(:group)
    assert assigns(:is_group_profile_view)
    assert assigns(:src_path), EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST
  end

  def test_show_redirect
    current_user_is :f_mentor
    assert_false programs(:org_primary).connection_profiles_enabled?

    get :profile, params: { :id => groups(:mygroup), :activation => 1}

    assert_equal groups(:mygroup), assigns(:group)
    assert_redirected_to group_path(groups(:mygroup) , :activation => 1)
  end

  def test_show_profile
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    groups(:mygroup).update_attribute(:global , true)
    assert groups(:mygroup).global?

    get :profile, params: { :id => groups(:mygroup)}

    assert_response :success
    assert_false assigns(:outsider_view)
    assert_equal groups(:mygroup), assigns(:group)
    assert_equal "/assets/icons/group_profile.png", assigns(:logo_url)
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
    assert assigns(:is_group_profile_view)

    assert_select "div#group_side_pane" do
      assert_select "a", :text => "Meetings", :count => 0
    end
    assert_select "nav-tabs", count: 0
    assert_select "a", text: "Start a Conversation", count: 0
  end

  def test_show_calendar_feature_enabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    groups(:mygroup).update_attribute(:global , true)
    assert groups(:mygroup).global?

    get :profile, params: { :id => groups(:mygroup)}


    assert_response :success
    assert_false assigns(:outsider_view)
    assert_equal groups(:mygroup), assigns(:group)
    assert_equal "/assets/icons/group_profile.png", assigns(:logo_url)
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_edit_answers_xhr
    current_user_is :f_mentor
    get :edit_answers, xhr: true, params: { :id => groups(:mygroup)}
    assert_response :success
    assert_nil assigns(:connection_questions)
  end

  def test_edit_answers_connection_profile_disabled
    disable_feature(programs(:albers), FeatureName::CONNECTION_PROFILE)

    current_user_is :f_mentor
    get :edit_answers, params: { :id => groups(:mygroup) }
    assert_response :success
    assert_blank assigns(:connection_questions)
  end

  def test_edit_answers_permission_other_users
    current_user_is :f_student
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)

    assert_permission_denied do
      get :edit_answers, params: { :id => groups(:mygroup)}
    end
  end

  def test_edit_answers
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)

    get :edit_answers, params: { :id => groups(:mygroup)}

    assert_response :success
    assert_no_match(/group_notes_/, response.body)
    assert_equal groups(:mygroup), assigns(:group)
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_edit_answers_by_admin
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)

    get :edit_answers, params: { :id => groups(:mygroup)}

    assert_response :success
    assert_match /id=\"group_notes_\"/, response.body
    assert_equal groups(:mygroup), assigns(:group)
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_get_edit_start_date_popup_permission_denied
    group = groups(:mygroup)
    current_user_is :f_mentor_student

    assert_permission_denied do
      get :get_edit_start_date_popup, params: {:id => group.id}
    end
  end

  def test_get_edit_start_date_popup
    group = groups(:mygroup)
    current_user_is :f_mentor

    get :get_edit_start_date_popup, xhr: true, params: {:id => group.id, :propose_workflow => "true", :from_profile_flash => "true"}
    
    assert_response :success
    assert assigns(:propose_workflow)
    assert assigns(:from_profile_flash)
  end

  def test_update_answers_permission_feature
    programs(:albers).enable_feature(FeatureName::CONNECTION_PROFILE)
    current_user_is :f_mentor
    post :update_answers, params: { :id => groups(:mygroup), :group => {:name => "hi"},
      :connection_answers => { common_questions(:required_string_connection_q).id.to_s => "world" }}
    assert_equal "hi", groups(:mygroup).reload.name
  end

  def test_update_answers_disabling_connection_profile
    programs(:albers).enable_feature(FeatureName::CONNECTION_PROFILE, false)
    current_user_is :student_2
    post :update_answers, params: { id: groups(:group_2), group: {name: "hi"},
        connection_answers: { common_questions(:required_string_connection_q).id.to_s => "world" } }
    assert_redirected_to edit_answers_group_path(groups(:group_2))
    assert_equal "You are not authorized to access the page", flash[:error]
    assert_false assigns(:from_profile_flash)
  end

  def test_update_answers_permission_user
    current_user_is :f_student
    assert_permission_denied do
      post :update_answers, params: { :id => groups(:mygroup), :group => {:name => "hi"},
        :connection_answers => { common_questions(:required_string_connection_q).id.to_s => "world" }}
    end
  end

  def test_update_answers_success
    current_user_is :student_2
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:group_2)

    assert_difference "Connection::Answer.count", 4 do
      post :update_answers, params: { :id => group,
        :group => {:global => "1", :name => "hi", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')},
        :connection_answers => {
          common_questions(:required_string_connection_q).id.to_s => "world",
          common_questions(:string_connection_q).id.to_s => "hello",
          common_questions(:single_choice_connection_q).id.to_s => "opt_2",
          common_questions(:multi_choice_connection_q).id.to_s => ["Walk","Run"]
        }
      }
    end

    assert_equal "hi", group.reload.name
    assert_equal "test_pic.png", group.logo_file_name
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert group.global?
  end

  def test_update_answers_for_set_start_date_popup_propose_workflow
    current_user_is :student_2
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    programs(:albers).update_attribute(:allow_circle_start_date, true)
    group = groups(:group_2)

    Member.any_instance.stubs(:get_valid_time_zone).returns("Asia/Kolkata")

    post :update_answers, xhr: true, params: {:id => group,
      :group => {:global => "1", :name => "hi", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :start_date => "April 19, 2028"}, :set_start_date_popup => true, :propose_workflow => true, :from_profile_flash => "true"}

    assert_equal "hi", group.reload.name
    assert_equal "test_pic.png", group.logo_file_name
    assert_equal "April 19, 2028".to_time.in_time_zone("Asia/Kolkata").to_date, group.start_date.in_time_zone("Asia/Kolkata").to_date
    assert_equal "A start date has been set for the mentoring connection.", flash[:notice]
    assert group.global?
    assert assigns(:from_profile_flash)
  end

  def test_update_answers_for_set_start_date_popup
    current_user_is :student_2
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:group_2)

    programs(:albers).update_attributes(:allow_circle_start_date => false)

    post :update_answers, xhr: true, params: {:id => group,
      :group => {:global => "1", :name => "hi", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'), :start_date => "April 19, 2028"}, :set_start_date_popup => true}

    assert_equal "hi", group.reload.name
    assert_equal "test_pic.png", group.logo_file_name
    assert_false group.program.allow_circle_start_date?
    assert_nil group.start_date
    assert_nil flash[:notice]
    assert group.global?
  end

  def test_update_answers_for_set_start_date_popup_without_start_date
    current_user_is :student_2
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:group_2)

    post :update_answers, xhr: true, params: {:id => group,
      :group => {:global => "1", :name => "hi", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')}, :set_start_date_popup => true}

    assert_equal "hi", group.reload.name
    assert_equal "test_pic.png", group.logo_file_name
    assert_nil flash[:notice]
    assert group.global?
  end

  def test_update_answers_failure
    stub_paperclip_size(21.megabytes.to_i)
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:group_2)

    current_user_is :student_2

    assert_no_difference "Connection::Answer.count" do
      post :update_answers, params: { :id => group,
        :group => {:name => "hi", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')},
        :connection_answers => {
          common_questions(:required_string_connection_q).id.to_s => "world",
          common_questions(:string_connection_q).id.to_s => "hello",
          common_questions(:single_choice_connection_q).id.to_s => "opt_2",
          common_questions(:multi_choice_connection_q).id.to_s => ["Walk","Run"]
        }
      }
    end

    assert_false group.reload.logo?
    assert_redirected_to edit_answers_group_path(group)
  end

  def test_update_answers_required_failure
    current_user_is :student_2
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    group = groups(:group_2)

    assert_no_difference "Connection::Answer.count" do
      post :update_answers, params: { :id => group,
        :group => {:global => "1", :name => "hi", :logo => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')},
        :connection_answers => {
          common_questions(:required_string_connection_q).id.to_s => "", # Error
          common_questions(:string_connection_q).id.to_s => "hello",
          common_questions(:single_choice_connection_q).id.to_s => "opt_2",
          common_questions(:multi_choice_connection_q).id.to_s => ["Walk","Run"]
        }
      }
    end

    assert_equal "hi", group.reload.name
    assert_equal "test_pic.png", group.logo_file_name
    assert_redirected_to edit_answers_group_path(group)
  end

  def test_update_answers_by_group_proposer
    proposer = users(:f_mentor_pbe)
    group = groups(:group_pbe_1)
    roles = programs(:pbe).roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).index_by(&:name)
    student_role_id = roles[RoleConstants::STUDENT_NAME].id
    current_user_is :f_mentor_pbe

    assert_permission_denied do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => 5 }}}
    end

    group.update_attributes!(status: Group::Status::PROPOSED, created_by: proposer)
    group.mentors = [proposer]
    group.save!

    assert_difference "Group::MembershipSetting.count", +1 do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => 5 }}}
    end
    assert_redirected_to profile_group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal group.membership_settings.first, Group::MembershipSetting.last
    assert_equal 5, group.membership_settings.find_by(role_id: student_role_id).max_limit
  end

  def test_add_no_member_for_empty_unpublished_pbe_group
    current_user_is :f_admin_pbe
    current_program_is programs(:pbe)
    group = create_group(name: "test", created_by: users(:f_admin_pbe), :mentors => [], :students => [], :program => programs(:pbe), :status => Group::Status::DRAFTED)
    post :update, xhr: true, params: { :id => group.id, :tab => Group::Status::DRAFTED}
    assert_response :success
    assert_match /The mentoring connection has been updated/, response.body
  end

  def test_add_no_member_for_unpublished_pbe_group
    current_user_is :f_admin_pbe
    current_program_is programs(:pbe)
    @group = groups(:group_pbe_0)
    Group.any_instance.expects(:update_members)
    @group.update_attribute(:status, Group::Status::DRAFTED)
    post :update, xhr: true, params: { :id => @group.id, :connection => {:users => {}},:tab => Group::Status::DRAFTED}
    assert_response :success
  end


  def test_update_memberhship_setting_for_unpublished_group
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    role = program.get_role(RoleConstants::STUDENT_NAME)
    group = groups(:group_pbe_1)
    group.global = true
    group.save!
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id

    assert_difference "Group::MembershipSetting.count", +1 do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => 5 }}}
    end
    assert_redirected_to profile_group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal group.membership_settings.first, Group::MembershipSetting.last
    assert_equal 5, group.membership_settings.find_by(role_id: role.id).max_limit
  end

  def test_update_memberhship_setting_for_unpublished_group_update
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    role = program.get_role(RoleConstants::STUDENT_NAME)
    group = groups(:group_pbe_1)
    group.global = true
    group.save!
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    group.membership_settings.create(role_id: role.id, max_limit: 5)

    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => 8 }}}
    end
    assert_redirected_to profile_group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal 8, group.membership_settings.find_by(role_id: role.id).max_limit
  end

  def test_update_membership_setting_for_unpublished_group_with_teacher_role
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    role = program.get_role("teacher")
    role.add_permission("send_project_request")
    group = groups(:group_pbe_1)
    group.global = true
    group.save!
    teacher_role_id = program.roles.find_by(name: "teacher").id

    assert_difference "Group::MembershipSetting.count", +1 do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { teacher_role_id.to_s => 5 }}}
    end
    assert_redirected_to profile_group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal group.membership_settings.first, Group::MembershipSetting.last
    assert_equal 5, group.membership_settings.find_by(role_id: role.id).max_limit
  end

  def test_create_group_without_name
    program = programs(:albers)
    current_user_is :f_admin
    current_program_is program
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id

    assert_difference "Group.count" do
      post :create, xhr: true, params: { group: { mentoring_model_id: program.default_mentoring_model.id },
        group_members: {
          role_id: {
            :"#{mentor_role_id}" => users(:ram).name_with_email,
            :"#{student_role_id}" => users(:f_mentor_student).name_with_email
          }
        }
      }
    end
    assert_equal "Raman & Studenter", users(:ram).groups[0].name
  end

  def test_create_group_with_name
    program = programs(:albers)
    current_user_is :f_admin
    current_program_is program
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id

    assert_difference "Group.count" do
      post :create, xhr: true, params: { group: { name: "Group name", mentoring_model_id: program.default_mentoring_model.id },
        group_members: {
          role_id: {
            :"#{mentor_role_id}" => users(:ram).name_with_email,
            :"#{student_role_id}" => users(:f_mentor_student).name_with_email
          }
        }
      }
    end
    assert_equal "Group name", users(:ram).groups[0].name
  end

  ####################################################################################################
  #
  # Slot config related tests
  #
  # The following tests checks the test cases in 3 scenarios:
  # (Group creation, group proposal, editing connection profile)
  #
  # Case#   slot_config   params     membership_setting_present?  Action on membership setting object
  # 1       optional      present    no                           create new object
  # 2                     present    yes                          update object
  # 3                     absent     no                           ignore
  # 4                     absent     yes                          destroy object
  # 5       required      present    no                           create new object
  # 6                     present    yes                          update object
  # 7                     absent     yes/no                       raise error
  # 8       disabled      present    yes/no                       ignore - should not create/update
  # 9                     absent     yes/no                       ignore - should not destroy
  #
  #####################################################################################################


  def test_slot_config_setting_test_case_1
    current_user_is :f_mentor_pbe
    pbe_slot_config_test_setup
    programs(:pbe).update_attributes(:allow_circle_start_date => false)
    @slot_config_test__program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    assert @slot_config_test__student_role.slot_config_optional?
    assert_differences [["Group.count", 1], ["Group::MembershipSetting.count", 1]] do
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {@slot_config_test__student_role.id.to_s =>  "5"}
      },
      :propose_view => "true"}
    end
  end

  def test_slot_config_setting_test_case_2
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    set_max_limit_for_group(@slot_config_test__group, 2, RoleConstants::STUDENT_NAME)
    assert @slot_config_test__student_role.slot_config_optional?
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => @slot_config_test__group, :group => {
        :name => "hello", :membership_setting => { @slot_config_test__student_role.id.to_s => "5" }
      }}
    end
    assert_redirected_to group_path(@slot_config_test__group)
    assert_equal "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal 5, @slot_config_test__group.setting_for_role_id(@slot_config_test__student_role.id).max_limit
  end

  def test_slot_config_setting_test_case_3
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    assert @slot_config_test__student_role.slot_config_optional?
    assert_differences [["Group.count", 1], ["Group::MembershipSetting.count", 0]] do
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {@slot_config_test__student_role.id.to_s =>  ""}
      }}
    end
  end

  def test_slot_config_setting_test_case_4
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    set_max_limit_for_group(@slot_config_test__group, 2, RoleConstants::STUDENT_NAME)
    assert @slot_config_test__student_role.slot_config_optional?
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => @slot_config_test__group, :group => {
        :name => "hello", :membership_setting => { @slot_config_test__student_role.id.to_s => "" }
      }}
    end
    assert_redirected_to group_path(@slot_config_test__group)
    assert_equal "Mentoring Connection profile has been saved", flash[:notice]
    assert_nil @slot_config_test__group.setting_for_role_id(@slot_config_test__student_role.id).max_limit
  end

  def test_slot_config_setting_test_case_5
    current_user_is :f_mentor_pbe
    pbe_slot_config_test_setup
    programs(:pbe).update_attributes(:allow_circle_start_date => false)
    @slot_config_test__student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)
    @slot_config_test__program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    assert_differences [["Group.count", 1], ["Group::MembershipSetting.count", 1]] do
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {@slot_config_test__student_role.id.to_s =>  "5"}
      },
      :propose_view => "true"}
    end
  end

  def test_slot_config_setting_test_case_6
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    @slot_config_test__student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)
    set_max_limit_for_group(@slot_config_test__group, 2, RoleConstants::STUDENT_NAME)
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => @slot_config_test__group, :group => {
        :name => "hello", :membership_setting => { @slot_config_test__student_role.id.to_s => "5" }
      }}
    end
    assert_redirected_to group_path(@slot_config_test__group)
    assert_equal "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal 5, @slot_config_test__group.setting_for_role_id(@slot_config_test__student_role.id).max_limit
  end

  def test_slot_config_setting_test_case_7
    current_user_is :f_mentor_pbe
    pbe_slot_config_test_setup
    @slot_config_test__student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)
    @slot_config_test__program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    assert_no_difference "Group.count" do
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {@slot_config_test__student_role.id.to_s =>  ""}
      },
      :propose_view => "true"}
    end
    assert_redirected_to program_root_path
  end

  def test_slot_config_setting_test_case_7_while_updating
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    @slot_config_test__student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)
    set_max_limit_for_group(@slot_config_test__group, 2, RoleConstants::STUDENT_NAME)
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => @slot_config_test__group, :group => {
        :name => "hello", :membership_setting => { @slot_config_test__student_role.id.to_s => "" }
      }}
    end
    assert_equal "The maximum limit of students in the mentoring connection cannot be empty.", flash[:error]
    assert_equal 2, @slot_config_test__group.setting_for_role_id(@slot_config_test__student_role.id).max_limit
  end

  def test_slot_config_setting_test_case_8
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    @slot_config_test__student_role.update_attributes!(slot_config: nil)
    assert_nil @slot_config_test__group.setting_for_role_id(@slot_config_test__student_role.id)
    assert_differences [["Group.count", 1], ["Group::MembershipSetting.count", 0]] do
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {@slot_config_test__student_role.id.to_s =>  "5"}
      }}
    end
  end

  def test_slot_config_setting_test_case_9
    current_user_is :f_admin_pbe
    pbe_slot_config_test_setup
    @slot_config_test__student_role.update_attributes!(slot_config: nil)
    set_max_limit_for_group(@slot_config_test__group, 2, RoleConstants::STUDENT_NAME)
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => @slot_config_test__group, :group => {
        :name => "hello", :membership_setting => { @slot_config_test__student_role.id.to_s => "" }
      }}
    end
    assert_equal 2, @slot_config_test__group.setting_for_role_id(@slot_config_test__student_role.id).max_limit
  end

  def test_update_membership_setting_respects_slot_config
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    student_role_id = student_role.id
    group = groups(:group_pbe)
    group.global = true
    group.save!

    assert student_role.slot_config_optional?
    assert_nil group.membership_settings.find_by(role_id: student_role.id)
    # Test#3
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => "" }}}
    end
    assert_redirected_to group_path(group)
    assert_equal "Mentoring Connection profile has been saved", flash[:notice]

    # Test#1
    assert_difference "Group::MembershipSetting.count", +1 do
      post :update_answers, params: { :id => group, :group => { :name => "hello", :membership_setting => { student_role_id.to_s => 5 }}}
    end
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hello", group.reload.name
    assert_equal group.membership_settings.first, Group::MembershipSetting.last
    assert_equal 5, group.membership_settings.find_by(role_id: student_role.id).max_limit

    # Test#5
    student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)

    post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => "" }}}
    assert_equal "The maximum limit of students in the mentoring connection cannot be empty.", flash[:error]
    assert_equal 5, group.membership_settings.find_by(role_id: student_role.id).max_limit

    # Test#7
    student_role.update_attributes!(slot_config: nil)
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => group, :group => { :name => "hello", :membership_setting => { student_role_id.to_s => "" }}}
    end
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal 5, group.membership_settings.find_by(role_id: student_role.id).max_limit

    # Test#2
    student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::OPTIONAL)
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => group, :group => { :name => "hello", :membership_setting => { student_role_id.to_s => "" }}}
    end
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_nil group.membership_settings.find_by(role_id: student_role.id).max_limit

    # Test#6
    student_role.update_attributes!(slot_config: nil)
    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => group, :group => { :name => "hello", :membership_setting => { student_role_id.to_s => "5" }}}
    end
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_nil group.membership_settings.find_by(role_id: student_role.id).max_limit
  end

  def test_update_membership_setting_for_unpublished_group_with_teacher_role_and_student_role
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    teacher_role = program.get_role("teacher")
    student_role = program.get_role("student")
    teacher_role.add_permission("send_project_request")
    group = groups(:group_pbe_1)
    group.global = true
    group.save!

    assert_difference "Group::MembershipSetting.count", +2 do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { teacher_role.id.to_s => 5, student_role.id.to_s => 4 }}}
    end
    assert_redirected_to profile_group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal 5, group.membership_settings.find_by(role_id: teacher_role.id).max_limit
    assert_equal 4, group.membership_settings.find_by(role_id: student_role.id).max_limit
  end

  def test_update_memberhship_setting_for_published_group_maxlimit_5
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    role = program.get_role(RoleConstants::STUDENT_NAME)
    group = groups(:group_pbe)
    group.global = true
    group.save!
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id

    assert_difference "Group::MembershipSetting.count", +1 do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => 5 }}}
    end
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal group.membership_settings.first, Group::MembershipSetting.last
    assert_equal 5, group.membership_settings.find_by(role_id: role.id).max_limit
  end

  def test_update_memberhship_setting_for_published_group
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    role = program.get_role(RoleConstants::STUDENT_NAME)
    group = groups(:group_pbe)
    group.global = true
    group.save!
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    group.membership_settings.create(role_id: role.id, max_limit: 5)

    assert_no_difference "Group::MembershipSetting.count" do
      post :update_answers, params: { :id => group, :group => { :name => "hi", :membership_setting => { student_role_id.to_s => 8 }}}
    end
    assert_redirected_to group_path(group)
    assert_equal  "Mentoring Connection profile has been saved", flash[:notice]
    assert_equal "hi", group.reload.name
    assert_equal 8, group.membership_settings.find_by(role_id: role.id).max_limit
  end

  def test_make_group_profile_private
    current_user_is :f_mentor
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    g = groups(:mygroup)
    g.global = true
    g.save!
    assert g.global?

    post :update_answers, params: { :id => g.id, :group => {:global => "0", :name => "hi"},
      :connection_answers => { common_questions(:required_string_connection_q).id.to_s => "world" }
    }

    assert_redirected_to group_path(g)
    assert_false g.reload.global?
  end

  def test_should_not_show_mentoring_tip_for_mentor
    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success

    assert_select 'html' do
      assert_no_select 'div#mentoring_area_tips'
    end
    assert_nil assigns(:random_tip)
    assert_false assigns(:can_current_user_create_meeting)
  end

  def test_should_not_show_tour_for_member_one_one_group
    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_equal 2, groups(:mygroup).members.count
    assert_false assigns(:show_tour_v2)
  end

  def test_should_not_show_tour_for_member
    add_users_to_group(groups(:mygroup), [users(:f_mentor_student)], :mentor)
    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert groups(:mygroup).members.count > 2
    assert assigns(:show_tour_v2)
  end

  def test_should_not_show_tour_for_member_if_already_shown
    users(:f_mentor).one_time_flags.create!(message_tag: OneTimeFlag::Flags::TourTags::GROUP_SHOW_V2_TOUR_TAG)
    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_false assigns(:show_tour_v2)
  end

  def test_mentoring_model_tasks_for_feature_disbale
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => group.id}
    assert_response :success
    assert_empty assigns(:mentoring_model_tasks)
  end

  def test_show_home_page_view
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { :id => group.id, home_page_view: true}
    assert_response :success
    assert assigns(:home_page_view)
  end

  def test_mentoring_model_tasks_if_feature_enabled
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => group.reload.id}
    assert_response :success
    assert_equal group.get_tasks_list, assigns(:mentoring_model_tasks)
  end

  def test_groups_all_members_enabled
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    new_users = group.program.student_users - group.members.students
    users(:f_mentor).update_attribute(:max_connections_limit, 50)
    add_users_to_group(group, new_users, :student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => group}
    assert_response :success
    assert_equal true, assigns(:all_members_enabled)
  end

  def test_mentoring_model_milestones
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    milestone3 = create_mentoring_model_milestone
    milestone4 = create_mentoring_model_milestone
    milestone5 = create_mentoring_model_milestone

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 10.days)
    task1.update_attribute(:status, MentoringModel::Task::Status::DONE)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days)
    task3 = create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today + 10.days)
    task3.update_attribute(:status, MentoringModel::Task::Status::DONE)
    task4 = create_mentoring_model_task(milestone_id: milestone4.id)
    task5 = create_mentoring_model_task(milestone_id: milestone5.id, required: true, due_date: Date.today + 10.days)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id}
    assert_response :success
    assert_equal({milestone1.id => [task1], milestone2.id => [task2], milestone3.id => [task3], milestone4.id => [task4], milestone5.id => [task5]}, assigns(:mentoring_model_tasks))
    assert_equal [milestone1.id], assigns(:completed_mentoring_model_milestone_ids_to_hide)
    assert_equal [milestone4.id, milestone2.id], assigns(:mentoring_model_milestone_ids_to_expand)
    assert_equal [milestone2, milestone3, milestone4, milestone5], assigns(:mentoring_model_milestones)
    assert_equal [milestone1.id, milestone3.id, milestone4.id], assigns(:completed_mentoring_model_milestone_ids)
    assert_false assigns(:is_group_profile_view)
  end

  def test_mentoring_model_milestones_home_page_view
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    milestone3 = create_mentoring_model_milestone

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 3.days)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 5.days)
    task3 = create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today + 15.days)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [milestone1, milestone2], assigns(:mentoring_model_milestones)

    task1.update_attribute(:status, MentoringModel::Task::Status::DONE)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [milestone2], assigns(:mentoring_model_milestones)

    task2.update_attribute(:status, MentoringModel::Task::Status::DONE)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [], assigns(:mentoring_model_milestones)
    task3.update_column(:due_date, Date.today - 15.days)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [milestone3], assigns(:mentoring_model_milestones)
  end

  def test_mentoring_model_tasks_home_page_view
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)

    task1 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days)
    task2 = create_mentoring_model_task(required: true, due_date: Date.today + 5.days)
    task3 = create_mentoring_model_task(required: true, due_date: Date.today + 15.days)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [task1, task2], assigns(:mentoring_model_tasks)

    task1.update_attribute(:status, MentoringModel::Task::Status::DONE)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [task2], assigns(:mentoring_model_tasks)

    task2.update_attribute(:status, MentoringModel::Task::Status::DONE)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [], assigns(:mentoring_model_tasks)
    task3.update_column(:due_date, Date.today - 15.days)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, xhr: true, params: { id: group.id, home_page_view: true}
    assert_response :success
    assert_equal [task3], assigns(:mentoring_model_tasks)
  end

  def test_mentoring_model_milestones_with_no_current_milestones
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    milestone3 = create_mentoring_model_milestone

    assert_empty group.mentoring_model_milestones.overdue
    assert_empty group.mentoring_model_milestones.current

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 10.days)
    task1.update_attribute(:status, MentoringModel::Task::Status::DONE)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days)
    task2.update_attribute(:status, MentoringModel::Task::Status::DONE)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id}
    assert_response :success
    assert_equal({ milestone1.id => [task1], milestone2.id => [task2], milestone3.id => [] }, assigns(:mentoring_model_tasks))
    assert_equal [milestone1.id, milestone2.id], assigns(:completed_mentoring_model_milestone_ids_to_hide)
    assert_equal [milestone3.id], assigns(:mentoring_model_milestone_ids_to_expand)
    assert_equal [milestone3], assigns(:mentoring_model_milestones)
    assert_equal [milestone1.id, milestone2.id], assigns(:completed_mentoring_model_milestone_ids)
    assert_false assigns(:is_group_profile_view)
  end

  def test_mentoring_model_milestones_in_due_date_filter_mode
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task1 = create_mentoring_model_task(milestone_id: milestone1.id)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE}
    assert_response :success
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, assigns(:view_mode)
    assert_equal [task2, task1], assigns(:mentoring_model_tasks)
  end

  def test_mentoring_model_milestones_with_target_user
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)

    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    milestone3 = create_mentoring_model_milestone

    members = group.members.to_a

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, user: members.first)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days, user: members.last)
    task3 = create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today + 10.days, user: members.last)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id, target_user_id: group.members.first.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success
    assert_equal({milestone1.id => [task1], milestone2.id => [], milestone3.id => []}, assigns(:mentoring_model_tasks))
    assert_equal [milestone1.id], assigns(:completed_mentoring_model_milestone_ids_to_hide)
    assert_equal [milestone1.id, milestone2.id], assigns(:mentoring_model_milestone_ids_to_expand)
    assert_equal [milestone2, milestone3], assigns(:mentoring_model_milestones)

    assert_false assigns(:is_group_profile_view)
  end

  def test_show_for_overdue_survey_popup_without_cookie_present
    current_user_is :f_mentor
    group = groups(:mygroup)

    survey = surveys(:two)

    mentoring_model = programs(:albers).mentoring_models.default.first
    groups(:mygroup).update_attribute(:mentoring_model_id, mentoring_model.id)

    cm = groups(:mygroup).membership_of(users(:f_mentor))
    MentoringModel::Task.any_instance.stubs(:overdue?).returns(true)

    task_template = create_mentoring_model_task_template
    task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    task_template.action_item_id = survey.id
    task_template.skip_survey_validations = true
    task_template.save!

    task = cm.get_last_outstanding_survey_task

    assert_false @request.cookies.key?("#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{cm.id}")
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id}

    assert_response :success

    assert cookies.key?("#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{cm.id}")
    assert_equal survey, assigns(:oldest_overdue_survey)
    assert_equal edit_answers_survey_path(survey, :task_id => task.id, :src => Survey::SurveySource::POPUP, format: :js), assigns(:survey_answer_url)
  end

  def test_show_for_overdue_survey_popup_with_cookie_present
    current_user_is :f_mentor
    group = groups(:mygroup)

    survey = surveys(:two)

    mentoring_model = programs(:albers).mentoring_models.default.first
    groups(:mygroup).update_attribute(:mentoring_model_id, mentoring_model.id)

    cm = groups(:mygroup).membership_of(users(:f_mentor))
    MentoringModel::Task.any_instance.stubs(:overdue?).returns(true)

    task_template = create_mentoring_model_task_template
    task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    task_template.action_item_id = survey.id
    task_template.skip_survey_validations = true
    task_template.save!

    task = cm.get_last_outstanding_survey_task

    @request.cookies["#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{cm.id}"] = {:value => true, :expires => GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_EXPIRY_TIME}
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id}

    assert_response :success

    assert cookies.key?("#{GroupsController::OVERDUE_SURVEY_POPUP_COOKIE_FORMAT}_#{cm.id}")
    assert_nil assigns(:oldest_overdue_survey)
    assert_nil assigns(:survey_answer_url)
  end

  def test_mentoring_model_milestones_in_due_date_filter_mode_with_target_user
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_mentor)
    group = groups(:mygroup)
    program = group.program
    group.allow_manage_mm_tasks!(program.roles.for_mentoring_models)
    group.allow_manage_mm_milestones!(program.roles.for_mentoring_models)
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    members = group.members.to_a
    task1 = create_mentoring_model_task(milestone_id: milestone1.id, user: members.first)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days, user: members.last)

    cm = groups(:mygroup).membership_of(users(:f_mentor))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, target_user_id: group.members.reload.last, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, assigns(:view_mode)
    assert_equal [task2], assigns(:mentoring_model_tasks)

    assert_nil assigns(:oldest_overdue_survey)
    assert_nil assigns(:survey_answer_url)
  end

  def test_mentoring_model_milestones_in_due_date_filter_mode_with_preserved_target_user_and_view_mode_filter
    setup_for_update_view_mode_filter
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task1 = create_mentoring_model_task(milestone_id: milestone1.id, user: @group.members.first)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days, user: @group.members.reload.last)
    cm = @group.membership_of(@user)
    cm.update_attributes!(last_applied_task_filter: {user_info: connection_memberships(:connection_memberships_2).user_id.to_s, view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE})
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_response :success
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
    assert_equal connection_memberships(:connection_memberships_2).user, assigns(:target_user)
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, assigns(:view_mode)
  end

  def test_tasks_filter_should_not_show_all_members_if_group_has_more_than_25_members
    setup_for_update_view_mode_filter
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task1 = create_mentoring_model_task(milestone_id: milestone1.id, user: @group.members.first)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days, user: @group.members.reload.last)
    cm = @group.membership_of(@user)
    cm.update_attributes!(last_applied_task_filter: {user_info: GroupsController::TargetUserType::ALL_MEMBERS})
    Group.any_instance.stubs(:members).returns(User.limit(26))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    assert_response :success
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
    assert_equal connection_memberships(:connection_memberships_2).user, assigns(:target_user)
  end

  def test_update_view_mode_filter_milestone_normal_view
    setup_for_update_view_mode_filter
    membership = @group.membership_of(users(:f_mentor))
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    @group.meetings.destroy_all
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task11 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: @group.published_at + 10.days, position: 0)
    task12 = create_mentoring_model_task(milestone_id: milestone1.id, required: false, position: 1)
    task21 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: @group.published_at + 5.days, position: 0)
    task22 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: @group.published_at + 15.days, position: 1)
    assert_nil membership.reload.last_applied_task_filter
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, target_user_type: GroupsController::TargetUserType::UNASSIGNED}
    assert_response :success
    assert_nil membership.reload.last_applied_task_filter
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_MILESTONES}
    assert_response :success
    assert_nil membership.reload.last_applied_task_filter
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, assigns(:view_mode)
    assert_equal({milestone1.id => [task11, task12], milestone2.id => [task21, task22]}, assigns(:mentoring_model_tasks))
  end

  def test_update_view_mode_filter_milestone_normal_view_with_target_user
    setup_for_update_view_mode_filter
    membership = @group.membership_of(users(:f_mentor))
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    @group.meetings.destroy_all
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    members = @group.members.to_a
    task11 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: @group.published_at + 10.days, position: 0, user: members.first)
    task12 = create_mentoring_model_task(milestone_id: milestone1.id, required: false, position: 1, user: members.last)
    task21 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: @group.published_at + 5.days, position: 0, user: members.last)
    task22 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: @group.published_at + 15.days, position: 1, user: members.first)
    assert_nil membership.last_applied_task_filter
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, target_user_id: members.first.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, assigns(:view_mode)
    assert_equal @group.members.first, assigns(:target_user)
    assert_equal({milestone1.id => [task11], milestone2.id => [task22]}, assigns(:mentoring_model_tasks))
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, target_user_id: members.first.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success
    assert_equal members.first.id, membership.reload.user_info.to_i
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, membership.reload.view_mode
    assert_equal members.first, assigns(:target_user)
    assert_equal({milestone1.id => [task11], milestone2.id => [task22]}, assigns(:mentoring_model_tasks))
  end

  def test_mentoring_model_milestones_update_due_date_filter_mode_with_target_user
    setup_for_update_view_mode_filter
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    member = @group.members.to_a.first
    task1 = create_mentoring_model_task(milestone_id: milestone1.id)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today + 10.days, user: member)

    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, target_user_id: member.id, target_user_type: GroupsController::TargetUserType::INDIVIDUAL}
    assert_response :success
    assert_equal MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, assigns(:view_mode)
    assert_equal [task2], assigns(:mentoring_model_tasks)
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_MILESTONES, target_user_type: GroupsController::TargetUserType::UNASSIGNED}
    assert_response :success
    assert_equal GroupsController::TargetUserType::UNASSIGNED, assigns(:target_user_type)
  end

  def test_groups_view_title
    current_user_is :f_admin
    program = programs(:albers)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::INACTIVE_CONNECTIONS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Connections with no recent activity", abstract_view_id: view.id)

    get :index, params: { :metric_id => metric.id}
    assert_response :success

    assert_not_nil assigns(:metric)
    assert_page_title(metric.title)
  end

  def test_update_view_mode_filter_milestone_due_date_view
    setup_for_update_view_mode_filter
    @group.allow_manage_mm_milestones!(@program.roles.for_mentoring_models)
    @group.meetings.destroy_all
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    task11 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: @group.published_at + 10.days, position: 0)
    task12 = create_mentoring_model_task(milestone_id: milestone1.id, required: false, position: 1)
    task21 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: @group.published_at + 5.days, position: 0)
    task22 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: @group.published_at + 15.days, position: 1)
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE}
    assert_response :success
    assert_equal([task21, task11, task22, task12], assigns(:mentoring_model_tasks))
  end

  def test_update_view_mode_filter_tasks_normal_view
    setup_for_update_view_mode_filter
    @group.meetings.destroy_all
    task1 = create_mentoring_model_task(required: true, due_date: @group.published_at + 5.days, position: 0)
    task2 = create_mentoring_model_task(required: false, position: 1)
    task3 = create_mentoring_model_task(required: true, due_date: @group.published_at + 10.days, position: 2)
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_MILESTONES}
    assert_response :success
    assert_equal([task1, task2, task3], assigns(:mentoring_model_tasks))
  end

  def test_update_view_mode_filter_tasks_due_date_view
    setup_for_update_view_mode_filter
    @group.meetings.destroy_all
    task1 = create_mentoring_model_task(required: true, due_date: @group.published_at + 5.days, position: 0)
    task2 = create_mentoring_model_task(required: false, position: 1)
    task3 = create_mentoring_model_task(required: true, due_date: @group.published_at + 10.days, position: 2)
    get :update_view_mode_filter, xhr: true, params: { id: @group.id, view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE}
    assert_response :success
    assert_equal([task1, task3, task2], assigns(:mentoring_model_tasks))
  end

  def test_should_not_show_mentoring_tip_for_student
    current_user_is users(:mkr_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success

    assert_select 'html' do
      assert_no_select 'div#mentoring_area_tips'
    end
    assert_nil assigns(:random_tip)
  end

  def test_should_show_end_notice_when_mentoring_period_is_about_to_end
    group_setup

    Timecop.freeze(Time.now.beginning_of_day) do
      Group.skip_timestamping do
        @group.expiry_time = (Time.now + 3.days)
        @group.save!
      end
      @group.reload
      assert @group.about_to_expire?
      assert_false @group.expired?

      @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
      current_user_is @mentor
      get :show, params: { id: @group.id}
      assert_response :success
      assert_false assigns(:is_admin_view)
      assert_select 'div#group_notice_message', text: /The mentoring connection comes to an end in 3 days(.|\n)*Contact Administrator.*to extend the duration of your mentoring connection./
      assert_feedback_link_present
    end
  end

  def test_index_for_no_milestones_when_feature_disabled
    current_user_is :student_3
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:group_3).id}

    assert_nil assigns(:connection_milestones)
  end

  def test_should_show_ended_notice_when_mentoring_period_has_ended
    group_setup
    current_user_is @mentor

    Group.skip_timestamping do
      Timecop.travel(20.days.ago)
      @group.expiry_time = 10.days.from_now
      @group.save!
      Timecop.return
    end
    @group.reload
    assert(@group.expired?)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}
    assert_response :success
    assert !assigns(:is_admin_view)
    assert_select 'html' do
      assert_select 'div#group_notice_message', :text => /The mentoring connection has ended(.|\n)*Contact Administrator.*to extend the duration of your mentoring connection./
    end

    assert_feedback_link_present
  end

  def test_should_show_recently_reactivated_notice
    group_setup
    current_user_is @mentor

    ra = RecentActivity.create!(
      :programs => [@group.program],
      :ref_obj => @group,
      :action_type => RecentActivityConstants::Type::GROUP_REACTIVATION,
      :member => @mentor.member,
      :target => RecentActivityConstants::Target::ALL)

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD + 1.hour)
    assert @group.recently_reactivated?
    assert @group.active?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}
    assert_response :success
    assert !assigns(:is_admin_view)
    assert_select 'html' do
      assert_select 'div#group_notice_message', :text => /The mentoring connection was recently reactivated. This mentoring connection ends in/
    end
  end

  def test_show_backlink_groups_show_page_admin
    current_user_is :f_admin
    session[:last_visit_url] = "/p/albers/groups"
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { :id => groups(:mygroup).id}
    back_link = {link: "/p/albers/groups"}
    assert_equal back_link, assigns[:back_link]
  end

  def test_show_backlink_groups_show_page_mentor
    current_user_is :f_mentor
    session[:last_visit_url] = "/p/albers/groups"
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    back_link = {link: "/p/albers/groups"}
    assert_equal back_link, assigns[:back_link]
  end

  def test_show_backlink_groups_show_page_mentee
    current_user_is :mkr_student
    session[:last_visit_url] = "/p/albers/groups"
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    back_link = {link: "/p/albers/groups"}
    assert_equal back_link, assigns[:back_link]
  end

  def test_should_show_recently_changed_expiry_date_notice
    group_setup
    current_user_is @mentor

    ra = RecentActivity.create!(
      :programs => [@group.program],
      :ref_obj => @group,
      :action_type => RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
      :member => @mentor.member,
      :target => RecentActivityConstants::Target::ALL)

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD + 1.hour)
    assert @group.recently_expiry_date_changed?
    assert @group.active?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}
    assert_response :success
    assert !assigns(:is_admin_view)
    assert_select 'html' do
      assert_select 'div#group_notice_message', :text => /The duration of this mentoring connection was recently changed. This mentoring connection ends in/
    end
  end

  def test_activation_renders_feedback_response_form
    group_setup
    current_user_is @user
    @group.update_attribute :status, Group::Status::INACTIVE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id, :activation => 1}
    assert_response :success
    feedback_response = assigns(:feedback_response)
    assert_equal programs(:albers).feedback_survey, feedback_response.survey
  end

  def test_activation_form_does_not_render_if_active
    group_setup
    current_user_is @user
    assert_equal Group::Status::ACTIVE, @group.status
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id, :activation => 1}
    assert_response :success
    assert !assigns(:activation)
    feedback_response = assigns(:feedback_response)
    assert_equal programs(:albers).feedback_survey, feedback_response.survey
  end

  def test_should_show_group_for_student
    group_setup
    current_user_is @user
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    assert_difference 'RecentActivity.count' do
      get :show, params: { :id => @group.id}
    end

    act = RecentActivity.last
    assert_equal RecentActivityConstants::Type::VISIT_MENTORING_AREA, act.action_type
    assert_equal RecentActivityConstants::Target::NONE, act.target
    assert_equal @group, act.ref_obj
    assert_equal @user, act.get_user(@group.program)

    assert_response :success
    assert !assigns(:is_admin_view)
    assert_feedback_link_present

    assert_nil assigns(:random_tip)
  end

  def test_show_confidentiality_warning_to_non_member_admin
    current_user_is :f_admin
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id, :created_at => 2.minutes.ago)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    assert_no_difference 'RecentActivity.count' do
      get :show, params: { :id => groups(:mygroup).id}
    end

    assert_response :success
    assert assigns(:is_admin_view)
  end

  def test_show_confidentiality_lock_icon_when_enabled_at_track_level
    current_user_is :f_admin
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
    programs(:albers).save!
    programs(:albers).reload
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id, :created_at => 2.minutes.ago)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    assert_no_difference 'RecentActivity.count' do
      get :show, params: { :id => groups(:mygroup).id}
    end

    assert_response :success
    assert assigns(:is_admin_view)
  end

  def test_show_confidentiality_lock_icon_when_disabled_at_track_level
    current_user_is :f_admin
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is a reason", :group_id => groups(:mygroup).id, :created_at => 2.minutes.ago)
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
    programs(:albers).save!
    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    assert_no_difference 'RecentActivity.count' do
      get :show, params: { :id => groups(:mygroup).id}
    end

    assert_response :success
    assert assigns(:is_admin_view)
  end

  def test_dont_show_confidentiality_warning_to_member
    current_user_is users(:mkr_student)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert !assigns(:is_admin_view)
    assert_select 'html' do
      assert_no_select "div.warning_flash span.notice_msg img#lock"
    end
  end

  def test_mentor_is_inactive_in_group
    current_user_is :f_mentor
    users(:mkr_student).delete!
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert !assigns(:is_admin_view)
    assert_match "#{users(:mkr_student).name} is currently inactive", flash[:warning]
  end

  def test_should_show_group_for_mentor
    current_user_is :f_mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    assert_difference 'RecentActivity.count' do
      get :show, params: { :id => groups(:mygroup).id}
    end

    act = RecentActivity.last
    assert_equal RecentActivityConstants::Type::VISIT_MENTORING_AREA, act.action_type
    assert_equal RecentActivityConstants::Target::NONE, act.target
    assert_equal groups(:mygroup), act.ref_obj
    assert_equal users(:f_mentor), act.get_user(groups(:mygroup).program)

    assert_response :success
    assert !assigns(:is_admin_view)
    assert_feedback_link_present
    assert_nil assigns(:random_tip)
  end

  def test_show_raised_permission_denied_error_for_non_member
    current_user_is :rahim

    # ram is not a member of the group.
    assert !groups(:mygroup).has_member?(users(:ram))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    assert_permission_denied { get :show, params: { :id => groups(:mygroup).id }}
  end

  def test_should_show_group_to_privileged_user
    current_program_is :albers
    role = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME)
    add_role_permission(role, 'manage_connections')
    student_user = users(:f_student)

    current_user_is student_user

    assert student_user.can_manage_connections?
    programs(:albers).confidentiality_audit_logs.create!(
      :user => student_user, :reason => "This is a reason", :group_id => groups(:mygroup).id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert assigns(:is_admin_view)

    assert_no_feedback_link_present
  end

  def test_should_show_group_to_admin_with_inactive_audit_log
    current_user_is :f_admin
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
    programs(:albers).save!
    programs(:albers).reload
    programs(:albers).confidentiality_audit_logs.create!(
      :user_id => users(:f_admin).id, :reason =>"This is a reason",
      :group_id => groups(:mygroup).id, :created_at => 1.day.ago)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { :id => groups(:mygroup).id}
    assert_redirected_to  new_confidentiality_audit_log_path(:group_id => groups(:mygroup).id)
  end

  def test_should_show_group_to_admin_without_any_audit_log
    current_user_is :f_admin
    programs(:albers).admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
    programs(:albers).save!
    programs(:albers).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { :id => groups(:mygroup).id}
    assert_redirected_to  new_confidentiality_audit_log_path(:group_id => groups(:mygroup).id)
  end

  def test_dont_show_actions_for_closed_group
    group_setup
    @group.terminate!(users(:f_admin), "Test reason", @group.program.permitted_closure_reasons.first.id)

    current_user_is @mentor
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { id: @group.id}
    
    assert_response :success
    assert_select 'html' do
      assert_no_select 'a.action'
    end
  end

  def test_dont_show_form_for_closed_group
    current_user_is :f_mentor
    groups(:mygroup).terminate!(users(:f_admin), "Test reason", groups(:mygroup).program.permitted_closure_reasons.first.id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert_select 'html' do
      assert_no_select '#new_common_item'
    end
  end

  def test_should_not_show_skype_buttons_to_student_when_feature_disabled
    group_setup
    current_user_is users(:f_mentor)
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)

    @group.students << users(:student_2)
    create_skype_answer(RoleConstants::MENTOR_NAME, "self_id", @mentor)
    # Self skype button should not be shown.
    create_skype_answer(RoleConstants::STUDENT_NAME, "stu_1_id", @user)
    # Other students' skype buttons should also not be shown when feature is disabled.
    create_skype_answer(RoleConstants::STUDENT_NAME, "stu_2_id", users(:student_2))
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}

    assert_response :success
    assert_select "div#SkypeButton_Call_self_id", :count => 0
    assert_select "div#SkypeButton_Call_stu_1_id", :count => 0
  end

  def test_should_not_show_skype_buttons_to_mentor_when_feature_disabled
    group_setup
    current_user_is users(:mkr_student)
    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)

    @group.students << users(:student_2)
    create_skype_answer(RoleConstants::MENTOR_NAME, "mentor_id", @mentor)
    create_skype_answer(RoleConstants::STUDENT_NAME, "self_id", @user)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert_select "div#SkypeButton_Call_self_id", :count => 0
    assert_select "div#SkypeButton_Call_mentor_id", :count => 0
  end

  def test_more_activities
    current_user_is users(:f_mentor)

    mock_1 = mock()
    mock_2 = mock()
    mock_3 = mock()

    Group.any_instance.expects(:activities).at_least(0).returns(mock_1)
    mock_1.expects(:for_display).at_least(0).returns(mock_2)
    mock_2.expects(:latest_first).at_least(0).returns(mock_3)
    mock_3.expects(:fetch_with_offset).with(20, 5, {:include => [:ref_obj, :member]}).at_least(0).returns([])

    get :more_activities, xhr: true, params: { :id => groups(:mygroup).id, :offset_id => 5}
    assert_response :success
    assert_equal 5, assigns(:offset_id)
    assert_equal 25, assigns(:new_offset_id)
  end

  def test_groups_listing_active_filter_should_consider_last_member_activity_at_for_manage_view
    g1 = groups(:group_2)
    g2 = groups(:group_3)

    assert g1.last_activity_at < g2.last_activity_at
    assert g1.last_member_activity_at > g2.last_member_activity_at

    current_user_is :f_admin

    get :index, params: { :sort => 'active'}
    assert_response :success
    assert_false assigns(:is_my_connections_view)
    assert_equal 6, assigns(:groups).size
    assert assigns(:groups).index(g1) < assigns(:groups).index(g2)
  end

  def test_groups_listing_active_filter_should_consider_last_activity_at_for_my_connections_view
    g1 = groups(:group_2)
    g2 = groups(:group_3)

    assert g1.last_activity_at < g2.last_activity_at
    assert g1.last_member_activity_at > g2.last_member_activity_at

    current_user_is :not_requestable_mentor

    get :index, params: { :show => 'my'}
    assert_response :success
    assert assigns(:is_my_connections_view)
    assert_equal 2, assigns(:groups).size
    assert assigns(:groups).index(g1) > assigns(:groups).index(g2)
  end

  def test_whether_user_has_left_and_group_closed
    g1 = groups(:group_5)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    current_user_is g1.members.first
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).never
    get :leave_connection, params: { :id => g1.id, :group => {:termination_reason => "Sample Reason", closure_reason: g1.get_auto_terminate_reason_id}}
    assert_redirected_to program_root_path
    assert assigns(:group).closed?
  end

  def test_mentee_leave_connection_one_mentee
    u1 = users(:psg_student1)
    u2 = users(:psg_student2)
    u3 = users(:psg_student3)
    g1 = groups(:multi_group)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    current_user_is :psg_student1
    assert_equal 6, g1.memberships.size
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).once

    get :leave_connection, params: { :id => g1.id, :group => { :leaving_reason => "I didn't like it"}}
    assert_redirected_to program_root_path
    assert_false g1.closed?
    assert_false g1.memberships.collect(&:user).include?(u1)
    assert_equal 5, g1.memberships.size
  end

  def test_mentee_leave_connection_second_mentee
    u1 = users(:psg_student1)
    u2 = users(:psg_student2)
    u3 = users(:psg_student3)
    g1 = groups(:multi_group)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    g1.memberships.where(:user_id => u1.id).first.destroy
    current_user_is :psg_student2
    assert_equal 5, g1.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).once
    get :leave_connection, params: { :id => g1.id, :group => {:leaving_reason => "I didn't like it"}}
    assert_redirected_to program_root_path
    assert_false g1.closed?
    assert_false g1.memberships.collect(&:user).include?(u2)
    assert_equal 4, g1.memberships.size
  end

  def test_mentee_leave_connection_third_mentee
    u1 = users(:psg_student1)
    u2 = users(:psg_student2)
    u3 = users(:psg_student3)
    g1 = groups(:multi_group)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    g1.memberships.where(:user_id => u1.id).first.destroy
    g1.memberships.where(:user_id => u2.id).first.destroy
    current_user_is :psg_student3
    assert_equal 4, g1.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).never
    get :leave_connection, params: { :id => g1.id, :group => {:termination_reason => "I didn't like it", closure_reason: g1.get_auto_terminate_reason_id}}
    assert_redirected_to program_root_path
    assert assigns(:group).closed?
  end

  def test_mentee_leave_connection_one_mentor
    u1 = users(:psg_mentor1)
    u2 = users(:psg_mentor2)
    u3 = users(:psg_mentor3)
    g1 = groups(:multi_group)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    current_user_is :psg_mentor1
    assert_equal 6, g1.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).once
    get :leave_connection, params: { :id => g1.id, :group => {:leaving_reason => "I didn't like it"}}
    assert_redirected_to program_root_path
    assert_false g1.closed?
    assert_false g1.memberships.collect(&:user).include?(u1)
    assert_equal 5, g1.memberships.size
  end

  def test_mentee_leave_connection_second_mentor
    u1 = users(:psg_mentor1)
    u2 = users(:psg_mentor2)
    u3 = users(:psg_mentor3)
    g1 = groups(:multi_group)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    g1.memberships.where(:user_id => u1.id).first.destroy
    current_user_is :psg_mentor2
    assert_equal 5, g1.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).once
    get :leave_connection, params: { :id => g1.id, :group => {:leaving_reason => "I didn't like it"}}
    assert_redirected_to program_root_path
    assert_false g1.closed?
    assert_false g1.memberships.collect(&:user).include?(u2)
    assert_equal 4, g1.memberships.size
  end

  def test_mentee_leave_connection_third_mentor
    u1 = users(:psg_mentor1)
    u2 = users(:psg_mentor2)
    u3 = users(:psg_mentor3)
    g1 = groups(:multi_group)
    program = g1.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    g1.memberships.where(:user_id => u1.id).first.destroy
    g1.memberships.where(:user_id => u2.id).first.destroy
    current_user_is :psg_mentor3
    assert_equal 4, g1.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).once
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).never
    get :leave_connection, params: { :id => g1.id, :group => {:termination_reason => "I didn't like it", closure_reason: g1.get_auto_terminate_reason_id}}
    assert_redirected_to program_root_path
    assert assigns(:group).closed?
  end

  def test_user_leave_available_connection_in_pbe_should_send_notification_to_owner
    g = groups(:group_pbe_0)
    o = users(:pbe_mentor_0)
    u = users(:pbe_student_0)
    assert g.has_member?(o)
    make_user_owner_of_group(g, o)
    assert g.has_member?(u)
    assert_equal 1, g.owners.size
    program = g.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    current_user_is :pbe_student_0
    assert_equal 3, g.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).once
    assert_difference 'PendingNotification.count' do
      get :leave_connection, params: { :id => g.id, :group => { :leaving_reason => "I didn't like it"}}
    end
    assert_redirected_to program_root_path
    assert_false g.closed?
    assert_false g.memberships.collect(&:user).include?(u)
    assert_equal 2, g.memberships.size
  end

  def test_last_user_leave_available_connection_in_pbe_should_not_terminate_group
    g = create_group(:mentors => [users(:f_mentor_pbe)], :students => [], :program => programs(:pbe), :status => Group::Status::PENDING )
    u = users(:f_mentor_pbe)
    assert g.has_member?(u)
    program = g.program
    program.update_attributes!(:allow_users_to_leave_connection => true)
    current_user_is :f_mentor_pbe
    assert_equal 1, g.memberships.size

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).once
    get :leave_connection, params: { :id => g.id, :group => { :leaving_reason => "I didn't like it"}}
    assert_redirected_to program_root_path
    assert_false g.closed?
    assert_false g.memberships.collect(&:user).include?(u)
    assert_equal 0, g.memberships.size
  end

  def test_leave_connection_popup
    group = groups(:multi_group)
    program = group.program
    program.update_attributes!(:allow_users_to_leave_connection => true)


    current_user_is :psg_mentor3
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).never
    get :leave_connection, xhr: true, params: { :id => groups(:multi_group).id}
    assert_template partial: '_closure_reason_form_fields'
    assert_response :success
  end

  def test_leave_connection_check_if_enabled
    current_user_is :f_admin
    group = groups(:mygroup)
    program = group.program
    program.update_attributes!(:allow_users_to_leave_connection => false)
    # ram is not a member of the group.
    assert_false program.allow_users_to_leave_connection?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::LEAVE_CONNECTION).never
    assert_permission_denied  do
      get :leave_connection, params: { :id => groups(:mygroup).id}
    end
  end

  def test_mentor_cannot_create_meeting_if_calendar_disable
    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success

    assert_false assigns(:can_current_user_create_meeting)
  end

  def test_mentor_can_create_meeting
    org = programs(:org_primary)
    org.enable_feature(FeatureName::CALENDAR, true)

    current_user_is users(:f_mentor)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
  end

  def test_mentor_cannot_create_meeting
    org = programs(:org_primary)

    current_user_is users(:f_mentor)
    org.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert assigns(:new_meeting).blank?
  end

  def test_mentor_can_create_meeting_with_group_meeting_enabled
    org = programs(:org_primary)

    current_user_is users(:f_mentor)
    org.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success
    assert assigns(:new_meeting).present?
  end

  def test_fetch_notes_permission_denied
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert_permission_denied do
      get :fetch_notes, xhr: true, params: { :id => group.id}
    end
  end

  def test_fetch_notes
    current_user_is :f_admin
    group = groups(:mygroup)
    get :fetch_notes, xhr: true, params: { :id => group.id, src: "profile"}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal "profile", assigns(:source)
  end

  def test_update_notes_permission_denied
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert_permission_denied do
      put :update_notes, xhr: true, params: { :id => group.id, :group => {:notes => "Test Notes"}}
    end
    assert_nil group.reload.notes
  end

  def test_update_notes
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    current_user_is :f_admin
    group = groups(:mygroup)

    put :update_notes, xhr: true, params: { :id => group.id, :group => {:notes => "Test Notes"}, src: "profile"}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal "Test Notes", group.reload.notes
    assert_equal "profile", assigns(:source)
    assert_false assigns(:mentoring_model_v2_enabled)
  end

  def test_update_notes_with_v2_enabled
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group = groups(:mygroup)
    put :update_notes, xhr: true, params: { :id => group.id, :group => {:notes => "Test Notes"}}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal "Test Notes", group.reload.notes
    assert assigns(:mentoring_model_v2_enabled)
  end

  def test_update_expiry_date
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = group.expiry_time + 4.months
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EXTEND_MENTORING_SESSION).never
    put :update_expiry_date, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Update Mentoring Period"}
    assert_response :success
    assert_nil assigns(:error_flash)
    assert_equal new_expiry_date, group.reload.expiry_time
  end

  def test_update_expiry_date_today
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = Date.today
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EXTEND_MENTORING_SESSION).never
    put :update_expiry_date, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Update Mentoring Period"}
    assert_response :success
    assert_nil assigns(:error_flash)
    assert_equal new_expiry_date.to_date.end_of_day.to_s, group.reload.expiry_time.to_s
  end

  def test_update_expiry_date_error
    current_user_is :f_admin
    group = groups(:mygroup)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EXTEND_MENTORING_SESSION).never
    put :update_expiry_date, xhr: true, params: { :id => group.id, :mentoring_period => 2.days.ago.to_date, :revoking_reason => ""}
  end

  def test_update_expiry_date_today_by_member
    current_user_is :f_mentor
    group = groups(:mygroup)

    new_expiry_date = Date.today
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::EXTEND_MENTORING_SESSION).once
    put :update_expiry_date, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Update Mentoring Period"}
    assert_response :success
    assert_nil assigns(:error_flash)
    assert_equal new_expiry_date.to_date.end_of_day.to_s, group.reload.expiry_time.to_s
  end

  def test_reactivate
    current_user_is :f_admin
    group = groups(:group_4)

    new_expiry_date = group.expiry_time + 4.months
    put :reactivate, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Reactivate"}
    assert_response :success
    assert_nil assigns(:error_flash)
    assert_equal new_expiry_date, group.reload.expiry_time
  end

  def test_reactivate_not_allowed_if_connection_already_exists
    group = groups(:group_4)
    mentor_user = users(:requestable_mentor)
    mentor_user.update_attribute(:max_connections_limit, 5)
    student_user = users(:student_4)
    create_group(name: "Claire Underwood", mentors: [mentor_user], students: [student_user], program: programs(:albers), status: Group::Status::ACTIVE)
    new_expiry_date = group.expiry_time + 4.months

    current_user_is :f_admin
    put :reactivate, xhr: true, params: { id: group.id, mentoring_period: new_expiry_date, revoking_reason: "Want to Reactivate"}
    assert_equal "Requestable mentor is already a mentor to student_e example", assigns(:error_flash)
    assert_not_equal new_expiry_date, group.reload.expiry_time
  end

  def test_reactivate_non_admin_owner
    current_user_is :f_mentor
    group = groups(:mygroup)
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).once
    post :destroy, xhr: true, params: { :group => {:termination_reason => "Test reason", closure_reason: groups(:mygroup).get_auto_terminate_reason_id}, :id => groups(:mygroup).id}

    group = groups(:mygroup).reload
    assert_false group.active?
    assert_equal "Test reason", group.termination_reason
    assert_equal users(:f_mentor), group.closed_by
    assert_not_nil group.closed_at
  end

  def test_reactivate_non_admin_owner_after_4_months
    current_user_is :requestable_mentor
    group = groups(:group_4)
    groups(:group_4).membership_of(users(:requestable_mentor)).update_attributes!(owner: true)

    new_expiry_date = group.expiry_time + 4.months
    put :reactivate, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Reactivate"}
    assert_response :success
    assert_nil assigns(:error_flash)
    assert_equal new_expiry_date, group.reload.expiry_time
  end

  def test_reactivate_for_reactivate_group_permission
    current_user_is :requestable_mentor
    program = programs(:albers)
    group = groups(:group_4)
    program.add_role_permission("mentor", "reactivate_groups")

    new_expiry_date = group.expiry_time + 4.months
    put :reactivate, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Reactivate"}
    assert_response :success
    assert_nil assigns(:error_flash)
    assert_equal new_expiry_date, group.reload.expiry_time
  end

  def test_reactivate_redirection_for_notice
    current_user_is :requestable_mentor
    program = programs(:albers)
    group = groups(:group_4)
    program.add_role_permission("mentor", "reactivate_groups")

    new_expiry_date = group.expiry_time + 4.months
    put :reactivate, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Reactivate", src: "notice"}
    assert_nil assigns(:error_flash)
    assert_equal "The mentoring connection has been reactivated. Users of the mentoring connection will be notified.", flash[:notice]
    assert_redirected_to group_path(group)
  end

  def test_reactivate_permission_denied_for_mentor
    current_user_is :requestable_mentor
    program = programs(:albers)
    group = groups(:group_4)
    assert_false program.has_role_permission?("mentor", "reactivate_groups")
    new_expiry_date = group.expiry_time + 4.months
    assert_permission_denied do
      put :reactivate, xhr: true, params: { :id => group.id, :mentoring_period => new_expiry_date, :revoking_reason => "Want to Reactivate"}
    end
  end

  def test_set_expiry_date_non_admin
    current_user_is :f_mentor
    group = groups(:mygroup)
    get :set_expiry_date, xhr: true, params: { :id => group.id}
    assert_response :success
    assert_equal group, assigns(:group)
  end

  def test_set_expiry_date_admin
    current_user_is :f_admin
    group = groups(:mygroup)
    get :set_expiry_date, xhr: true, params: { :id => group.id}
    assert_response :success
    assert_equal group, assigns(:group)
  end

  def test_fetch_reactivate_non_admin
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert_permission_denied do
      get :fetch_reactivate, xhr: true, params: { :id => group.id}
    end
  end

  def test_fetch_reactivate_non_admin_owner
    current_user_is :f_mentor
    group = groups(:mygroup)
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CLOSE_CONNECTION).once
    post :destroy, xhr: true, params: { :group => {:termination_reason => "Test reason", closure_reason: groups(:mygroup).get_auto_terminate_reason_id}, :id => groups(:mygroup).id}

    group = groups(:mygroup).reload
    assert_false group.active?
    assert_equal "Test reason", group.termination_reason
    assert_equal users(:f_mentor), group.closed_by
    assert_not_nil group.closed_at

    get :fetch_reactivate, xhr: true, params: { :id => group.id}

    assert_response :success
    assert_equal group, assigns(:group)
  end

  def test_fetch_reactivate_admin
    current_user_is :f_admin
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    group = groups(:mygroup)
    Group.any_instance.stubs(:closed?).returns(true)
    get :fetch_reactivate, xhr: true, params: { :id => group.id}
    assert_response :success
    assert_match GroupReactivationNotification.mailer_attributes[:uid], @response.body
    assert_equal group, assigns(:group)
    assert_equal ({}), assigns(:inconsistent_roles)
    group_mentor = users(:f_mentor)
    group_mentor.role_names = [RoleConstants::STUDENT_NAME]
    group_mentor.save
    get :fetch_reactivate, xhr: true, params: { :id => group.id}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal ({program_roles[RoleConstants::MENTOR_NAME].first => [group_mentor]}), assigns(:inconsistent_roles)
    group_student = users(:mkr_student)
    group_student.role_names = [RoleConstants::MENTOR_NAME]
    group_student.save
    get :fetch_reactivate, xhr: true, params: { :id => group.id}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal ({program_roles[RoleConstants::MENTOR_NAME].first => [group_mentor], program_roles[RoleConstants::STUDENT_NAME].first => [group_student]}), assigns(:inconsistent_roles)
  end

  def test_fetch_reactivate_with_reactivate_group_permission
    current_user_is :requestable_mentor
    program = programs(:albers)
    group = groups(:group_4)
    program.add_role_permission("mentor", "reactivate_groups")

    get :fetch_reactivate, xhr: true, params: { :id => group.id, src: "listing"}
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal "listing", assigns(:source)
  end

  def test_fetch_reactivate_redirect_unless_xhr
    current_user_is :requestable_mentor
    program = programs(:albers)
    group = groups(:group_4)
    program.add_role_permission("mentor", "reactivate_groups")

    get :fetch_reactivate, params: { :id => group.id, src: "listing"}
    assert_equal group, assigns(:group)
    assert_equal "listing", assigns(:source)
    assert_redirected_to groups_path(reactivate_group_id: group.id, tab: Group::Status::CLOSED, src: "listing")
  end

  def test_fetch_terminate_non_admin
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert_permission_denied do
      get :fetch_terminate, xhr: true, params: { :id => group.id}
    end
  end

  def test_fetch_terminate_owner
    current_user_is :f_mentor
    group = groups(:mygroup)
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)

    assert users(:f_mentor).can_manage_or_own_group?(group)
    assert_false users(:f_mentor).can_manage_connections?

    get :fetch_terminate, xhr: true, params: { :id => group.id}
    assert_template partial: '_closure_reason_form_fields'

    assert_equal group, assigns(:group)
    assert_response :success
  end

  def test_fetch_terminate_admin
    current_user_is :f_admin
    group = groups(:mygroup)
    get :fetch_terminate, xhr: true, params: { :id => group.id}
    assert_response :success
    assert_match GroupTerminationNotification.mailer_attributes[:uid], @response.body
    assert_equal group, assigns(:group)
  end

  def test_fetch_bulk_actions_set_expiry_date
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = group.expiry_time + 4.months
    get :fetch_bulk_actions, xhr: true, params: { :bulk_action => {:action_type => Group::BulkAction::SET_EXPIRY_DATE, :group_ids => [groups(:mygroup).id]}}
    assert_response :success
    assert_equal "#{Group::BulkAction::SET_EXPIRY_DATE}", assigns(:action_type)
    assert_equal ["#{groups(:mygroup).id}"], assigns(:group_ids)
    assert_equal [groups(:mygroup)], assigns(:groups)
  end

  def test_fetch_bulk_actions_discard
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = group.expiry_time + 4.months
    get :fetch_bulk_actions, xhr: true, params: { :bulk_action => {:action_type => Group::BulkAction::DISCARD, :group_ids => [groups(:mygroup).id]}}
    assert_response :success
    assert_equal "#{Group::BulkAction::DISCARD}", assigns(:action_type)
    assert_equal ["#{groups(:mygroup).id}"], assigns(:group_ids)
    assert_equal [groups(:mygroup)], assigns(:groups)
  end

  def test_fetch_bulk_actions_terminate
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = group.expiry_time + 4.months
    get :fetch_bulk_actions, xhr: true, params: { :bulk_action => {:action_type => Group::BulkAction::TERMINATE, :group_ids => [groups(:mygroup).id]}}
    assert_response :success
    assert_match GroupTerminationNotification.mailer_attributes[:uid], @response.body
    assert_equal "#{Group::BulkAction::TERMINATE}", assigns(:action_type)
    assert_equal ["#{groups(:mygroup).id}"], assigns(:group_ids)
    assert_equal [groups(:mygroup)], assigns(:groups)
  end

  def test_fetch_bulk_actions_export
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = group.expiry_time + 4.months
    get :fetch_bulk_actions, xhr: true, params: { :bulk_action => {:action_type => Group::BulkAction::EXPORT, :group_ids => [groups(:mygroup).id], :tab_number => Group::Status::ACTIVE}}
    assert_response :success
    assert_equal "#{Group::BulkAction::EXPORT}", assigns(:action_type)
    assert_equal ["#{groups(:mygroup).id}"], assigns(:group_ids)
    assert_equal Group::Status::ACTIVE, assigns(:tab_number)
    assert_equal [groups(:mygroup)], assigns(:groups)
  end

  def test_update_bulk_actions_set_expiry_date
    current_user_is :f_admin
    group = groups(:mygroup)

    new_expiry_date = group.expiry_time + 4.months
    member_size = groups(:mygroup).members.size + groups(:group_2).members.size
    assert_difference 'PendingNotification.count', member_size do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:action_type => Group::BulkAction::SET_EXPIRY_DATE, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" "), :mentoring_period => new_expiry_date, :reason => "Testing Expiry date"}}
    end
    assert_response :success
    assert_equal "#{Group::BulkAction::SET_EXPIRY_DATE}", assigns(:action_type)
    assert_equal_unordered ["#{groups(:mygroup).id}", "#{groups(:group_2).id}"], assigns(:group_ids)
    assert_equal_unordered [groups(:mygroup), groups(:group_2)], assigns(:groups)
    assert_equal [], assigns(:error_flash)
    assert_equal [], assigns(:error_groups)
    assert_equal new_expiry_date, groups(:mygroup).reload.expiry_time
    assert_equal new_expiry_date, groups(:group_2).reload.expiry_time
  end

  def test_update_bulk_actions_publish
    current_user_is :f_admin

    groups(:mygroup).update_attribute(:status, Group::Status::DRAFTED)
    groups(:group_2).update_attribute(:status, Group::Status::DRAFTED)
    member_size = groups(:mygroup).members.size + groups(:group_2).members.size
    assert_emails member_size do
      assert_difference "ProgressStatus.count", 1 do
        post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::PUBLISH, group_ids: [groups(:mygroup).id, groups(:group_2).id].join(" "), message: "Testing Notes", membership_settings: {allow_join: "true"}}}
      end
    end
    assert_response :success

    assert_equal "#{Group::BulkAction::PUBLISH}", assigns(:action_type)
    assert_equal_unordered ["#{groups(:mygroup).id}", "#{groups(:group_2).id}"], assigns(:group_ids)
    assert_equal_unordered [groups(:mygroup), groups(:group_2)], assigns(:groups)
    assert_equal Group::Status::ACTIVE, groups(:mygroup).reload.status
    # Not checking the message value, as it is an attr_accessor
    assert_equal Group::Status::ACTIVE, groups(:group_2).reload.status

    progress_status = ProgressStatus.last
    assert_equal 2, progress_status.maximum
    assert_equal users(:f_admin), progress_status.ref_obj
    assert_equal ProgressStatus::For::Group::BULK_PUBLISH, progress_status.for
    assert_equal ({:error_flash=>[], :error_group_ids=>[], :redirect_path=>nil}),  progress_status.reload.details
  end

  def test_update_bulk_actions_publish_render_publish_complete
    current_user_is :f_admin

    publish_progress = ProgressStatus.create!(details: {:error_flash=>["Error Flash"], :error_group_ids=>[groups(:mygroup).id], :redirect_path=>nil}, for: ProgressStatus::For::Group::BULK_PUBLISH, maximum: 1, completed_count: 0, ref_obj: users(:f_admin))
    post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::PUBLISH, group_ids: [groups(:mygroup).id, groups(:group_2).id].join(" ") }, publish_progress_id: publish_progress.id }
    assert_response :success
    assert_equal ["Error Flash"], assigns(:error_flash)
    assert_equal [groups(:mygroup)], assigns(:error_groups)
    assert_nil publish_progress.reload.details
  end

  def test_update_bulk_actions_publish_render_publish_complete_redirect
    current_user_is :f_admin

    publish_progress_id = ProgressStatus.create!(details: {:error_flash=>[], :error_group_ids=>[], :redirect_path=> program_root_path}, for: ProgressStatus::For::Group::BULK_PUBLISH, maximum: 1, completed_count: 0, ref_obj: users(:f_admin)).id
    post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::PUBLISH, group_ids: [groups(:mygroup).id, groups(:group_2).id].join(" ") }, publish_progress_id: publish_progress_id }
    assert_equal "window.location.href = '#{Rails.application.routes.url_helpers.program_root_path}'", @response.body
  end

  def test_update_bulk_actions_discard
    current_user_is :f_admin

    assert_no_emails do
      assert_difference "Group.count", -2 do
        post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:action_type => Group::BulkAction::DISCARD, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" ")}}
      end
    end
    assert_response :success

    assert_equal "#{Group::BulkAction::DISCARD}", assigns(:action_type)
    assert_equal_unordered ["#{groups(:mygroup).id}", "#{groups(:group_2).id}"], assigns(:group_ids)
    assert_equal_unordered [groups(:mygroup), groups(:group_2)], assigns(:groups)
  end

  def test_update_bulk_actions_terminate
    current_user_is :f_admin

    member_size = groups(:mygroup).members.size + groups(:group_2).members.size
    assert_emails member_size do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:action_type => Group::BulkAction::TERMINATE, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" "), :termination_reason => "Testing Termination", closure_reason: groups(:group_2).get_auto_terminate_reason_id}}
    end
    assert_response :success

    assert_equal "#{Group::BulkAction::TERMINATE}", assigns(:action_type)
    assert_equal_unordered ["#{groups(:mygroup).id}", "#{groups(:group_2).id}"], assigns(:group_ids)
    assert_equal_unordered [groups(:mygroup), groups(:group_2)], assigns(:groups)
    assert_equal Group::Status::CLOSED, groups(:mygroup).reload.status
    assert_equal Group::Status::CLOSED, groups(:group_2).reload.status
    check_group_state_change_unit(groups(:group_2), GroupStateChange.last, Group::Status::ACTIVE)
  end

  def test_update_bulk_actions_reactivate
    current_user_is :f_admin
    group = groups(:mygroup)
    group.terminate!(users(:f_admin),"Test reason", group.program.permitted_closure_reasons.first.id)
    groups(:group_2).terminate!(users(:f_admin),"Test reason", groups(:group_2).program.permitted_closure_reasons.first.id)

    new_expiry_date = group.expiry_time + 4.months
    member_size = groups(:mygroup).members.size + groups(:group_2).members.size
    assert_emails member_size do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:action_type => Group::BulkAction::REACTIVATE, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" "), :mentoring_period => new_expiry_date, :reason => "Testing Expiry date"}}
    end
    assert_response :success

    assert_equal "#{Group::BulkAction::REACTIVATE}", assigns(:action_type)
    assert_equal_unordered ["#{groups(:mygroup).id}", "#{groups(:group_2).id}"], assigns(:group_ids)
    assert_equal_unordered [groups(:mygroup), groups(:group_2)], assigns(:groups)
    assert_equal [], assigns(:error_flash)
    assert_equal [], assigns(:error_groups)
    assert_equal Group::Status::ACTIVE, groups(:mygroup).reload.status
    assert_equal new_expiry_date, groups(:mygroup).expiry_time
    assert_equal Group::Status::ACTIVE, groups(:group_2).reload.status
    assert_equal new_expiry_date, groups(:group_2).expiry_time
    check_group_state_change_unit(groups(:group_2), GroupStateChange.last, Group::Status::CLOSED)
  end

  def test_update_bulk_actions_export
    current_user_is :f_admin
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    group_view = programs(:albers).group_view
    g1.members.second.member.update_attribute(:last_name, "madankumar'rajan")

    post :update_bulk_actions, params: { :bulk_actions => {:action_type => Group::BulkAction::EXPORT, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" "), :tab_number => Group::Status::ACTIVE}}
    assert_response :success

    assert_equal "#{Group::BulkAction::EXPORT}", assigns(:action_type)
    assert_equal Group::Status::ACTIVE, assigns(:tab_number)
    assert_equal_unordered ["#{g1.id}", "#{g2.id}"], assigns(:group_ids)
    assert_equal_unordered [g1, g2], assigns(:groups)
    assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
    csv_response = @response.body.split("\n")
    assert_equal UTF8_BOM + "Mentoring Connection Name,Notes,Started on,Last activity,Closes on,Mentor,Mentor Messages,Mentor Login Instances,Student,Student Messages,Student Login Instances", csv_response[0]
    assert_match "name & madankumarrajan", csv_response[1]
    assert_match "mkr_student madankumar'rajan", csv_response[1]
    assert_match /filename=mentoring_connections_/, @response.header["Content-Disposition"]
  end

  def test_update_bulk_actions_export_role_based_columns_pbe
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group = groups(:group_pbe_0)
    group_view = program.group_view
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    group_view_columns_count = group_view.group_view_columns.count
    xss_title = "<script> Project Based Engagement Template </script>"
    MentoringModel.where(id: group.mentoring_model.id).first.update_attributes(title: xss_title)
    GroupViewColumn::Columns::Defaults::ROLE_BASED_COLUMNS.each_with_index do |column_key, index|
      group_view.group_view_columns.create!(column_key: column_key, position: group_view_columns_count + index, ref_obj_type: GroupViewColumn::ColumnType::NONE, role_id: teacher_role_id)
    end
    group.membership_settings.create!(role_id: student_role_id, max_limit: 15)
    group.membership_settings.create!(role_id: teacher_role_id, max_limit: 5)

    post :update_bulk_actions, params: { :bulk_actions => {:action_type => Group::BulkAction::EXPORT, :group_ids => [group.id].join(" "), :tab_number => Group::Status::ACTIVE}}
    assert_response :success
    csv_response = @response.body.split("\n")
    assert_equal UTF8_BOM + "Mentoring Connection Name,Notes,Started on,Last activity,Closes on,Goals Status,Tasks Overdue,Tasks Pending,Tasks Completed,Milestones Overdue,Milestones Pending,Milestones Completed,Mentoring Connection Plan Template,No. of Survey Responses,Mentors,Mentor Meetings,Mentor Posts,Mentor Login Instances,Number of slots (Mentor),Number of slots taken (Mentor),Number of remaining slots (Mentor),Students,Student Meetings,Student Posts,Student Login Instances,Number of slots (Student),Number of slots taken (Student),Number of remaining slots (Student),Teachers,Teacher Meetings,Teacher Posts,Teacher Login Instances,Number of slots (Teacher),Number of slots taken (Teacher),Number of remaining slots (Teacher)", csv_response[0]
    assert_equal ["mentor_a chronus", "-", "0", "0", "", "1", "", "\"student_a example", " student_f example\"", "-", "0", "0", "15", "2", "13", "\"\"", "-", "0", "0", "5", "0", "5"], csv_response[1].split(",").last(22)
    assert_match xss_title, @response.body
  end

  def test_update_bulk_actions_export_xss
    current_user_is :f_admin
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    group_view = programs(:albers).group_view
    mentor_role_id = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id
    profile_question = profile_questions(:multi_education_q)
    profile_answer = profile_question.profile_answers.first
    profile_answer.educations.first.update_attributes(:school_name => '<script>Indian college </script>')
    columns_count = group_view.group_view_columns.count
    group_view.group_view_columns.create!(profile_question_id: profile_question.id, position: columns_count, ref_obj_type: GroupViewColumn::ColumnType::USER, role_id: mentor_role_id)
    post :update_bulk_actions, params: { :bulk_actions => {:action_type => Group::BulkAction::EXPORT, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" "), :tab_number => Group::Status::ACTIVE}}
    assert_response :success
    csv_response = @response.body.split("\n")

    assert_match "Mentoring Connection Name,Notes,Started on,Last activity,Closes on,Mentor,Mentor Messages,Mentor Login Instances,Student,Student Messages,Student Login Instances,Mentor - Entire Education", csv_response[0]
    assert_match "&lt;script&gt;Indian college &lt;/script&gt;", csv_response[1]
  end

  def test_pending_profile_should_not_see_flash_warning
    current_user_is :f_mentor
    users(:mkr_student).update_attribute(:state, User::Status::PENDING)
    assert_false users(:mkr_student).active?
    assert users(:mkr_student).profile_pending?
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:mygroup).id}
    assert_response :success

    assert_nil flash[:warning]
  end

  def test_assign_match_form_admin_only
    current_user_is :f_mentor
    assert_permission_denied do
      get :assign_match_form, xhr: true, params: { student_id: users(:f_student).id, mentor_id: users(:f_mentor).id}
    end
  end

  def test_assign_match_form_success
    student = users(:student_1)
    mentor = users(:mentor_1)
    assert_equal_unordered [groups(:group_5), groups(:group_inactive), groups(:drafted_group_2), groups(:drafted_group_3)], mentor.mentoring_groups

    current_user_is :f_admin
    get :assign_match_form, xhr: true, params: { student_id: student.id, mentor_id: mentor.id}
    assert_response :success
    assert_match /#{GroupCreationNotificationToMentor.mailer_attributes[:uid]}/, @response.body
    assert_match /#{GroupCreationNotificationToStudents.mailer_attributes[:uid]}/, @response.body
    assert_equal student, assigns(:student)
    assert_equal mentor, assigns(:mentor)
    assert_equal [groups(:group_inactive)], assigns(:mentor_groups)
  end

  def test_save_as_draft_admin_only
    current_user_is :f_mentor
    assert_permission_denied do
      get :save_as_draft, xhr: true, params: { student_id: "1", mentor_id: "2"}
    end
  end

  def test_save_as_draft_success
    student = users(:student_1)
    mentor = users(:mentor_1)

    current_user_is :f_admin
    get :save_as_draft, xhr: true, params: { student_id: student.id, mentor_id: mentor.id}
    assert_response :success
    assert_equal student, assigns(:student)
    assert_equal mentor, assigns(:mentor)
  end

  def test_publish_with_validation_failure
    current_user_is :f_admin
    group = groups(:drafted_group_1)

    assert_equal [users(:robert)], group.mentors
    assert_equal [users(:student_1)], group.students

    user = users(:robert)
    user.update_attributes!(:max_connections_limit => 1)
    user.reload
    assert_equal 1, user.groups.active.size

    put :publish, xhr: true, params: { id: group.id, group: {:notes  => "test", membership_settings: {allow_join: "true"}}}
    assert_equal Group::Status::DRAFTED, group.reload.status
    assert_equal 1, user.groups.active.reload.size
    assert_equal "robert user preferred not to have more than 1 students", assigns(:error_flash)
  end

  def test_update_bulk_actions_with_validation_failure
    current_user_is :f_admin
    # programs(:albers).enable_feature(FeatureName::DRAFT_CONNECTIONS, true)

    group_1 = groups(:drafted_group_1)
    assert_equal [users(:robert)], group_1.mentors
    assert_equal [users(:student_1)], group_1.students

    user_1 = users(:robert)
    user_1.update_attributes!(:max_connections_limit => 1)
    user_1.reload
    assert_equal 1, user_1.groups.active.size

    group_2 = groups(:drafted_group_2)
    assert_equal [users(:mentor_1)], group_2.mentors
    assert_equal [users(:student_3)], group_2.students

    user_2 = users(:mentor_1)
    assert_equal 2, user_2.groups.active.size

    put :update_bulk_actions, xhr: true, params: { bulk_actions: { group_ids: [group_1.id , group_2.id].join(" "), action_type: Group::BulkAction::PUBLISH, membership_settings: {allow_join: "true"} }}

    assert_equal 3, user_2.groups.active.reload.size
    assert_equal 1, user_1.groups.active.reload.size
    assert_equal Group::Status::DRAFTED, group_1.reload.status
    assert_equal Group::Status::ACTIVE, group_2.reload.status
    output_hash = ProgressStatus.last.details
    assert_equal ["robert user preferred not to have more than 1 students"], output_hash[:error_flash]
    assert_equal [group_1.id], output_hash[:error_group_ids]

     group_3 = groups(:drafted_group_3)
  end

  def test_admin_visits_other_inactive_connections
    current_user_is :f_admin
    programs(:albers).confidentiality_audit_logs.create!(:user_id => users(:f_admin).id, :reason =>"This is another reason", :group_id => groups(:group_inactive).id)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { :id => groups(:group_inactive).id}
    assert_false assigns(:is_member)
    assert_false assigns(:show_feedback_form)
  end

  def test_member_visits_inactive_connections
    current_user_is :mentor_1
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => groups(:group_inactive).id}
    assert assigns(:show_feedback_form)
  end

  def test_edit_columns_permission_denied
    current_user_is :moderated_mentor
    assert_permission_denied {  get :edit_columns, xhr: true }
  end

  def test_edit_columns_for_program_with_third_role
    current_user_is :f_admin_pbe
    current_program_is :pbe

    get :edit_columns, xhr: true, params: { :tab => Group::Status::ACTIVE, :view => Group::View::LIST}
    assert_response :success

    assert_select "div.modal-header" do
      assert_select "h4", :text => 'Select Fields to Display'
    end
    assert_match "Mentor Profile Fields", @response.body
    assert_match "Student Profile Fields", @response.body
    assert_match "Teacher Profile Fields", @response.body
  end

  def test_select_all_ids_permission_denied
    current_user_is :moderated_mentor
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_no_filter_params
    user = users(:f_admin)
    program = user.program
    closed_groups = program.groups.closed
    assert closed_groups.present?

    current_user_is user
    get :select_all_ids, params: { filter_field: Group::Status::CLOSED, tab: Group::Status::CLOSED}
    assert_response :success
    assert_equal 0, assigns(:view)
    assert_equal "#{Group::Status::CLOSED}", @request.session[:groups_tab]
    assert_equal Group::Status::CLOSED, assigns(:tab_number)
    assert_equal Group::Status::CLOSED, assigns(:with_options)[:status]
    assert_nil assigns[:with_options][:status_filter]
    assert_nil assigns(:expiry_start_time) || assigns(:closed_start_time) || assigns(:close_start_time) || assigns(:started_start_time)
    assert_nil assigns(:expiry_end_time) || assigns(:closed_end_time) || assigns(:close_end_time) || assigns(:started_end_time)
    assert_equal_unordered closed_groups.pluck(:id).map(&:to_s), JSON.parse(response.body)["group_ids"]
  end

  def test_select_all_ids_with_filter_params
    user = users(:f_admin)
    program = user.program
    time = DateTime.now.utc
    format = "date.formats.date_range".translate
    ongoing_groups = program.groups.with_status([Group::Status::ACTIVE, Group::Status::INACTIVE]).where("expiry_time < ?", time + 5.months)

    current_user_is user
    get :select_all_ids, params: { filter_field: [Group::Status::ACTIVE], sub_filter: { not_started: GroupsController::StatusFilters::NOT_STARTED, inactive: GroupsController::StatusFilters::Code::INACTIVE, active: GroupsController::StatusFilters::Code::ACTIVE },
      tab: Group::Status::ACTIVE, search_filters: { expiry_date: "#{time.strftime(format)} - #{(time + 5.months).strftime(format)}" }
    }
    assert_response :success
    assert_equal 0, assigns(:view)
    assert_equal "0", @request.session[:groups_tab]
    assert_equal 0, assigns(:tab_number)
    assert_nil assigns(:with_options)[:status]
    assert_equal true, assigns(:is_manage_connections_view)
    assert_equal true, assigns(:mentoring_model_v2_enabled)
    assert_equal true, assigns(:v2_tasks_overdue_filter)
    assert_equal [], assigns[:my_filters]
    assert_equal program.groups, assigns(:groups_scope)
    # Rails assert_equal doesn't always work with DateTimes. Hence the usage of 'to_i'.
    # Reference: http://stackoverflow.com/questions/5556726/rails-assert-equal-doesnt-always-work-with-datetimes
    assert_equal time.in_time_zone.beginning_of_day.to_i, assigns(:expiry_start_time).to_i
    assert_equal (time.in_time_zone.end_of_day + 5.months).to_i, assigns(:expiry_end_time).to_i
    assert_equal_unordered ongoing_groups.collect(&:id).map(&:to_s), JSON.parse(response.body)["group_ids"]
  end

  def test_index_with_mentoring_models
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :index, params: { search_filters: {mentoring_models: [mentoring_model.id.to_s]}}
    assert_response :success

    assert assigns(:groups).empty?
  end

  def test_index_with_v2_tasks_behind_schedule
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :index, params: { search_filters: {v2_tasks_behind_schedule: true}}
    assert_response :success

    assert assigns(:v2_tasks_overdue_filter)
  end

  def test_mentoring_models_index_page_back_link
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :index, params: { from_mentoring_models: true}
    assert_response :success

    assert assigns(:back_link).present?
    assert_equal ({:label => "Mentoring Connection Plan Templates", :link => mentoring_models_path}), assigns(:back_link)
  end

  def test_index_for_reactivate_group
    current_user_is :requestable_mentor
    program = programs(:albers)
    program.add_role_permission("mentor", "reactivate_groups")
    group_id = groups(:group_4).id
    get :index, params: { reactivate_group_id: group_id, src: "listing", tab: Group::Status::CLOSED }
    assert assigns(:reactivate_group)
  end

  def test_index_permission_denied_for_reactivate_group
    current_user_is :requestable_mentor
    group_id = groups(:group_4).id
    assert_permission_denied do
      get :index, params: { reactivate_group_id: group_id, src: "listing", tab: Group::Status::CLOSED }
    end
    assert_false assigns(:reactivate_group)
  end

  def test_fetch_bulk_actions_with_assign_template
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model1 = programs(:albers).default_mentoring_model
    mentoring_model2 = create_mentoring_model(title: "Aaron Paul - Jesse")
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :fetch_bulk_actions, xhr: true, params: { bulk_action: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [groups(:mygroup).id]}}
    assert_response :success

    assert_false assigns(:individual_action)
    assert_equal [mentoring_model2, mentoring_model1].collect{|mentoring_model| [mentoring_model.title, mentoring_model.id] }, assigns(:mentoring_models).collect{|mentoring_model| [mentoring_model.title, mentoring_model.id]}
  end

  def test_update_bulk_actions_with_assign_template_permission_denied
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    assert_permission_denied do
      post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [groups(:mygroup).id, groups(:group_2).id].join(" "), tab_number: Group::Status::DRAFTED}}
    end
  end

  def test_update_bulk_actions_with_assign_template
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [groups(:drafted_group_1).id].join(" "), tab_number: Group::Status::DRAFTED}}
    assert_response :success

    assert_equal mentoring_model, groups(:drafted_group_1).reload.mentoring_model
  end

def test_update_bulk_actions_with_assign_template_allow_forum_changed
  program = programs(:pbe)
  mentoring_model = create_mentoring_model(program_id: program.id)
  mentoring_model.update_attribute(:allow_forum, false)
  group = create_group(
    program: program,
    mentor: users(:f_mentor_pbe),
    student: users(:f_student_pbe),
    status: Group::Status::PENDING,
    mentoring_model_id: mentoring_model.id
  )
  assert_nil group.forum
  current_user_is :f_admin_pbe
  default_mentoring_model = program.default_mentoring_model
  post :update_bulk_actions, xhr: true, params: { mentoring_model: default_mentoring_model.id, bulk_actions: { action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: group.id, tab_number: Group::Status::PENDING }}
  assert_response :success
  group.reload
  assert_equal default_mentoring_model, group.mentoring_model
  assert group.forum
end

  def test_fetch_bulk_actions_with_single_group
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    get :fetch_bulk_actions, xhr: true, params: { individual_action: true, bulk_action: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [groups(:mygroup).id], tab_number: Group::Status::DRAFTED}}
    assert_response :success

    assert assigns(:individual_action)
  end

  def test_assign_from_match_with_multiple_templates
    mentor = users(:f_mentor)
    student = users(:f_student)
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = create_mentoring_model(title: "Homeland Carrie")
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    assert_emails 2 do
      assert_difference "Group.count" do
        assert_difference "Connection::Membership.count", 2 do
          post :assign_from_match, params: { mentoring_model: mentoring_model.id, student_id: student.id, mentor_id: mentor.id, group_id: "", message: "Hi"}
        end
      end
    end

    group = assigns(:group)
    assert_equal "Hi", group.message
    assert_equal [mentor], group.mentors
    assert_equal [student], group.students
    assert_equal mentoring_model, group.mentoring_model
  end

  def test_assign_from_match_default_template_for_non_multiple_templates
    mentor = users(:f_mentor)
    student = users(:f_student)
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = create_mentoring_model(title: "Homeland Carrie")
    default_mentoring_model = programs(:albers).default_mentoring_model
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    programs(:org_primary).reload

    assert_emails 2 do
      assert_difference "Group.count" do
        assert_difference "Connection::Membership.count", 2 do
          post :assign_from_match, params: { mentoring_model: mentoring_model.id, student_id: student.id, mentor_id: mentor.id, group_id: "", message: "Hi"}
        end
      end
    end

    group = assigns(:group)
    assert_equal "Hi", group.message
    assert_equal [mentor], group.mentors
    assert_equal [student], group.students
    assert_not_equal default_mentoring_model, group.mentoring_model
    assert_equal mentoring_model, group.mentoring_model
  end

  def test_assign_from_match_for_feature_disabled
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    mentor = users(:f_mentor)
    student = users(:f_student)
    current_user_is :f_admin
    current_program_is :albers
    mentoring_model = create_mentoring_model(title: "Homeland Carrie")
    default_mentoring_model = programs(:albers).default_mentoring_model

    assert_emails 2 do
      assert_difference "Group.count" do
        assert_difference "Connection::Membership.count", 2 do
          post :assign_from_match, params: { mentoring_model: mentoring_model.id, student_id: student.id, mentor_id: mentor.id, group_id: "", message: "Hi"}
        end
      end
    end

    group = assigns(:group)
    assert_equal "Hi", group.message
    assert_equal [mentor], group.mentors
    assert_equal [student], group.students
    assert_nil group.mentoring_model
  end

  def test_update_login_count_for_not_group_member
    group_setup
    current_user_is :f_admin

    assert_nil cookies[:mentoring_area_visited]
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).never
    get :show, params: { :id => groups(:mygroup).id}
    assert_nil cookies[:mentoring_area_visited]
  end

  def test_update_login_count_for_mentor
    group_setup
    current_user_is :f_mentor
    connection_membership = users(:f_mentor).connection_memberships.where(:group_id => @group.id).first

    assert_nil cookies[:mentoring_area_visited]
    assert_equal 0, connection_membership.login_count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}

    assert_equal [@group.id.to_s], cookies[:mentoring_area_visited].split(',')
    assert_equal 1, connection_membership.reload.login_count

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}

    assert_equal [@group.id.to_s], cookies[:mentoring_area_visited].split(',')
    assert_equal 1, connection_membership.reload.login_count
  end

  def test_update_login_count_for_student
    group_setup
    current_user_is :f_student
    connection_membership = users(:f_student).connection_memberships.where(:group_id => @group.id).first

    assert_nil cookies[:mentoring_area_visited]
    assert_equal 0, connection_membership.login_count
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}

    assert_equal [@group.id.to_s], cookies[:mentoring_area_visited].split(',')
    assert_equal 1, connection_membership.reload.login_count

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_MENTORING_AREA).once
    get :show, params: { :id => @group.id}

    assert_equal [@group.id.to_s], cookies[:mentoring_area_visited].split(',')
    assert_equal 1, connection_membership.reload.login_count
  end

  def test_get_activity_details_permission_denied
    group = groups(:mygroup)

    current_user_is group.members.first
    assert_permission_denied do
      get :get_activity_details, xhr: true, params: { id: group.id}
    end
  end

  def test_get_activity_details
    group = groups(:mygroup)
    group.program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, false)
    assert group.scraps_enabled?
    assert_false group.forum_enabled?
    assert_false group.meetings_enabled?

    current_user_is :f_admin
    get :get_activity_details, xhr: true, params: { id: group.id}
    assert_equal_hash( {
      users(:f_mentor).id => 0,
      users(:mkr_student).id => 0
    }, assigns(:login_activity))
    assert_equal_hash( {
      users(:f_mentor).id => 4,
      users(:mkr_student).id => 2
    }, assigns(:scraps_activity))
    assert_nil assigns(:posts_activity)
    assert_nil assigns(:meetings_activity)
    assert_nil assigns(:survey_answers)
    assert_nil assigns(:tasks_activity)
  end

  def test_get_activity_details_with_forum_and_meetings_and_tasks_and_no_surveys
    group = groups(:mygroup)
    create_mentoring_model_task
    task2 = create_mentoring_model_task
    task2.update_attributes!(status: MentoringModel::Task::Status::DONE)

    mentoring_model_roles = group.program.roles.for_mentoring_models
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    Group.any_instance.stubs(:scraps_enabled?).returns(false)
    Group.any_instance.stubs(:meetings_enabled?).returns(true)
    Group.any_instance.stubs(:can_manage_mm_tasks?).with(mentoring_model_roles).returns(true)

    current_user_is :f_admin
    get :get_activity_details, xhr: true, params: { id: group.id}
    assert_equal_hash( {
      users(:f_mentor).id => 0,
      users(:mkr_student).id => 0
    }, assigns(:login_activity))
    assert_nil assigns(:scraps_activity)
    assert_equal_hash({}, assigns(:posts_activity))
    assert_not_nil assigns(:meetings_activity)
    assert_equal_hash({}, assigns(:survey_answers))
    assert_equal_hash( {
      users(:f_mentor).id => 1,
    }, assigns(:tasks_activity))
  end

  def test_get_activity_details_with_data
    group_setup
    task1 = create_mentoring_model_task({group: @group, user: @user})
    task2 = create_mentoring_model_task({group: @group})
    task1.update_attributes!(status: MentoringModel::Task::Status::DONE)
    task2.update_attributes!(status: MentoringModel::Task::Status::DONE)

    mentoring_model_roles = @group.program.roles.for_mentoring_models
    Group.any_instance.stubs(:forum_enabled?).returns(true)
    Group.any_instance.stubs(:scraps_enabled?).returns(true)
    Group.any_instance.stubs(:meetings_enabled?).returns(true)
    Group.any_instance.stubs(:can_manage_mm_tasks?).with(mentoring_model_roles).returns(true)

    @group.create_group_forum
    topic = create_topic(forum: @group.forum, user: @mentor)
    create_post(topic: topic, user: @user)
    create_scrap(group: @group, sender: @mentor.member)
    create_meeting(start_time: 50.minutes.ago,
      end_time: 20.minutes.ago,
      group_id: @group.id,
      members: [@user.member, @mentor.member],
      owner_id: @mentor.member_id
    )
    create_engagement_survey_and_its_answers
    @user = @group.students.first
    @group.mentor_memberships.first.update_attribute(:login_count, 10)

    current_user_is :f_admin
    get :get_activity_details, xhr: true, params: { id: @group.id}
    assert_equal_hash( {
      @user.id => 0,
      @mentor.id => 10
    }, assigns(:login_activity))
    assert_equal_hash( {
      @mentor.id => 1
    }, assigns(:scraps_activity))
    assert_equal_hash( {
      @user.id => 1
    }, assigns(:posts_activity))
    assert_equal_hash( {
      @user.id => 1,
      @mentor.id => 1
    }, assigns(:meetings_activity))
    assert_equal 1, assigns(:survey_answers)[@mentor.id].size
    assert_equal_hash( {
      user_id: @mentor.id,
      group_id: @group.id,
      response_id: @response_id,
      id: nil
    }, assigns(:survey_answers)[@mentor.id].first.attributes)
    assert_equal_hash( {
      @mentor.id => 1,
      @user.id => 1
    }, assigns(:tasks_activity))
  end

  def test_remove_user_from_group_meetings_when_removed_from_group
    group = groups(:multi_group)
    current_user_is :psg_admin
    time = Time.now
    mentor = users(:psg_mentor1)
    student = users(:psg_student1)
    meeting = create_meeting(
      start_time: time,
      end_time: time + 30.minutes,
      members: [mentor.member, members(:psg_mentor2), student.member, members(:psg_student2)],
      program_id: programs(:psg).id,
      group_id: groups(:multi_group).id,
      owner_id: mentor.id
    )
    program_roles = group.program.roles.group_by(&:name)

    post :update, xhr: true, params: {
          :id => group.id,
          :connection => {
            :users => {
              student.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          }
        }
    meeting.reload
    assert_false meeting.members.collect(&:id).include?(student.id)
  end

  def test_survey_response_permission_denied_mentor
    group_setup
    current_user_is :f_mentor
    create_engagement_survey_and_its_answers
    assert_raise(Authorization::PermissionDenied) do
      get :survey_response, xhr: true, params: { id: @group.id, task_id: @task.id, user_id: @user.id, response_id: @response_id}
    end
  end

  def test_survey_response_permission_denied_student
    group_setup
    current_user_is :f_student
    create_engagement_survey_and_its_answers
    assert_raise(Authorization::PermissionDenied) do
      get :survey_response, xhr: true, params: { id: @group.id, task_id: @task.id, user_id: @user.id, response_id: @response_id}
    end
  end

  def test_survey_response
    group_setup
    current_user_is :f_admin
    create_engagement_survey_and_its_answers
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    get :survey_response, xhr: true, params: { id: @group.id, survey_id: survey.id, user_id: @user.id, response_id: @response_id}
    assert_equal_unordered survey.survey_questions, assigns(:questions)
    assert_equal @user, assigns(:user)
    answers = @group.survey_answers.select("common_answers.id, common_question_id, answer_text, common_answers.last_answered_at").index_by(&:common_question_id)
    answers.each do |key, val|
      assert_equal_hash val.attributes, assigns(:answers)[key].attributes
    end
  end

  def test_survey_response_of_removed_user
    group_setup
    current_user_is :f_admin
    create_engagement_survey_and_its_answers
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    @group.memberships.where(user_id: @user.id).first.update_column(:user_id, users(:rahim).id)
    get :survey_response, xhr: true, params: { id: @group.id, survey_id: survey.id, user_id: @user.id, response_id: @response_id}
    assert_equal_unordered survey.survey_questions, assigns(:questions)
    assert_equal @user, assigns(:user)
    answers = @group.survey_answers.select("common_answers.id, common_question_id, answer_text, common_answers.last_answered_at").index_by(&:common_question_id)
    answers.each do |key, val|
      assert_equal_hash val.attributes, assigns(:answers)[key].attributes
    end
  end

  def test_list_view_groups_index
    current_user_is :f_admin
    current_program_is :albers
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group_view = programs(:albers).group_view
    group_view.group_view_columns.create!(column_key: GroupViewColumn::Columns::Key::MENTORING_MODEL_TEMPLATES, ref_obj_type: GroupViewColumn::ColumnType::NONE, position: 11)

    get :index, xhr: true, params: { :tab => Group::Status::ACTIVE, :view => Group::View::LIST}
    assert_response :success
  end

  def test_should_show_my_connections_quick_links
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)

    group_setup
    current_user_is :f_mentor

    get :show, params: { :id => @group.id}
    assert_response :success

    assert_select "ul#quick_links" do
      assert_select 'a', :count => 1, :text => 'View Mentoring Connection Profile'
      assert_select 'a', :count => 1, :text => 'Edit Mentoring Connection Profile'
    end
  end

  def test_should_not_show_my_connection_quick_links
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE, false)
    group_setup
    current_user_is :f_mentor

    get :show, params: { :id => @group.id}
    assert_response :success

    assert_select "ul#quick_links" do
      assert_select 'a', :count => 0, :text => 'View Mentoring Connection Profile'
      assert_select 'a', :count => 0, :text => 'Edit Mentoring Connection Profile'
    end
  end

  def test_connection_question_filter
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    current_user_is :f_admin
    q1 = common_questions(:string_connection_q)
    q2 = common_questions(:multi_choice_connection_q)

    get :index, xhr: true, params: { :connection_questions => {"#{q1.id}" => "computer"}}
    assert_response :success
    assert_equal_unordered [groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)

    get :index, xhr: true, params: { :connection_questions => {"#{q1.id}" => "computer", "#{q2.id}" => [question_choices(:multi_choice_connection_q_3).id]}}
    assert_response :success
    assert_equal_unordered [groups(:mygroup)].collect(&:id), assigns(:groups).collect(&:id)
  end

  def test_connection_question_filter_different_set
    programs(:org_primary).enable_feature(FeatureName::CONNECTION_PROFILE)
    current_user_is :f_admin
    q1 = common_questions(:string_connection_q)
    q2 = common_questions(:multi_choice_connection_q)

    get :index, xhr: true, params: { :connection_questions => {"#{q1.id}" => "computer", "#{q2.id}" => [999999]}}
    assert_response :success
    assert assigns(:groups).empty?
  end

  def test_new_for_project_based_program
    current_program_is :pbe
    current_user_is :f_admin_pbe
    get :new
    assert_response :success
  end

  def test_create_for_project_based_program
    enable_project_based_engagements!
    current_user_is :f_admin
    student_role_id = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id

    Member.any_instance.stubs(:get_valid_time_zone).returns("Asia/Kolkata")

    # test with save and continue later
    assert_no_emails do
      assert_difference "Group.count" do
        post :create, params: { :group => {"name"=>"Sample Project", :membership_setting => { student_role_id.to_s => "" }, :start_date => "April 19, 2028"}, :connection_answers => {}, :save_and_continue_later => ""}
      end
    end
    assert_redirected_to groups_path(tab: Group::Status::DRAFTED)
    assert_equal "Sample Project", Group.last.name
    assert_equal "April 19, 2028".to_time.in_time_zone("Asia/Kolkata").to_date, Group.last.start_date.in_time_zone("Asia/Kolkata").to_date
    assert Group.last.drafted?
    assert Group.last.global
    assert_false Group.last.membership_settings.last
    assert_nil assigns(:existing_groups_alert)
  end

  def test_create_for_project_based_program_with_proceed_to_add_members
    current_program_is :pbe
    current_user_is :f_admin_pbe
    student_role_id = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id

    # test with proceed to add members
    assert_no_emails do
      assert_difference "Group.count" do
        post :create, params: { :group => {"name"=>"Demo Project", :membership_setting => { student_role_id.to_s => 5 }}, :connection_answers => {}, :proceed_to_add_members => ""}
      end
    end
    assert_redirected_to add_members_group_path(Group.last)
    assert_equal "Demo Project", Group.last.name
    assert Group.last.drafted?
    assert Group.last.global
    assert Group.last.membership_settings.last
    assert_equal 5, Group.last.membership_settings.last.max_limit
  end

  def test_propose_group_success_and_connection_settings_are_created
    program = programs(:pbe)
    program.update_attributes(:allow_circle_start_date => false)
    roles = program.roles.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).index_by(&:name)
    student_role = roles[RoleConstants::STUDENT_NAME]
    mentor_role = roles[RoleConstants::MENTOR_NAME]
    program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    current_user_is :f_mentor_pbe
    assert student_role.slot_config_optional?

    User.any_instance.stubs(:can_create_group_without_approval?).returns(false)

    assert_emails((program.admin_users - [users(:f_mentor_pbe)]).size) do
      assert_differences [ ["Group.count", 1], ["Group::MembershipSetting.count", 1] ] do
        post :create, params: { :group => {
          "name"=>"Sample Project",
          "join_as_role_id" => "#{mentor_role.id}",
          :membership_setting => {student_role.id.to_s =>  "5"}
        },
        :connection_answers => {},
        :propose_view => "true"}
      end
    end
    assert_redirected_to profile_group_path(Group.last)
    assert_equal "The mentoring connection proposal was successful. You will be notified once the administrator accepts your mentoring connection.", flash[:notice]
    assert Group.last.proposed?
    check_group_state_change_unit(Group.last, GroupStateChange.last, nil)
    assert_equal users(:f_mentor_pbe), Group.last.created_by
    assert Group.last.members.include?(users(:f_mentor_pbe))
    assert_equal 5, Group.last.membership_settings.find_by(role_id: student_role.id).max_limit
    assert_false assigns(:can_set_start_date)
    assert Group.last.membership_of(users(:f_mentor_pbe)).owner
  end

  def test_propose_group_success_with_can_set_start_date
    program = programs(:pbe)
    student_role = program.roles.with_name(RoleConstants::STUDENT_NAME).first
    program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    program.update_attributes(:allow_circle_start_date => true)
    current_user_is :f_mentor_pbe
    assert student_role.slot_config_optional?

    User.any_instance.stubs(:can_create_group_without_approval?).returns(false)

    assert_emails((program.admin_users - [users(:f_mentor_pbe)]).size) do
      assert_difference "Group.count", 1 do
        post :create, xhr: true, params: { :group => {
            "name"=>"Sample Project",
            :membership_setting => {student_role.id.to_s =>  ""}
          },
          :propose_view => "true"
        }
      end
    end

    assert assigns(:can_set_start_date)
  end

  def test_propose_group_success_with_approval_admin_not_required
    program = programs(:pbe)
    student_role = program.roles.with_name(RoleConstants::STUDENT_NAME).first
    program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    program.update_attributes(:allow_circle_start_date => false)
    current_user_is :f_mentor_pbe
    assert student_role.slot_config_optional?

    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(false)
    
    assert_no_emails do
      assert_difference "Group.count", 1 do
        post :create, xhr: true, params: { :group => {
            "name"=>"Sample Project",
            :membership_setting => {student_role.id.to_s =>  ""}
          },
          :propose_view => "true"
        }
      end
    end

    group = Group.last
    assert group.pending?
    assert_equal "The mentoring connection has been created successfully.", flash[:notice]
    assert assigns(:can_create_group_directly)
  end

  def test_propose_group_success_max_limit_optional_and_absent
    program = programs(:pbe)
    student_role = program.roles.with_name(RoleConstants::STUDENT_NAME).first
    program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    program.update_attributes(:allow_circle_start_date => false)
    current_user_is :f_mentor_pbe
    assert student_role.slot_config_optional?

    Role.any_instance.stubs(:needs_approval_to_create_circle?).returns(true)

    assert_emails((program.admin_users - [users(:f_mentor_pbe)]).size) do
      assert_difference "Group.count", 1 do
        post :create, params: { :group => {
          "name"=>"Sample Project",
          :membership_setting => {student_role.id.to_s =>  ""}
        },
        :propose_view => "true"}
      end
    end

    assert_redirected_to profile_group_path(Group.last)
    assert_equal "The mentoring connection proposal was successful. You will be notified once the administrator accepts your mentoring connection.", flash[:notice]
    assert_false assigns(:can_create_group_directly)
  end

  def test_propose_group_fails_when_max_limit_required_and_absent
    program = programs(:pbe)
    student_role = program.roles.with_name(RoleConstants::STUDENT_NAME).first
    program.add_role_permission(RoleConstants::MENTOR_NAME, RolePermission::PROPOSE_GROUPS)
    current_user_is :f_mentor_pbe
    Rails.logger.expects(:error)
    student_role.update_attributes!(slot_config: RoleConstants::SlotConfig::REQUIRED)
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {student_role.id.to_s =>  ""}
      },
      :connection_answers => {},
      :propose_view => "true"}
    assert_redirected_to program_root_path
  end

  def test_propose_group_failure
    program = programs(:pbe)
    roles = program.roles.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).index_by(&:name)
    student_role = roles[RoleConstants::STUDENT_NAME]
    mentor_role = roles[RoleConstants::MENTOR_NAME]
    current_user_is :f_mentor_pbe

    assert_false users(:f_mentor_pbe).can_propose_groups?
    assert_permission_denied do
      post :create, params: { :group => {
        "name"=>"Sample Project",
        :membership_setting => {student_role.id.to_s => ""},
        "join_as_role_id" => "#{mentor_role.id}"
      },
      :connection_answers => {}, :propose_view => "true"}
    end
  end

  def test_add_members
    enable_project_based_engagements!
    current_user_is :f_admin
    group = programs(:albers).groups.last
    get :add_members, params: { :id => group.id}
    assert_response :success
  end

  def test_update_members_without_student_max_limit
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin

    group = program.groups.last
    group.update_attributes!(:name => "Sample Project", :status => Group::Status::DRAFTED)
    student_ids = [11, 12, 13, 14, 15]
    mentor_ids = [25, 26, 27]
    program_roles = program.roles.group_by(&:name)
    time_traveller(Time.new(2012).utc) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails (student_ids + mentor_ids).size do
            put :update_members, params: { :id => group.id,
              :group_members =>{
                :role_id => {
                  program_roles[RoleConstants::MENTOR_NAME].first.id => User.where(id: mentor_ids).collect(&:name_with_email).join(","),
                  program_roles[RoleConstants::STUDENT_NAME].first.id => User.where(id: student_ids).collect(&:name_with_email).join(",")
                }
              },
              group: {
                message: "Frank Underwood"
              }
            }
          end
        end
      end
    end

    assert_redirected_to groups_path(tab: Group::Status::PENDING)
    assert group.reload.pending?

    group_addition_ra = RecentActivity.last
    assert_equal group, group_addition_ra.ref_obj
    assert_equal RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL, group_addition_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, group_addition_ra.target
    assert_nil group_addition_ra.member
    assert_equal 1, group_addition_ra.connection_activities.count
    connection_activity = group_addition_ra.connection_activities.first
    assert_equal group, connection_activity.group
    assert_equal Time.new(2012).utc.strftime("%m/%d/%Y"), group.last_activity_at.strftime("%m/%d/%Y")


    assert_equal_unordered student_ids, group.reload.students.collect(&:member_id)
    assert_equal_unordered mentor_ids,  group.reload.mentors.collect(&:member_id)
    emails = ActionMailer::Base.deliveries.last(group.members.size)
    email = emails.last
    user = group.members.last
    assert_match /You have been added as a .* to #{group.name}/, email.subject
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /We will notify you when the mentoring connection starts. Meanwhile, you can visit the mentoring connection to see your other available activities./, mail_content
    assert_match /Frank Underwood/, mail_content
  end

  def test_update_members_with_student_max_limit_success
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin

    group = program.groups.last
    group.update_attributes!(:name => "Sample Project", :status => Group::Status::DRAFTED)
    student_ids = [11, 12, 13, 14, 15]
    mentor_ids = [25, 26, 27]

    m_setting = group.membership_settings.find_or_initialize_by(role_id: program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes(:max_limit => student_ids.count + 2)
    program_roles = program.roles.group_by(&:name)
    assert_emails (student_ids + mentor_ids).size do
      put :update_members, params: { :id => group.id, :group_members =>{
        :role_id => {
          program_roles[RoleConstants::MENTOR_NAME].first.id => User.where(id: mentor_ids).collect(&:name_with_email).join(","),
          program_roles[RoleConstants::STUDENT_NAME].first.id => User.where(id: student_ids).collect(&:name_with_email).join(",")
        }
      }}
    end
    assert_redirected_to groups_path(tab: Group::Status::PENDING)
    assert group.reload.pending?
    assert_equal_unordered student_ids, group.reload.students.collect(&:member_id)
    assert_equal_unordered mentor_ids,  group.reload.mentors.collect(&:member_id)
    emails = ActionMailer::Base.deliveries.last(group.members.size)
    email = emails.last
    user = group.members.last
    assert_match /You have been added as a .* to #{group.name}/, email.subject
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /We will notify you when the mentoring connection starts. Meanwhile, you can visit the mentoring connection to see your other available activities./, mail_content
  end

  def test_update_members_in_draft_status
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin

    group = program.groups.last
    group.update_attributes!(:name => "Sample Project", :status => Group::Status::DRAFTED)
    student_ids = [11, 12, 13, 14, 15]
    mentor_ids = [25, 26, 27]

    m_setting = group.membership_settings.find_or_initialize_by(role_id: program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes(:max_limit => student_ids.count + 2)
    program_roles = program.roles.group_by(&:name)
    assert_no_emails do
      put :update_members, params: { :id => group.id, :group_members =>{
        :role_id => {
          program_roles[RoleConstants::MENTOR_NAME].first.id => User.where(id: mentor_ids).collect(&:name_with_email).join(","),
          program_roles[RoleConstants::STUDENT_NAME].first.id => User.where(id: student_ids).collect(&:name_with_email).join(",")
        }
      }, "save_and_continue_later" => true}
    end
    assert_redirected_to groups_path(tab: Group::Status::DRAFTED)
    assert_false group.reload.pending?
    assert group.drafted?
    assert_equal_unordered student_ids, group.reload.students.collect(&:member_id)
    assert_equal_unordered mentor_ids,  group.reload.mentors.collect(&:member_id)
  end

  def test_update_members_with_student_max_limit_failure
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin

    group = program.groups.last
    group.update_attributes!(:name => "Sample Project", :status => Group::Status::DRAFTED)
    student_ids = [11, 12, 13, 14, 15]
    mentor_ids = [25, 26, 27]

    m_setting = group.membership_settings.find_or_initialize_by(role_id: program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes!(:max_limit => student_ids.count - 2 )
    program_roles = program.roles.group_by(&:name)
    assert_no_emails do
      put :update_members, params: { :id => group.id, :group_members =>{
        :role_id => {
          program_roles[RoleConstants::MENTOR_NAME].first.id => User.where(id: mentor_ids).collect(&:name_with_email).join(","),
          program_roles[RoleConstants::STUDENT_NAME].first.id => User.where(id: student_ids).collect(&:name_with_email).join(",")
        }
      }}
    end
    assert_redirected_to add_members_group_path(group)
    assert_false group.reload.pending?
    assert_false ((student_ids - group.reload.students.collect(&:member_id)) + (group.reload.students.collect(&:member_id) - student_ids)).size == 0
    assert_false ((mentor_ids - group.reload.mentors.collect(&:member_id)) + (group.reload.mentors.collect(&:member_id) - mentor_ids)).size == 0
  end

  def test_update_with_pbe_drafted_groups
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    current_user_is :f_admin

    programs(:albers).update_attributes!(allow_one_to_many_mentoring: true)
    assert_false group.has_member?(users(:mentor_5))
    assert group.has_member?(users(:robert))
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    assert_no_difference('RecentActivity.count') do
      assert_emails 0 do
        post :update, xhr: true, params: {
          :id => group.id,
          :connection => {
            :users => {
              users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:student_5).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:robert).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:robert).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
              group.students.first.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          }, :tab => Group::Status::DRAFTED}
      end
    end

    assert_response :success
    group.reload
    assert_false group.has_member?(users(:robert))
    assert group.has_member?(users(:student_4))
    assert_equal [], group.mentors
    assert_equal [users(:student_4), users(:student_5)], group.students
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_update_with_max_limit_setting
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    group_students = group.students
    set_max_limit_for_group(group, group.students.count + 1, RoleConstants::STUDENT_NAME)
    current_user_is :f_admin

    programs(:albers).update_attributes!(allow_one_to_many_mentoring: true)
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    assert_no_difference('RecentActivity.count') do
      assert_emails 0 do
        post :update, xhr: true, params: {
          :id => group.id,
          :connection => {
            :users => {
              users(:student_6).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_6).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:student_5).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          }, :tab => Group::Status::DRAFTED}
      end
    end

    assert_response :success
    group.reload
    assert_false group.has_member?(users(:student_4))
    assert_false group.has_member?(users(:student_5))
    assert_false group.has_member?(users(:student_6))
    assert_not_equal [], group.mentors
    assert_equal group_students, group.reload.students
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
    assert_equal ["The mentoring connection can't have more than 2 students"], assigns(:group).errors.full_messages
  end

  def test_update_with_max_limit_setting_from_profile
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    group_students = group.students
    set_max_limit_for_group(group, group.students.count + 1, RoleConstants::STUDENT_NAME)
    current_user_is :f_admin
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    programs(:albers).update_attributes!(allow_one_to_many_mentoring: true)
    assert_no_difference('RecentActivity.count') do
      assert_emails 0 do
        post :update, params: {
          :id => group.id,
          :connection => {
            :users => {
              users(:student_6).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_6).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:student_5).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
              users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
            }
          }, :tab => Group::Status::DRAFTED, src: "profile"}
      end
    end

    assert_redirected_to profile_group_path(group)
    group.reload
    assert_false group.has_member?(users(:student_4))
    assert_false group.has_member?(users(:student_5))
    assert_false group.has_member?(users(:student_6))
    assert_not_equal [], group.mentors
    assert_equal group_students, group.reload.students
    assert_nil assigns(:connection_questions)
    assert_equal ["The mentoring connection can't have more than 2 students"], assigns(:group).errors.full_messages
  end

  def test_update_failure_for_mentor_with_max_limit_setting_from_profile_and_profile_connections_feature_disabled
    group = groups(:drafted_group_1)
    group_students = group.students
    set_max_limit_for_group(group, group.students.count + 1, RoleConstants::STUDENT_NAME)
    current_user_is :f_admin
    program = programs(:albers)
    program_roles = program.roles.group_by(&:name)
    programs(:albers).update_attributes!(allow_one_to_many_mentoring: true)
    post :update, params: {
      :id => group.id,
        :connection => {
          :users => {
            users(:student_6).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_6).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
            users(:student_5).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
            users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
          }
        }, src: "profile"
      }
    assert_false program.connection_profiles_enabled?
    assert_redirected_to group_path(group)
    group.reload
    assert_false group.has_member?(users(:student_4))
    assert_false group.has_member?(users(:student_5))
    assert_false group.has_member?(users(:student_6))
    assert_equal ["The mentoring connection can't have more than #{users(:f_mentor).max_connections_limit} students"], assigns(:group).errors.full_messages
  end

  def test_update_with_pbe_pending_groups
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin

    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    assert_false group.has_member?(users(:mentor_5))
    program_roles = program.roles.group_by(&:name)
    time_traveller Time.new(2012).utc do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Connection::Activity.count' do
          assert_emails 2 do
            post :update, xhr: true, params: {
              :id => group.id,
              :connection => {
                :users => {
                  users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
                  users(:student_5).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
                }
              }, :tab => Group::Status::PENDING}
          end
        end
      end
    end

    assert_response :success
    group.reload

    group_addition_ra = RecentActivity.last
    assert_equal group, group_addition_ra.ref_obj
    assert_equal RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL, group_addition_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, group_addition_ra.target
    assert_nil group_addition_ra.message
    assert_nil group_addition_ra.member
    assert_equal 1, group_addition_ra.connection_activities.count
    connection_activity = group_addition_ra.connection_activities.first
    assert_equal group, connection_activity.group
    assert_equal Time.new(2012).utc.strftime("%m/%d/%Y"), group.last_activity_at.strftime("%m/%d/%Y")

    assert_false group.has_member?(users(:robert))
    assert group.has_member?(users(:student_4))
    assert_equal [], group.mentors
    assert_equal [users(:student_4), users(:student_5)], group.students
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_update_with_max_limit_checks
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin

    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    m_setting = group.membership_settings.find_or_initialize_by(role_id: program.get_role(RoleConstants::STUDENT_NAME).id)
    m_setting.update_attributes!(:max_limit => 1)
    program_roles = program.roles.group_by(&:name)
    post :update, xhr: true, params: {
      :id => group.id,
      :connection => {
        :users => {
          users(:student_5).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
          users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}}
        }
      }, :tab => Group::Status::PENDING
    }

    assert_response :success
    group.reload
    assert_false group.has_member?(users(:robert))
    assert_false group.has_member?(users(:student_4))
    assert_equal [], group.mentors
    assert_equal [], group.students
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
    assert_equal ["The mentoring connection can't have more than 1 student"], assigns(:group).errors.full_messages
  end

  def test_index_for_draft_groups_with_pbe
    enable_project_based_engagements!
    current_user_is :f_admin

    get :index, params: { :tab => Group::Status::DRAFTED}
    assert_response :success

    assert_equal_unordered [
      groups(:drafted_group_1),
      groups(:drafted_group_2),
      groups(:drafted_group_3)
    ].collect(&:id), assigns(:groups).collect(&:id)

    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_index_for_pending_grups_with_pbe
    enable_project_based_engagements!
    current_user_is :f_admin

    get :index, params: { :tab => Group::Status::PENDING}
    assert_response :success

    assert assigns(:is_pending_connections_view)
    assert "active", assigns(:sort_field)
    assert "desc", assigns(:sort_order)
    assert_equal programs(:albers).connection_questions, assigns(:connection_questions)
  end

  def test_indx_for_pending_groups_with_pbe_list_view
    enable_project_based_engagements!
    current_user_is :f_admin

    get :index, params: { :tab => Group::Status::PENDING, :view => Group::View::LIST}
    assert_response :success

    assert assigns(:is_pending_connections_view)
    assert "name", assigns(:sort_field)
    assert "asc", assigns(:sort_order)
    assert_nil assigns(:connection_questions)
  end

  def test_assign_template_for_pending_pbe_tracks
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    mentoring_model = create_mentoring_model
    mentoring_model.update_columns(allow_forum: false, allow_messaging: true)
    assert group.scraps_enabled?

    post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [group.id].join(" "), tab_number: Group::Status::PENDING}}
    assert_response :success

    assert_equal mentoring_model, group.reload.mentoring_model
  end

  def test_show_template_mismatch_alert_assign_template
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin
    group = create_group(name: "Claire Underwood", students: [], mentors: [program.mentor_users.first], program: program, status: Group::Status::PENDING)
    mentoring_model = create_mentoring_model
    create_scrap(group: group)

    assert group.scraps_enabled?
    assert mentoring_model.allow_forum?

    post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [group.id].join(" "), tab_number: Group::Status::PENDING}}
    assert_response :success

    assert_match "The updated template does not have Messages enabled. If you go ahead with this change, the users of the mentoring connection will no longer be able to see the messages.", @response.body
    assert_not_equal mentoring_model, group.reload.mentoring_model
  end

  def test_no_show_template_mismatch_alert_assign_template_if_already_shown
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_admin
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    mentoring_model = create_mentoring_model
    assert group.scraps_enabled?
    assert mentoring_model.allow_forum?

    post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ASSIGN_TEMPLATE, group_ids: [group.id].join(" "), tab_number: Group::Status::PENDING, assign_template_alert_shown: "true"}}
    assert_response :success
    assert_equal mentoring_model, group.reload.mentoring_model
  end

  def test_make_available_permission_denied
    program = programs(:albers)
    enable_project_based_engagements!
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    current_user_is :f_admin

    assert_permission_denied do
      post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::MAKE_AVAILABLE, group_ids: [group.id].join(" "), tab_number: Group::Status::PENDING}}
    end
  end

  def test_make_available_success
    program = programs(:albers)
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    current_user_is :f_admin

    program.update_attribute(:allow_circle_start_date, true)

    group.update_attribute(:start_date, Time.now + 2.days)

    assert_emails group.members.size do
      post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::MAKE_AVAILABLE, group_ids: [group.id].join(" "), tab_number: Group::Status::DRAFTED, message: "Frank Underwood"}, with_new_start_date: "false", start_date: "April 19, 2028"}
    end
    assert_response :success

    assert group.reload.pending?
    emails = ActionMailer::Base.deliveries.last(2)
    email = emails.last
    user = group.members.last
    assert_match /You have been added as a .* to #{group.name}/, email.subject
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    assert_equal [], assigns(:groups_with_past_start_date)
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /We will notify you when the mentoring connection starts. Meanwhile, you can visit the mentoring connection to see your other available activities./, mail_content
    assert_match /Frank Underwood/, mail_content
    assert_match "- the program administrator", mail_content
    assert_match "Go to mentoring connection", mail_content

    group = create_group(name: "Claire Underwood", students: [], mentors: [users(:pending_user)], program: program, status: Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    assert users(:pending_user).state == User::Status::PENDING

    Member.any_instance.stubs(:get_valid_time_zone).returns("Asia/Kolkata")

    post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::MAKE_AVAILABLE, group_ids: [group.id].join(" "), tab_number: Group::Status::DRAFTED, message: "Frank Underwood"}, with_new_start_date: "true", :start_date => "April 19, 2010"}

    assert users(:pending_user).reload.state == User::Status::ACTIVE

    assert_equal [group], assigns(:groups_with_past_start_date)
    assert_equal "April 19, 2010".to_time.in_time_zone("Asia/Kolkata").to_date, group.reload.start_date.in_time_zone("Asia/Kolkata").to_date
  end

  def test_make_available_show_past_date_flash
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    programs(:albers).update_attribute(:allow_circle_start_date, true)
    
    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    group.update_attribute(:start_date, current_time + 12.hours)
    current_user_is :f_admin

    assert_no_emails do
      post :update_bulk_actions, xhr: true, params: {bulk_actions: {action_type: Group::BulkAction::MAKE_AVAILABLE, group_ids: [group.id].join(" "), tab_number: Group::Status::DRAFTED, message: "Frank Underwood"}}
    end
    
    assert_response :success

    assert_equal [group], assigns(:groups_with_past_start_date)
    assert_equal ["Couldn't complete the action as the start date of mentoring connection(s) #{ActionController::Base.helpers.link_to(group.name, profile_group_path(group), target: "_blank")} are already past. Please set a new start for mentioned mentoring connection to complete the action in bulk."], assigns(:error_flash)
  end

  def test_make_available_show_past_date_flash_with_setting_disabled
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    programs(:albers).update_attribute(:allow_circle_start_date, false)
    current_user_is :f_admin

    group.update_attribute(:start_date, Time.now - 2.days)

    post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::MAKE_AVAILABLE, group_ids: [group.id].join(" "), tab_number: Group::Status::DRAFTED, message: "Frank Underwood"}}
    
    assert_response :success

    assert_equal [], assigns(:groups_with_past_start_date)
    assert_nil assigns(:error_flash)
  end

  def test_make_available_fetch_bulk_actions
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    programs(:albers).update_attribute(:allow_circle_start_date, true)
    current_user_is :f_admin

    Group.any_instance.stubs(:has_past_start_date?).returns(true)

    get :fetch_bulk_actions, xhr: true, params: { :bulk_action => {:action_type => Group::BulkAction::MAKE_AVAILABLE, :group_ids => [group.id]}, individual_action: true}

    assert_response :success
    assert_match PendingGroupAddedNotification.mailer_attributes[:uid], @response.body
    assert assigns(:show_start_date_field)
    assert_equal [group], assigns(:groups)
    assert_match /An.*#{PendingGroupAddedNotification.mailer_attributes[:uid]}.*email.*will be sent to the users if you complete this action./, @response.body
  end

  def test_make_available_fetch_bulk_actions_for_no_show_start_date_field
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    programs(:albers).update_attribute(:allow_circle_start_date, false)
    current_user_is :f_admin

    Group.any_instance.stubs(:has_past_start_date?).returns(true)

    get :fetch_bulk_actions, xhr: true, params: {:bulk_action => {:action_type => Group::BulkAction::MAKE_AVAILABLE, :group_ids => [group.id]}, individual_action: true}

    assert_response :success
    assert_false assigns(:show_start_date_field)
  end

  def test_make_available_with_no_show_start_date
    enable_project_based_engagements!
    group = groups(:drafted_group_1)
    current_user_is :f_admin

    Group.any_instance.stubs(:has_past_start_date?).returns(true)

    get :fetch_bulk_actions, xhr: true, params: {:bulk_action => {:action_type => Group::BulkAction::MAKE_AVAILABLE, :group_ids => [group.id]}}
    assert_response :success
    assert_false assigns(:show_start_date_field)

    Group.any_instance.stubs(:has_past_start_date?).returns(false)

    get :fetch_bulk_actions, xhr: true, params: {:bulk_action => {:action_type => Group::BulkAction::MAKE_AVAILABLE, :group_ids => [group.id]}, individual_action: true}
    assert_response :success
    assert_false assigns(:show_start_date_field)
  end

  def test_publish_groups_with_active_project_requests
    enable_project_based_engagements!
    group = create_group(name: "Claire Underwood", mentors: [users(:f_mentor)], students: [users(:f_student)], program: programs(:albers), status: Group::Status::PENDING)
    create_project_request(group, users(:student_3))
    current_user_is :f_admin

    post :update_bulk_actions, xhr: true, params: { bulk_actions: {action_type: Group::BulkAction::PUBLISH, group_ids: [group.id].join(" "), notes: "Testing Notes", membership_settings: {allow_join: "true"}}}
    assert_response :success
    assert_equal [group], assigns(:groups)

    output_hash = ProgressStatus.last.details
    assert_empty output_hash[:error_group_ids]

    assert_equal ["feature.connection.content.notice.published_groups_with_pending_requests_html".translate(mentoring_connections: _mentoring_connections, project_listing_url: manage_project_requests_path(filtered_group_ids: [group.id], from_bulk_publish: true, dont_show_flash: true, ga_src: EngagementIndex::Src::GROUP_LISTING, track_publish_ga: true, src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET))], output_hash[:error_flash]
    assert_equal manage_project_requests_path(filtered_group_ids: [group.id], from_bulk_publish: true, ga_src: EngagementIndex::Src::GROUP_LISTING, track_publish_ga: true, src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET), output_hash[:redirect_path]
  end

  def test_publish_single_group_with_active_project_requests
    enable_project_based_engagements!
    group = create_group(name: "Claire Underwood", mentors: [users(:f_mentor)], students: [users(:f_student)], program: programs(:albers), status: Group::Status::PENDING)
    create_project_request(group, users(:student_3))
    create_project_request(group, users(:student_4))
    current_user_is :f_admin

    put :publish, params: { :id => group.id, group: {message: "Test notes", membership_settings: {allow_join: "true"}}, ga_src: "ga_src"}

    assert_equal group, assigns(:group)
    assert_nil assigns(:error_flash)
    assert_equal "ga_src", assigns(:ga_src)
    program = programs(:albers)
    organization = program.organization
    assert_redirected_to Rails.application.routes.url_helpers.manage_project_requests_url(host: organization.domain, subdomain: organization.subdomain, root: program.root,filtered_group_ids: [group.id], from_bulk_publish: false, track_publish_ga: true, ga_src: "ga_src", src: EngagementIndex::Src::PUBLISH_CIRCLE_WIDGET)
  end

  def test_open_tab_for_end_users_in_pbe
    enable_project_based_engagements!
    program = programs(:albers)
    initialize_connection_questions(program)
    group = create_group(name: "Claire Underwood", mentors: [users(:f_mentor)], students: [users(:f_student)], program: program, status: Group::Status::PENDING)
    current_user_is :f_mentor

    get :index, params: { show: "my"}
    assert_response :success

    assert assigns(:is_my_connections_view)
    assert assigns(:is_open_connections_view)
    assert_equal 2, assigns(:tab_counts)[:open]
    assert assigns(:connection_questions).present?
  end

  def test_find_new_projects_permission_denied
    enable_project_based_engagements!
    current_user_is :f_admin

    assert_permission_denied do
      get :find_new
    end
  end

  def test_find_new_projects_with_filters
    enable_project_based_engagements!
    current_user_is :f_student
    program = programs(:albers)
    search_filters = { :available_to_join => "all_projects"}
    get :find_new, xhr: true, params: { search_filters: search_filters, "view"=>"", "sort"=>"", "order"=>"", "tab"=>""}
    assert_response :success
    count1 = assigns(:my_filters).count
    member_filters = { program.roles.find_by(name: RoleConstants::MENTOR_NAME).id => "Good unique name"}
    search_filters = { :available_to_join => "availabe_projects" }
    get :find_new, xhr: true, params: { search_filters: search_filters, member_filters: member_filters, "view"=>"", "sort"=>"", "order"=>"", "tab"=>""}
    assert_response :success
    count2 = assigns(:my_filters).count
    assert_not_equal count1, count2
  end

  def test_find_new_projects_with_student
    enable_project_based_engagements!
    initialize_connection_questions(programs(:albers))
    current_user_is :f_student

    get :find_new
    assert_response :success

    assert_page_title "Find new mentoring connections"
    assert assigns(:filterable_connection_questions).present?
    assert assigns(:connection_questions).present?
  end

  def test_find_new_with_mentor
    enable_project_based_engagements!
    programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    initialize_connection_questions(programs(:albers))
    current_user_is :f_mentor

    get :find_new
    assert_response :success

    assert_page_title "All mentoring connections"
    assert assigns(:filterable_connection_questions).present?
    assert assigns(:connection_questions).present?
  end

  def test_find_new_success_with_student_scenrio
    current_user_is :f_student_pbe
    get :find_new

    assert_response :success
    assert_page_title "Find new mentoring connections"
    assert_equal programs(:pbe).groups.open_connections.to_a, assigns(:groups).to_a
    assert_false assigns(:groups).include?(groups(:drafted_group_3))
    assert assigns(:find_new)
  end

  def test_find_new_success_with_student_scenrio_with_filter_selected
    current_user_is :f_student_pbe

    get :find_new, xhr: true, params: { search_filters: {available_to_join: GroupsHelper::DEFAULT_AVAILABLE_TO_JOIN_FILTER}}
    assert_response :success

    assert_equal programs(:pbe).groups.open_connections.to_a, assigns(:groups).to_a
    assert assigns(:find_new)
  end

  def test_find_new_success_with_student_scenrio_with_filter_deselected
    current_user_is :f_student_pbe

    get :find_new, xhr: true, params: { search_filters: {available_to_join: "all_projects"}}
    assert_response :success

    assert_equal programs(:pbe).groups.where(status: [Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::PENDING]).to_a, assigns(:groups).to_a
    assert assigns(:find_new)
    assert_no_select "#ct_milestones_content"
  end

  def test_find_new_success_with_teacher_scenrio_with_filter_deselected
    current_user_is :f_student_pbe
    users(:f_student_pbe).update_roles(["teacher"])

    program = programs(:pbe)
    role = program.get_role("teacher")
    role.add_permission("send_project_request")
    role.add_permission("view_find_new_projects")
    get :find_new, xhr: true, params: { search_filters: {available_to_join: "all_projects"}}
    assert_response :success

    assert_equal programs(:pbe).groups.where(status: Group::Status::OPEN_CRITERIA).to_a, assigns(:groups).to_a
    assert assigns(:find_new)
    assert_no_select "#ct_milestones_content"
  end

  def test_find_new_success_with_mentor_scenrio
    programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    current_user_is :f_mentor_pbe

    get :find_new
    assert_response :success

    assert_page_title "All mentoring connections"
    assert_equal [groups(:group_pbe)], assigns(:groups).to_a
    assert assigns(:find_new)
    assert_no_select "#ct_milestones_content"
  end

  def test_find_new_projects_with_search_student
    current_user_is :f_student_pbe
    get :find_new, params: { search: "project_b" }
    assert_response :success
    assert_page_title "Search results for project_b"
    assert assigns(:find_new)
    assert_equal "project_b", assigns(:search_query)
    assert_equal [groups(:group_pbe_1)], assigns(:groups).to_a
  end

  def test_find_new_projects_with_search_mentor
    programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")

    current_user_is :f_mentor_pbe
    get :find_new, params: { search: "project_b" }
    assert_response :success
    assert_page_title "Search results for project_b"
    assert assigns(:find_new)
    assert_equal "project_b", assigns(:search_query)
    assert_empty assigns(:groups)
  end

  def test_find_new_projects_with_request_to_join
    current_user_is :pbe_student_1
    get :find_new
    assert_response :success
    assert_select "a.cjs_request_group_#{groups(:group_pbe_0).id}", 2
  end

  def test_find_new_projects_quick_find_student
    current_user_is :f_student_pbe
    get :find_new, xhr: true, params: { search_filters: { quick_search: "project_b" } }
    assert_response :success
    assert assigns(:find_new)
    assert_nil assigns(:search_query)
    assert_equal [groups(:group_pbe_1)], assigns(:groups).to_a
  end

  def test_find_new_projects_quick_find_mentor
    programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")

    current_user_is :f_mentor_pbe
    get :find_new, xhr: true, params: { search_filters: { quick_search: "project_b" } }
    assert_response :success
    assert assigns(:find_new)
    assert_nil assigns(:search_query)
    assert_empty assigns(:groups)
  end

  def test_access_to_show_profile_for_admin_user
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)

    current_user_is :f_admin
    group = groups(:mygroup)
    assert group.published?
    get :profile, params: { id: group.id }
    assert_response :success

    # should be able to see in the draft state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    get :profile, params: { id: group.id}
    assert_response :success
  end

  def test_access_to_show_profile_for_member_user
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_mentor
    group = groups(:mygroup)

    assert group.has_member?(users(:f_mentor))
    assert group.published?
    get :profile, params: { id: group.id}
    assert_response :success

    # should not see in the draft state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :profile, params: { id: group.id}
    end
  end

  def test_access_to_show_profile_for_other_user_career_based
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_student
    group = groups(:mygroup)

    # should not see profile in career based program if group is not global
    group.global = false
    group.save!
    assert_false group.has_member?(users(:f_student))
    assert group.published?
    assert_false group.global?
    assert_permission_denied do
      get :profile, params: { id: group.id}
    end

    # should see profile in career based program if group is global
    group.global = true
    group.save!
    assert group.global?
    get :profile, params: { id: group.id}
    assert_response :success
 end

 def test_access_to_show_profile_for_other_user_project_based
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_student
    group = groups(:mygroup)

    # should see profile in project based program
    get :profile, params: { id: group.id}
    assert_response :success

    # should not to see in the draft state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :profile, params: { id: group.id}
    end
    # should see profile in pending state
    group.actor = users(:f_admin)
    group.update_attributes!(status: Group::Status::PENDING)
    assert group.pending?
    get :profile, params: { id: group.id}
    assert_response :success
    assert_nil assigns(:scraps_enabled)
  end

  def test_access_to_edit_answers_for_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_admin

    group = groups(:mygroup)
    assert group.published?
    get :edit_answers, params: { id: group.id}
    assert_response :success

    # should be able to edit in the draft state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    get :edit_answers, params: { id: group.id}
    assert_response :success

    # should not be able to edit in the closed state
    group.update_attributes!(status: Group::Status::CLOSED, closed_at: Time.now, closed_by: users(:f_admin), termination_mode: Group::TerminationMode::ADMIN, closure_reason_id: group.get_auto_terminate_reason_id)
    assert group.closed?
    assert_permission_denied do
      get :edit_answers, params: { id: group.id}
    end
  end

  def test_access_to_edit_answers_for_member_career_based
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_mentor
    group = groups(:mygroup)

    #should be able to edit in published state
    assert group.has_member?(users(:f_mentor))
    assert group.published?
    get :edit_answers, params: { id: group.id}
    assert_response :success

    # should not edit in the draft state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :edit_answers, params: { id: group.id}
    end

    # should not edit in the closed state
    group.update_attributes!(status: Group::Status::CLOSED, closed_at: Time.now, closed_by: users(:f_admin), termination_mode: Group::TerminationMode::ADMIN, closure_reason_id: group.get_auto_terminate_reason_id)
    assert group.closed?
    assert_permission_denied do
      get :edit_answers, params: { id: group.id}
    end
  end

  def test_access_to_edit_answers_for_member_project_based
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert program.project_based?
    #should not edit in any state
    assert group.published?
    assert_permission_denied do
      get :edit_answers, params: { id: group.id}
    end
  end

  def test_access_to_edit_answers_for_other_user
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_student
    group = groups(:mygroup)
    # can't edit answers at all.
    assert_false group.has_member?(users(:f_student))
    assert_permission_denied do
      get :edit_answers, params: { id: group.id}
    end
  end

  def test_access_to_edit_answers_for_member_project_based_owner
    program = programs(:albers)
    enable_project_based_engagements!
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert program.project_based?
    assert group.published?
    group.membership_of(users(:f_mentor)).update_attributes!(owner: true)

    get :edit_answers, params: { id: group.id}
    assert_response :success
  end

  def test_access_to_mentoring_area_for_admin_with_audit_logs
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_admin

    program.admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::AUDITED_ACCESS
    program.save!

    group = groups(:mygroup)
    assert group.published?
    get :show, params: { id: group.id}
    # should be redirected to confidentiality audit log before mentoring area access
    assert_redirected_to new_confidentiality_audit_log_path(group_id: group.id)
    # should allow access in drafted or pending state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :show, params: { id: group.id}
    end
  end

  def test_access_to_mentoring_area_for_admin_without_audit_logs
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_admin
    group = groups(:mygroup)

    program.admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::OPEN
    program.save!
    program.reload

    assert group.published?
    get :show, params: { id: group.id}
    assert_response :success

    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :show, params: { id: group.id}
    end
  end

  def test_params_target_all_members
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_admin
    group = groups(:mygroup)
    assert_equal 2, group.members.size

    program.admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::OPEN
    program.save!
    program.reload

    assert group.published?
    get :show, params: { id: group.id}
    assert_response :success
    assert_equal GroupsController::TargetUserType::ALL_MEMBERS, assigns(:target_user_type)

    get :show, params: { id: group.id, :target_user_id => users(:f_mentor).id, :target_user_type => GroupsController::TargetUserType::INDIVIDUAL}
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, assigns(:target_user_type)
  end

  def test_access_to_mentoring_area_for_admin_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::CONNECTION_PROFILE, true)
    current_user_is :f_admin
    group = groups(:mygroup)

    program.admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::DISABLED
    program.save!

    assert group.published?
    assert_permission_denied do
      get :show, params: { id: group.id}
    end

    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :show, params: { id: group.id}
    end
  end

  def test_access_to_mentoring_area_for_member
    current_user_is :f_mentor
    group = groups(:mygroup)
    # can see mentoring area in published state
    assert group.has_member?(users(:f_mentor))
    get :show, params: { id: group.id}
    assert_response :success
    # should not see in pending or drafted state
    group.update_attributes!(created_by: users(:f_admin), status: Group::Status::DRAFTED)
    assert group.drafted?
    assert_permission_denied do
      get :show, params: { id: group.id}
    end
  end

  def test_access_to_mentoring_area_for_other_user
    current_user_is :f_student
    group = groups(:mygroup)
    # can't see mentoring area at all.
    assert_false group.has_member?(users(:f_student))
    assert_permission_denied do
      get :show, params: { id: group.id}
    end
  end

  # group view type should be detailed always for non-manage connections view( my connection view, global connection view)
  def test_groups_listing_for_non_manage_connections_view
    current_user_is :f_admin
    # manage connection view (without :show params)
    session[:groups_view] = Group::View::LIST
    get :index, params: { :tab => Group::Status::PENDING, :view => Group::View::LIST}
    assert_response :success
    assert_equal Group::View::LIST, session[:groups_view]
    assert_equal Group::View::LIST, assigns(:view)
  end

  def test_groups_listing_for_non_manage_connections_view_with_param
    current_user_is :f_admin
    # non-manage connection view (with :show params)
    session[:groups_view] = Group::View::LIST
    get :index, params: { :tab => Group::Status::PENDING, :view => Group::View::LIST, :show => "my"}
    assert_response :success
    assert_equal Group::View::DETAILED, session[:groups_view]
    assert_equal Group::View::DETAILED, assigns(:view)
  end

  def test_counts_proposed_rejected_tabs_and_proposed_groups_disabled
    current_user_is :f_admin_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)
    2.times do
      create_group(name: "Mad Men - Donald Draper", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Orange is the new black", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    get :index, params: { view: Group::View::DETAILED}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 6, drafted: 1, rejected: 4, pending: 5, ongoing: 1, closed: 0, withdrawn: 1}), assigns(:tab_counts)
    assert_select "ul#tab-box" do
      assert_select "li#drafted_tab"
      assert_select "li#proposed_tab"
      assert_select "li#pending_tab"
      assert_select "li#ongoing_tab"
      assert_select "li#closed_tab"
      assert_select "li#rejected_tab"
      assert_select "li#withdrawn_tab"
    end
  end

  def test_tabs_for_admins_without_proposed_groups_permission
    current_user_is :f_admin_pbe
    programs(:pbe).groups.where(status: [Group::Status::PROPOSED, Group::Status::REJECTED]).destroy_all

    get :index, params: { view: Group::View::DETAILED}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 0, drafted: 1, rejected: 0, pending: 5, ongoing: 1, closed: 0, withdrawn: 1}), assigns(:tab_counts)

    assert_select "ul#tab-box" do
      assert_no_select "li#open_tab"
      assert_select "li#pending_tab"
      assert_select "li#ongoing_tab"
      assert_no_select "li#proposed_tab"
      assert_no_select "li#rejected_tab"
      assert_select "li#closed_tab"
      assert_select "li#withdrawn_tab"
    end
  end

  def test_counts_proposed_rejected_tabs_for_students_without_can_propose_projects
    current_user_is :f_student_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)

    2.times do
      create_group(name: "Suits - Donna :)", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "House of Cards - Robin Wright :)", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end
    program.reload

    get :index, params: { view: Group::View::DETAILED, show: "my"}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 2, rejected: 3, open: 1, closed: 0, withdrawn: 0}), assigns(:tab_counts)

    assert_select "ul#tab-box" do
      assert_select "li#open_tab"
      assert_no_select "li#pending_tab"
      assert_no_select "li#ongoing_tab"
      assert_no_select "li#proposed_tab"
      assert_no_select "li#rejected_tab"
      assert_select "li#closed_tab"
    end
  end

  def test_counts_proposed_rejected_tabs_for_students_who_can_propose_projects
    current_user_is :f_student_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)
    program.roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).each do |role|
      role.add_permission(RolePermission::PROPOSE_GROUPS)
    end
    2.times do
      create_group(name: "House of Cards - Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_mentor_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Homeland - Carrie Mathison", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_student_pbe).id)
    end

    create_group(name: "Walter/Skyler White", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)

    get :index, params: { view: Group::View::DETAILED, show: "my"}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 4, rejected: 2, open: 1, closed: 0, withdrawn: 0}), assigns(:tab_counts)

    assert_select "ul#tab-box" do
      assert_select "li#open_tab"
      assert_no_select "li#pending_tab"
      assert_no_select "li#ongoing_tab"
      assert_select "li#proposed_tab"
      assert_select "li#rejected_tab"
      assert_select "li#closed_tab"
    end
  end

  def test_counts_withdrawn_tab_student
    current_user_is :f_student_pbe
    program = programs(:pbe)
    2.times do
      create_group(name: "Harvey Spector - Michael Ross 1", students: [users(:f_student_pbe)], mentors: [], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Harvey Spector - Michael Ross 2", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end
    get :index, params: { view: Group::View::DETAILED, show: "my", tab: Group::Status::WITHDRAWN}
    assert_response :success
    assert_equal_hash ({proposed: 2, rejected: 1, open: 1, closed: 0, withdrawn: 2}), assigns(:tab_counts)
    assert_select "ul#tab-box" do
      assert_select "li#withdrawn_tab"
    end
  end

  def test_counts_withdrawn_tab_admin
    current_user_is :f_admin_pbe
    program = programs(:pbe)

    2.times do
      create_group(name: "Harvey Spector - Michael Ross 1", students: [users(:f_student_pbe)], mentors: [], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Harvey Spector - Michael Ross 2", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end
    get :index, params: { view: Group::View::DETAILED, tab: Group::Status::WITHDRAWN}
    assert_response :success
    assert_equal_hash ({proposed: 4, pending: 5, rejected: 2, drafted: 1, closed: 0, ongoing: 1, withdrawn: 5}), assigns(:tab_counts)

    assert_select "ul#tab-box" do
      assert_select "li#withdrawn_tab"
    end
  end

  def test_counts_proposed_rejected_tabs_proposed_connections_view_for_end_users
    current_user_is :f_student_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)
    2.times do
      create_group(name: "House of Cards - Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_mentor_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Homeland - Carrie Mathison", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_student_pbe).id)
    end

    create_group(name: "Walter/Skyler White", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)

    get :index, params: { view: Group::View::DETAILED, show: "my", tab: Group::Status::PROPOSED}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 4, rejected: 2, open: 1, closed: 0, withdrawn: 0}), assigns(:tab_counts)

    assert_select "ul#tab-box" do
      assert_select "li#open_tab"
      assert_no_select "li#pending_tab"
      assert_no_select "li#ongoing_tab"
      assert_no_select "li#proposed_tab"
      assert_no_select "li#rejected_tab"
      assert_select "li#closed_tab"
    end
  end

  def test_counts_proposed_rejected_tabs_for_admins_rejected_connections_view
    current_user_is :f_admin_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)
    2.times do
      create_group(name: "Mad Men - Donald Draper", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Orange is the new black", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    get :index, params: { view: Group::View::DETAILED, tab: Group::Status::REJECTED}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 6, drafted: 1, rejected: 4, pending: 5, ongoing: 1, closed: 0, withdrawn: 1}), assigns(:tab_counts)
    assert_select "ul#tab-box" do
      assert_select "li#drafted_tab"
      assert_select "li#proposed_tab"
      assert_select "li#pending_tab"
      assert_select "li#ongoing_tab"
      assert_select "li#closed_tab"
      assert_select "li#rejected_tab"
      assert_select "li#withdrawn_tab"
    end
  end

  def test_assert_false_connection_questions
    current_user_is :f_admin_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)

    get :index, params: { view: Group::View::DETAILED, tab: Group::Status::PROPOSED}
    assert_response :success

    assert assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_false assigns(:connection_questions).present?
  end

  def test_assert_connection_questions_for_proposed_view
    current_user_is :f_admin_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)
    2.times do
      create_group(name: "Mad Men - Donald Draper", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Orange is the new black", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")

    get :index, params: { view: Group::View::DETAILED, tab: Group::Status::PROPOSED}
    assert_response :success

    assert assigns(:is_proposed_connections_view)
    assert_false assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 6, drafted: 1, rejected: 4, withdrawn: 1, pending: 5, ongoing: 1, closed: 0}), assigns(:tab_counts)
    assert assigns(:connection_questions).present?
    assert_false assigns(:my_filters).include?({"label"=>"Survey Response", "reset_suffix"=>"survey_filter"})
  end

  def test_assert_connection_questions_for_rejected_view
    current_user_is :f_admin_pbe
    rejected_groups = []
    proposed_groups = []
    program = programs(:pbe)

    2.times do
      create_group(name: "Mad Men - Donald Draper", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    2.times do
      create_group(name: "Orange is the new black", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")

    get :index, params: { view: Group::View::DETAILED, tab: Group::Status::REJECTED}
    assert_response :success

    assert_false assigns(:is_proposed_connections_view)
    assert assigns(:is_rejected_connections_view)
    assert_equal_hash ({proposed: 6, drafted: 1, rejected: 4, pending: 5, ongoing: 1, closed: 0, withdrawn: 1}), assigns(:tab_counts)
    assert assigns(:connection_questions).present?
    assert_false assigns(:my_filters).include?({"label"=>"Survey Response", "reset_suffix"=>"survey_filter"})
  end

  def test_fetch_bulk_actions_accept_proposal
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group = create_group(name: "Betty Draper", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    Group.any_instance.stubs(:has_past_start_date?).returns(true)

    get :fetch_bulk_actions, xhr: true, params: { bulk_action: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: [group], tab_number: Group::Status::PROPOSED}, individual_action: true}

    assert_response :success
    assert_match ProposedProjectAccepted.mailer_attributes[:uid], @response.body

    assert_select ".modal-header" do
      assert_select "h4", text: "Accept & Make Available"
    end
    assert assigns(:show_start_date_field)
    assert assigns(:mentoring_models).present?
    assert assigns(:individual_action)
    assert_equal [group.id.to_s], assigns(:group_ids)
    assert_equal [group], assigns(:groups)
    assert_equal Group::BulkAction::ACCEPT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal Group::Status::PROPOSED, assigns(:tab_number)
  end

  def test_fetch_bulk_actions_accept_proposal_for_no_show_start_date_field
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    program.update_attribute(:allow_circle_start_date, false)
    group = create_group(name: "Betty Draper", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    Group.any_instance.stubs(:has_past_start_date?).returns(true)

    get :fetch_bulk_actions, xhr: true, params: {bulk_action: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: [group], tab_number: Group::Status::PROPOSED}, individual_action: true}

    assert_response :success
    assert_false assigns(:show_start_date_field)
  end

  def test_fetch_bulk_actions_accept_proposal_for_multiple_groups
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    groups = []

    Group.any_instance.stubs(:has_past_start_date?).returns(true)

    2.times do
      groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    get :fetch_bulk_actions, xhr: true, params: { bulk_action: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id), tab_number: Group::Status::PROPOSED}}
    assert_response :success

    assert_select ".modal-header" do
      assert_select "h4", text: "Accept & Make Available"
    end

    assert_false assigns(:show_start_date_field)
    assert assigns(:mentoring_models).present?
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal groups, assigns(:groups)
    assert_false assigns(:individual_action)
    assert_equal Group::BulkAction::ACCEPT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal Group::Status::PROPOSED, assigns(:tab_number)

    Group.any_instance.stubs(:has_past_start_date?).returns(false)

    get :fetch_bulk_actions, xhr: true, params: {bulk_action: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id), tab_number: Group::Status::PROPOSED}}

    assert_response :success
    assert_false assigns(:show_start_date_field)
  end

  def test_group_proposal_accepted
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    groups = []

    2.times do
      groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    groups.each {|g| Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, g)}
    assert_emails 2 do
      post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}, with_new_start_date: "false", start_date: "April 19, 2028"}
    end
    assert_response :success

    assigns(:groups).each(&:reload)
    assert_equal groups, assigns(:groups)
    assert_equal [], assigns(:groups_with_past_start_date)
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal [Group::Status::PENDING] * 2, assigns(:groups).collect(&:status)
    assert_equal [mentoring_model] * 2, assigns(:groups).collect(&:mentoring_model)
    assert_equal Group::BulkAction::ACCEPT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal [], groups.first.owners
    assert_equal [], groups.last.owners
    assert_nil groups.first.start_date
    assert_false assigns(:made_proposer_owner)
  end

  def test_group_proposal_accepted_for_past_start_date_flash
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    groups = []

    2.times do
      groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id, start_date: Time.now - 2.days)
    end
    
    assert_no_emails do
      post :update_bulk_actions, xhr: true, params: {mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}}
    end
    
    assert_response :success
    
    assert_equal groups, assigns(:groups_with_past_start_date)
    assert_equal ["Couldn't complete the action as the start date of mentoring connection(s) #{groups.map{|group| ActionController::Base.helpers.link_to(group.name, profile_group_path(group), target: "_blank")}.join(", ").html_safe} are already past. Please set a new start for mentioned mentoring connections to complete the action in bulk."], assigns(:error_flash)
  end

  def test_group_proposal_accepted_for_past_start_date_flash_with_setting_disabled
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    program.update_attribute(:allow_circle_start_date, false)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    groups = []

    2.times do
      groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id, start_date: Time.now-2.days)
    end
    
    post :update_bulk_actions, xhr: true, params: {mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}}
    
    assert_response :success
    
    assert_equal [], assigns(:groups_with_past_start_date)
    assert_nil assigns(:error_flash)
  end

  def test_group_proposal_accepted_with_owner
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    group1 = create_group(name: "Claire Underwood - Francis Underwood", mentors: [users(:f_mentor_pbe)], students: [users(:f_student_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    group2 = create_group(name: "Claire Underwood - Francis Underwood", mentors: [users(:f_mentor_pbe)], students: [users(:f_student_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_student_pbe).id)

    Member.any_instance.stubs(:get_valid_time_zone).returns("Asia/Kolkata")

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, group1)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, group2)
    assert_emails 2 do
      post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: [group1.id, group2.id].join(" "), tab_number: Group::Status::PROPOSED}, make_proposer_owner: true, with_new_start_date: "true", :start_date => "April 19, 2010"}
    end
    assert_response :success

    assert_equal [users(:f_mentor_pbe)], group1.reload.owners
    assert_equal [users(:f_student_pbe)], group2.reload.owners
    assert_equal "April 19, 2010".to_time.in_time_zone("Asia/Kolkata").to_date, group1.start_date.in_time_zone("Asia/Kolkata").to_date
    assert_equal "April 19, 2010".to_time.in_time_zone("Asia/Kolkata").to_date, group2.start_date.in_time_zone("Asia/Kolkata").to_date
    assert_equal [group1, group2], assigns(:groups_with_past_start_date)
  end

  def test_group_proposal_accepted_with_owner_not_part_of_group
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    group1 = create_group(name: "Claire Underwood - Francis Underwood", mentors: [], students: [users(:f_student_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    group2 = create_group(name: "Claire Underwood - Francis Underwood", mentors: [users(:f_mentor_pbe)], students: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_student_pbe).id)

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, group1)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, group2)
    assert_emails 2 do
      post :update_bulk_actions, xhr: true, params: { mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: [group1.id, group2.id].join(" "), tab_number: Group::Status::PROPOSED}, make_proposer_owner: true}
    end
    assert_response :success

    assert_equal [], group1.reload.owners
    assert_equal [], group2.reload.owners
    assert_false assigns(:made_proposer_owner)
  end

  def test_group_proposal_accepted_from_profile
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    groups = []
    groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, groups.first)
    assert_emails 1 do
      post :update_bulk_actions, params: { src: "profile", mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}}
    end
    assert_redirected_to profile_group_path(groups.first)
    assert_equal profile_group_path(groups.first), assigns(:redirect_path)
    assigns(:groups).each(&:reload)
    assert_equal groups, assigns(:groups)
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal [Group::Status::PENDING], assigns(:groups).collect(&:status)
    check_group_state_change_unit(assigns(:groups)[0], GroupStateChange.last, Group::Status::PROPOSED)
    assert_equal [mentoring_model], assigns(:groups).collect(&:mentoring_model)
    assert_equal Group::BulkAction::ACCEPT_PROPOSAL.to_s, assigns(:action_type)
  end

  def test_group_proposal_accepted_from_profile_with_owner
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    groups = []
    groups << create_group(name: "Claire Underwood - Francis Underwood", mentors: [users(:f_mentor_pbe)], students: [users(:f_student_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_ACCEPTED, groups.first)
    assert_emails 1 do
      post :update_bulk_actions, params: { src: "profile", mentoring_model: mentoring_model.id, bulk_actions: {action_type: Group::BulkAction::ACCEPT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}, make_proposer_owner: true}
    end
    assert_redirected_to profile_group_path(groups.first)

    assigns(:groups).each(&:reload)
    assert_equal groups, assigns(:groups)
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal [Group::Status::PENDING], assigns(:groups).collect(&:status)
    assert_equal [mentoring_model], assigns(:groups).collect(&:mentoring_model)
    assert_equal Group::BulkAction::ACCEPT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal [users(:f_mentor_pbe)], assigns(:groups).collect(&:owners).flatten
  end

  def test_fetch_bulk_actions_reject_proposal
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    group = create_group(name: "Betty Draper", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    get :fetch_bulk_actions, xhr: true, params: { bulk_action: {action_type: Group::BulkAction::REJECT_PROPOSAL, group_ids: [group], tab_number: Group::Status::PROPOSED}}
    assert_response :success
    assert_match ProposedProjectRejected.mailer_attributes[:uid], @response.body

    assert_select ".modal-header" do
      assert_select "h4", text: "Reject Mentoring Connection"
    end

    assert_equal [group.id.to_s], assigns(:group_ids)
    assert_equal [group], assigns(:groups)
    assert_equal Group::BulkAction::REJECT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal Group::Status::PROPOSED, assigns(:tab_number)
  end

  def test_fetch_bulk_actions_reject_proposal_for_multiple_groups
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    groups = []

    2.times do
      groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    get :fetch_bulk_actions, xhr: true, params: { bulk_action: {action_type: Group::BulkAction::REJECT_PROPOSAL, group_ids: groups.collect(&:id), tab_number: Group::Status::PROPOSED}}
    assert_response :success

    assert_select ".modal-header" do
      assert_select "h4", text: "Reject Mentoring Connection"
    end

    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal groups, assigns(:groups)
    assert_equal Group::BulkAction::REJECT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal Group::Status::PROPOSED, assigns(:tab_number)
  end

  def test_group_proposal_rejected
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    groups = []

    2.times do
      groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end

    groups.each {|g| Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_REJECTED, g)}
    assert_emails 2 do
      post :update_bulk_actions, xhr: true, params: { bulk_actions: {message: "You did not feed the dragons", action_type: Group::BulkAction::REJECT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}}
    end
    assert_response :success

    assigns(:groups).each(&:reload)
    assert_equal groups, assigns(:groups)
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal [Group::Status::REJECTED] * 2, assigns(:groups).collect(&:status)
    assert_equal Group::BulkAction::REJECT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal ["You did not feed the dragons"] * 2, assigns(:groups).collect(&:termination_reason)
  end

  def test_available_project_withdrawn_bulk_action
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    groups = []

    2.times do
      groups << create_group(name: "Neel Caffrey - Peter Burke", students: [users(:f_student_pbe)], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_mentor_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end

    assert_emails 4 do
      post :update_bulk_actions, xhr: true, params: { bulk_actions: {message: "You did not feed the dragons", action_type: Group::BulkAction::WITHDRAW_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::WITHDRAWN}}
    end
    assert_response :success

    assigns(:groups).each(&:reload)
    assert_equal groups, assigns(:groups)
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal [Group::Status::WITHDRAWN] * 2, assigns(:groups).collect(&:status)
    assert_equal Group::BulkAction::WITHDRAW_PROPOSAL.to_s, assigns(:action_type)
    assert_equal ["You did not feed the dragons"] * 2, assigns(:groups).collect(&:termination_reason)
  end

  def test_available_project_withdrawn_admin_from_profile
    current_user_is :f_admin_pbe
    program = programs(:pbe)

    group = create_group(name: "Neel Caffrey - Peter Burke", students: [users(:f_student_pbe)], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_mentor_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)

    assert_emails 2 do
      post :withdraw, xhr: true, params: { src: "profile", :id => group.id, withdraw_message: "White Collar"}
    end

    assert_redirected_to profile_group_path(group)

    group.reload
    assert_equal true, group.withdrawn?
    assert_equal "White Collar", group.termination_reason
    assert_equal users(:f_admin_pbe), group.closed_by
    assert_not_nil group.closed_at
  end

  def test_available_project_withdrawn_owner_from_profile
    current_user_is :f_mentor
    groups(:mygroup).membership_of(users(:f_mentor)).update_attributes!(owner: true)

    assert_emails 1 do
      post :withdraw, xhr: true, params: { src: "profile", :id => groups(:mygroup).id, withdraw_message: "Words are wind"}
    end

    assert_redirected_to profile_group_path(groups(:mygroup))
    group = groups(:mygroup).reload
    assert_equal true, group.withdrawn?
    assert_equal "Words are wind", group.termination_reason
    assert_equal users(:f_mentor), group.closed_by
    assert_not_nil group.closed_at
  end

  def test_available_project_withdrawn_member_from_profile
    current_user_is :f_mentor
    group = groups(:mygroup)
    assert_permission_denied  do
      post :withdraw, xhr: true, params: { src: "profile", :id => group.id, withdraw_message: "Words are wind"}
    end
  end

  def test_group_proposal_rejected_from_profile
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    mentoring_model = create_mentoring_model(program_id: program.id)
    program.mentoring_models.reload
    groups = []
    groups << create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PROPOSAL_REJECTED, groups.first)
    assert_emails 1 do
      post :update_bulk_actions, params: { src: "profile", bulk_actions: {message: "Hunt or be hunted", action_type: Group::BulkAction::REJECT_PROPOSAL, group_ids: groups.collect(&:id).join(" "), tab_number: Group::Status::PROPOSED}}
    end
    assert_redirected_to profile_group_path(groups.first)

    assigns(:groups).each(&:reload)
    assert_equal groups, assigns(:groups)
    assert_equal groups.collect{|group| group.id.to_s }, assigns(:group_ids)
    assert_equal [Group::Status::REJECTED], assigns(:groups).collect(&:status)
    assert_equal Group::BulkAction::REJECT_PROPOSAL.to_s, assigns(:action_type)
    assert_equal ["Hunt or be hunted"], assigns(:groups).collect(&:termination_reason)
  end

  def test_fetch_owners_access_by_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)

    assert_false student_user.can_manage_project_requests?
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)

    assert student_user.is_owner_of?(groups(:group_pbe_2))
    get :fetch_owners, xhr: true, params: { id: groups(:group_pbe_2).id, from_index: true, tab: "5", view: "1"}

    assert_equal groups(:group_pbe_2).id, assigns(:group).id
    assert_equal 1, assigns(:view)
    assert assigns(:from_index)
    assert_equal 5, assigns(:tab_number)
  end

  def test_fetch_owners_access_by_owner_no_permission
    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)
    assert_false student_user.can_manage_project_requests?
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)

    assert_false student_user.is_owner_of?(groups(:group_pbe_3))
    assert_permission_denied  do
      get :fetch_owners, xhr: true, params: { id: groups(:group_pbe_3).id}
    end
  end

  def test_fetch_owners_access_by_admin
    current_user_is :f_admin_pbe
    current_program_is :pbe
    admin_user = users(:f_admin_pbe)

    assert admin_user.can_manage_project_requests?

    assert_false admin_user.is_owner_of?(groups(:group_pbe_2))
    get :fetch_owners, xhr: true, params: { id: groups(:group_pbe_2).id}
    assert_match GroupOwnerAdditionNotification.mailer_attributes[:uid], @response.body

    assert_equal groups(:group_pbe_2).id, assigns(:group).id
  end

  def test_fetch_owners_access_by_non_admin_non_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)

    assert_false student_user.can_manage_project_requests?
    assert_false student_user.is_owner_of?(groups(:group_pbe_2))

    assert_permission_denied  do
      get :fetch_owners, xhr: true, params: { id: groups(:group_pbe_2).id}
    end
  end


  def test_update_owners_access_by_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)
    mentor_user = users(:pbe_mentor_2)

    assert_false student_user.can_manage_project_requests?
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)

    assert student_user.is_owner_of?(groups(:group_pbe_2))
    assert_emails 1 do
      put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id, group_owner: mentor_user.id, from_index: true, tab: "5", view: "1"}
    end

    assert_equal groups(:group_pbe_2).id, assigns(:group).id
    assert_equal 1, assigns(:view)
    assert assigns(:from_index)
    assert_equal 5, assigns(:tab_number)
    assert_false assigns(:is_manage_connections_view)
    assert_false student_user.is_owner_of?(groups(:group_pbe_2))
    assert mentor_user.is_owner_of?(groups(:group_pbe_2))

    email = ActionMailer::Base.deliveries.last
    assert_match /You are now an owner of project_c/, email.subject
    assert_equal [mentor_user.email], email.to
    mail_content = get_html_part_from(email)
    assert_match /Congratulations! We've added you as an owner /, mail_content
    assert_match /Visit the mentoring connection/, mail_content

    assert_permission_denied  do
      put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id}
    end
  end

  def test_update_owners_no_change
    current_user_is :f_admin_pbe
    current_program_is :pbe
    admin_user = users(:f_admin_pbe)
    student_user = users(:pbe_student_2)

    assert admin_user.can_manage_project_requests?

    assert_false admin_user.is_owner_of?(groups(:group_pbe_2))
    assert_equal [], groups(:group_pbe_2).owners
    assert_emails 0 do
      put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id, group_owner: ""}
    end
  end

  def test_update_owners_nochange_1
    current_user_is :f_admin_pbe
    current_program_is :pbe
    admin_user = users(:f_admin_pbe)
    student_user = users(:pbe_student_2)

    assert admin_user.can_manage_project_requests?

    assert_false admin_user.is_owner_of?(groups(:group_pbe_2))
    assert_equal [], groups(:group_pbe_2).owners

    groups(:group_pbe_2).reload
    assert_equal [], groups(:group_pbe_2).owners

    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)

    assert student_user.is_owner_of?(groups(:group_pbe_2))

    assert_emails 0 do
      put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id, group_owner: student_user.id}
    end
    groups(:group_pbe_2).reload
    assert_equal [student_user], groups(:group_pbe_2).owners
  end

  def test_update_owners_multiple_users
    current_user_is :f_admin_pbe
    current_program_is :pbe
    admin_user = users(:f_admin_pbe)
    student_user = users(:pbe_student_2)
    mentor_user = users(:pbe_mentor_2)

    assert admin_user.can_manage_project_requests?

    assert_false admin_user.is_owner_of?(groups(:group_pbe_2))
    assert_equal [], groups(:group_pbe_2).owners
    assert_emails 2 do
      put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id, group_owner: "#{student_user.id},#{mentor_user.id}"}
    end
    groups(:group_pbe_2).reload
    assert_equal_unordered [mentor_user, student_user], groups(:group_pbe_2).owners
  end

  def test_update_owners_access_by_admin
    current_user_is :f_admin_pbe
    current_program_is :pbe
    admin_user = users(:f_admin_pbe)
    student_user = users(:pbe_student_2)

    assert admin_user.can_manage_project_requests?

    assert_false admin_user.is_owner_of?(groups(:group_pbe_2))
    put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id, group_owner: student_user.id}

    assert_equal groups(:group_pbe_2).id, assigns(:group).id
  end

  def test_update_owners_access_by_non_admin_non_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)

    assert_false student_user.can_manage_project_requests?
    assert_false student_user.is_owner_of?(groups(:group_pbe_2))

    assert_permission_denied  do
      put :update_owners, xhr: true, params: { id: groups(:group_pbe_2).id}
    end
  end

  def test_index_survey_filter_text_based_substring
    current_user_is :f_admin
    setup_engagement_survey_answers_for_text_based
    ans = SurveyAnswer.last
    get :index, params: { search_filters: {survey_response: {survey_id: ans.task.action_item.id, question_id: ans.common_question_id, answer_text: "i am good"}}}
    assert assigns[:groups].include?(@group)
  end

  def test_index_survey_filter_text_based_extra_word
    current_user_is :f_admin
    setup_engagement_survey_answers_for_text_based
    ans = SurveyAnswer.last
    get :index, params: { search_filters: {survey_response: {survey_id: ans.task.action_item.id, question_id: ans.common_question_id, answer_text: "very good"}}}
    assert_false assigns[:groups].include?(@group)
    assigns(:my_filters).include?({:label=>"Survey Response", :reset_suffix=>"survey_filter"})
  end

  def test_index_survey_filter_text_based
    current_user_is :f_admin
    setup_engagement_survey_answers_for_text_based
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    get :index, params: { search_filters: {survey_response: {survey_id: survey.id, question_id: survey.survey_questions.where(question_type: CommonQuestion::Type::TEXT).first.id, answer_text: "good"}}}
    assert_false assigns[:groups].include?(@group)
    assigns(:my_filters).include?({:label=>"Survey Response", :reset_suffix=>"survey_filter"})
  end

  def test_index_survey_filter_choice_based_no_choice
    current_user_is :f_admin
    setup_engagement_survey_answers_for_choice_based
    choices_hash = @question.question_choices.index_by(&:text)
    get :index, params: { search_filters: {survey_response: {survey_id: @survey.id, question_id: @question.id, answer_text: choices_hash["go"].id}}}
    assert_false assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Response", :reset_suffix=>"survey_filter"})
  end

  def test_index_survey_filter_choice_based_subset_choice
    current_user_is :f_admin
    setup_engagement_survey_answers_for_choice_based
    choices_hash = @question.question_choices.index_by(&:text)
    get :index, params: { search_filters: {survey_response: {survey_id: @survey.id, question_id: @question.id, answer_text: "#{choices_hash['set'].id}, #{choices_hash['go'].id}"}}}
    assert assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Response", :reset_suffix=>"survey_filter"})
  end

  def test_index_survey_filter_choice_base_other_choice
    current_user_is :f_admin
    setup_engagement_survey_answers_for_choice_based
    get :index, params: { search_filters: {survey_response: {survey_id: @survey.id, question_id: @question.id, answer_text: @question.question_choices.find_by(text: "run").id}}}
    assert assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Response", :reset_suffix=>"survey_filter"})
  end

  def test_index_survey_filter_choice_based_extra_text
    current_user_is :f_admin
    setup_engagement_survey_answers_for_choice_based
    get :index, params: { search_filters: {survey_response: {survey_id: @survey.id, question_id: @question.id, answer_text: "9999999"}}}
    assert_false assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Response", :reset_suffix=>"survey_filter"})
  end

  def test_index_survey_status_filter_task_completed
    current_user_is :f_admin
    prog = programs(:albers)
    mentoring_model = prog.default_mentoring_model
    @group = groups(:mygroup)
    mentoring_model.update_attribute(:should_sync, true)
    @group.update_attribute(:mentoring_model_id, mentoring_model.id)
    @survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    @question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::MULTI_STRING, :question_text => "What is your name?", :survey => @survey})
    tem_task1 = create_mentoring_model_engagement_survey_task_template(action_item_id: @survey.id)
    membership = @group.mentor_memberships.first


    options = {:created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY,  :action_item_id => @survey.id, :group_id => @group.id, :group => groups(:mygroup), :status => MentoringModel::Task::Status::DONE}

    task1 = create_mentoring_model_task(options)
    create_survey_answer({:answer_text => "remove mentee", :response_id => 2, :last_answered_at => Time.now + 2.days, :survey_id => @survey.id, :survey_question => @question, :group_id => @group.id, :task_id => task1.id})

    get :index, params: { search_filters: {survey_status: {survey_id: @survey.id, survey_task_status: MentoringModel::Task::StatusFilter::COMPLETED.to_s}}}
    assert assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Status", :reset_suffix=>"survey_status_filter"})
  end

  def test_index_survey_status_filter_task_not_completed
    current_user_is :f_admin
    setup_engagement_survey_answers_for_choice_based
    get :index, params: { search_filters: {survey_status: {survey_id: @survey.id, survey_task_status: MentoringModel::Task::StatusFilter::NOT_COMPLETED.to_s}}}
    assert assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Status", :reset_suffix=>"survey_status_filter"})
  end

  def test_index_survey_status_filter_task_overdue
    current_user_is :f_admin
    prog = programs(:albers)
    mentoring_model = prog.default_mentoring_model
    @group = groups(:mygroup)
    mentoring_model.update_attribute(:should_sync, true)
    @group.update_attribute(:mentoring_model_id, mentoring_model.id)
    @survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    @question = create_survey_question({allow_other_option: true, question_type: CommonQuestion::Type::SINGLE_CHOICE, question_choices: "get,set,go", survey: @survey})
    tem_task1 = create_mentoring_model_engagement_survey_task_template(action_item_id: @survey.id)
    membership = @group.mentor_memberships.first


    options = {:due_date => 2.weeks.ago, :created_at => "July 04, 2016", :action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, :required => true, :action_item_id => @survey.id, :group_id => @group.id, :group => groups(:mygroup)}

    task1 = create_mentoring_model_task(options)

    get :index, params: { search_filters: {survey_status: {survey_id: @survey.id, survey_task_status: MentoringModel::Task::StatusFilter::OVERDUE.to_s}}}
    assert assigns[:groups].include?(@group)
    assert assigns(:my_filters).include?({:label=>"Survey Status", :reset_suffix=>"survey_status_filter"})
  end

  def test_fetch_survey_questions_permission_denied_mentor
    current_user_is :f_mentor
    prog = programs(:albers)
    assert_permission_denied  do
      get :fetch_survey_questions, xhr: true
    end
  end

  def test_fetch_survey_questions_permission_denied_student
    current_user_is :f_student
    prog = programs(:albers)
    assert_permission_denied  do
      get :fetch_survey_questions, xhr: true
    end
  end

  def test_fetch_survey_questions_no_params
    current_user_is :f_admin
    prog = programs(:albers)
    get :fetch_survey_questions, xhr: true
    assert_nil assigns(:engagement_survey)
    assert_nil assigns(:survey_questions)
    assert_false assigns(:is_reports_view)
  end

  def test_fetch_survey_questions
    current_user_is :f_admin
    prog = programs(:albers)
    survey = prog.surveys.of_engagement_type.sample
    create_matrix_survey_question(survey: survey)
    get :fetch_survey_questions, xhr: true, params: { survey_id: survey.id, is_reports_view: true}
    assert_equal survey, assigns(:engagement_survey)
    assert_equal survey.get_questions_in_order_for_report_filters, assigns(:survey_questions)
    assert assigns(:is_reports_view)
  end

  def test_fetch_survey_questions_program_survey
    current_user_is :f_admin
    prog = programs(:albers)
    survey = prog.surveys.of_program_type.sample
    assert_record_not_found do
      get :fetch_survey_questions, xhr: true, params: { survey_id: survey.id}
    end
  end

  def test_fetch_survey_answers_permission_denied_mentor
    current_user_is :f_mentor
    prog = programs(:albers)
    assert_permission_denied  do
      get :fetch_survey_answers, xhr: true
    end
  end

  def test_fetch_survey_answers_permission_denied_student
    current_user_is :f_student
    prog = programs(:albers)
    assert_permission_denied  do
      get :fetch_survey_answers, xhr: true
    end
  end

  def test_fetch_survey_answers_no_params
    current_user_is :f_admin
    prog = programs(:albers)
    get :fetch_survey_answers, xhr: true
    assert_nil assigns(:survey_question)
    assert_false assigns(:is_reports_view)
  end

  def test_fetch_survey_answers
    current_user_is :f_admin
    prog = programs(:albers)
    survey = prog.surveys.of_engagement_type.sample
    create_matrix_survey_question({survey: survey})
    question = survey.survey_questions.not_matrix_questions.sample
    get :fetch_survey_answers, xhr: true, params: { survey_id: survey.id, question_id: question.id}
    assert_equal question, assigns(:survey_question)

    question = survey.survey_questions_with_matrix_rating_questions.matrix_rating_questions.sample
    get :fetch_survey_answers, xhr: true, params: { survey_id: survey.id, question_id: question.id, is_reports_view: true}
    assert_equal question, assigns(:survey_question)
    assert assigns(:is_reports_view)
  end

  def test_fetch_survey_answers_program_survey
    current_user_is :f_admin
    prog = programs(:albers)
    survey = prog.surveys.of_program_type.sample
    assert_record_not_found do
      get :fetch_survey_answers, xhr: true, params: { survey_id: survey.id}
    end
  end

  def test_fetch_survey_answers_engagement_survey_formatting
    current_user_is :f_admin
    prog = programs(:albers)
    survey = prog.surveys.of_engagement_type.first
    question = survey.survey_questions.select{|sq| sq.choice_based?}[0]
    question.question_choices.destroy_all
    question.question_choices.index_by(&:text)
    # testing many possibilities
    "aaa,bbb,ccc,</script>,ko,<script>alert('okok')</script>,<b>,</b>,</ script>,< /script>,< /  script>,'ko',\"lp\",\"ko'lp\"".split(",").each_with_index{|qc, pos| question.question_choices.create!(text: qc, position: pos +1, is_other: false)}
    get :fetch_survey_answers, xhr: true, params: { survey_id: survey.id, question_id: question.id}
    assert_equal question, assigns(:survey_question)
    assert_equal "displaySurveyAnswerChoices(\\'#{question.question_choices.collect(&:id).join(CommonQuestion::SELECT2_SEPARATOR)}\\', \\'aaa/~bbb/~ccc/~<\\\\/script>/~ko/~<script>alert(\\\\\\'okok\\\\\\')<\\\\/script>/~<b>/~<\\\\/b>/~<\\\\/ script>/~< /script>/~< /  script>/~\\\\\\'ko\\\\\\'/~\\\\\\\"lp\\\\\\\"/~\\\\\\\"ko\\\\\\'lp\\\\\\\"\\', \\'\\', \\'/~\\')\\n//]]>\\n<\\/script>\");", response.body.match(/displaySurveyAnswerChoices.*/)[0]
  end

  def test_group_params_with_filters_applied_param
    current_user_is :f_admin
    program = programs(:albers)
    view = program.abstract_views.where(default_view: [AbstractView::DefaultType::ACTIVE_BUT_BEHIND_CONNECTIONS]).first
    assert_not_nil view

    get :index, params: { abstract_view_id: view.id, filters_applied: "true"}
    assert_equal GroupsController::StatusFilters::Code::ONGOING, assigns(:status_filter)

    get :index, params: { abstract_view_id: view.id}
    assert_equal GroupsController::StatusFilters::Code::ACTIVE, assigns(:status_filter)
  end

  def test_new_action_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_admin
    #changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    assert_permission_denied  do
      get :new
    end
  end

  def test_show_action_for_program_with_disabled_ongoing_mentoring
    current_user_is users(:f_mentor)

    #changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    assert_permission_denied  do
      get :show, params: { :id => groups(:mygroup).id}
    end
  end

  def test_create_action_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_admin
    mentor = users(:f_mentor)
    student = users(:f_student)
    mentor_request = mentor_requests(:mentor_request_1)

    #changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    assert_permission_denied  do
      post :create, xhr: true, params: { :group => {
        :mentor_name => mentor.name_with_email},
        :mentor_request_id => mentor_request.id
      }
    end
  end

  def test_index_action_for_program_with_disabled_ongoing_mentoring
    current_user_is :f_mentor

    #changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    assert_permission_denied  do
      get :index, params: { :show => 'my'}
    end
  end

  def test_index_action_for_mentor_with_onetime_mentoring_mode_and_has_active_group
    current_user_is :f_mentor

    #changing allow mentoring mode change of program to editable
    programs(:albers).update_attribute :allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE

    #changing mentoring mode of mentor to onetime
    users(:f_mentor).update_attribute :mentoring_mode, User::MentoringMode::ONE_TIME
    get :index, params: { :show => 'my'}
    assert_response :success
  end

  def test_index_action_for_mentor_with_onetime_mentoring_mode_and_no_active_group
    current_user_is :f_mentor_student

    #changing allow mentoring mode change of program to editable
    programs(:albers).update_attribute :allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE
    programs(:albers).enable_feature("calendar", true)

    #changing mentoring mode of mentor to onetime
    users(:f_mentor_student).update_attribute :mentoring_mode, User::MentoringMode::ONE_TIME
    assert_permission_denied  do
      get :index, params: { :show => 'my'}
    end
  end

  def test_index_action_for_admin_mentor_with_onetime_mentoring_mode
    current_user_is :ram

    #changing allow mentoring mode change of program to editable
    programs(:albers).update_attribute :allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE

    #changing mentoring mode of mentor to onetime
    users(:ram).update_attribute :mentoring_mode, User::MentoringMode::ONE_TIME

    assert_nothing_raised  do
      get :index
    end
  end

  def test_index_with_dashboard_filters
    current_user_is :f_admin

    dashboard_params = {"type" => GroupsController::DashboardFilter::GOOD, "start_date" => "15/05/2017", "end_date" => "18/06/2018"}
    @controller.stubs(:handle_dashboard_health_filters).with(dashboard_params).returns(7)
    get :index, params: { dashboard: dashboard_params }

    assert_equal 7, assigns(:dashboard_filtered_groups_count)
  end

  def test_show_coach_rating_for_mentee
    program = programs(:albers)
    group = groups(:mygroup)
    program.enable_feature(FeatureName::COACH_RATING)
    recipient_id = group.mentors.first.id
    current_user_is :mkr_student

    get :show, params: { :id => group.id, :coach_rating => recipient_id}
    assert_equal new_feedback_response_path(group_id: group.id, recipient_id: recipient_id), assigns(:response_url)
  end

  def test_show_coach_rating_for_mentee_trying_to_rate_mentor_from_different_group
    program = programs(:albers)
    group = groups(:mygroup)
    program.enable_feature(FeatureName::COACH_RATING)
    recipient_user = users(:mentor_1)
    current_user_is :mkr_student

    get :show, params: { :id => group.id, :coach_rating => recipient_user.id}

    assert_false group.has_mentor?(recipient_user)
    assert_nil assigns(:response_url)
  end

  def test_show_coach_rating_for_mentee_no_feature
    program = programs(:albers)
    group = groups(:mygroup)
    current_user_is :mkr_student

    get :show, params: { :id => group.id, :coach_rating => group.mentors.first.id}
    assert_nil assigns(:response_url)
  end

  def test_show_coach_rating_for_mentor
    program = programs(:albers)
    group = groups(:mygroup)
    program.enable_feature(FeatureName::COACH_RATING)
    current_user_is :f_mentor

    get :show, params: { :id => group.id, :coach_rating => "444"}
    assert_nil assigns(:show_rating_popup)
  end

  def test_group_side_pane_for_manual_progress_goals
    group = groups(:mygroup)
    program = programs(:albers)
    current_user_is :f_mentor

    create_object_role_permission("manage_mm_goals", role: "users", object: group)
    mmg1 = create_mentoring_model_goal
    mmg2 = create_mentoring_model_goal
    mentoring_model = group.program.mentoring_models.first
    mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    goal_template = create_mentoring_model_goal_template(mentoring_model_id: mentoring_model.id)
    mmg1.update_attribute(:mentoring_model_goal_template, mentoring_model.mentoring_model_goal_templates.first)
    mmg2.update_attribute(:mentoring_model_goal_template, mentoring_model.mentoring_model_goal_templates.first)
    group.update_attribute(:mentoring_model, mentoring_model)

    get :show, params: { :id => group.id}
    assert_response :success
    assert_select "div.cjs_side_pane_mentoring_model_goals" do
      assert_select "div#cui-manual-progress-goal-progressbar-container-#{mmg2.id}"
      assert_select "div#cui-manual-progress-goal-progressbar-container-#{mmg1.id}"
    end
  end

  def test_assign_from_match_existing_connection_xss
    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(programs(:albers))
    mentor = users(:f_mentor)
    student = users(:f_student)
    group = groups(:mygroup)

    assert_emails 1 do
      assert_no_difference "Group.count" do
        assert_difference "Connection::Membership.count", 1 do
          post :assign_from_match, params: { :student_id => student.id, :mentor_id => mentor.id, :group_id => group.id, :message => "<script>alert(\"Please connect.\")</script>"}
        end
      end
    end

    group = assigns(:group)
    assert_equal [mentor], group.mentors
    assert_equal [users(:mkr_student), student], group.students
    assert group.assigned_from_match
    assert_redirected_to matches_for_student_users_path
    assert_equal "<b>#{student.name}</b> has been assigned to the mentoring connection", flash[:notice]

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal [student.email], delivered_email.to
    assert_equal "You have been added as a student to name & madankumarrajan", delivered_email.subject
    assert_match "Your mentoring connection will end on #{formatted_time_in_words(group.expiry_time, :no_ago => true, :no_time => true)}", get_text_part_from(delivered_email)
  end

  def test_auto_complete_for_name
    current_program_is :albers
    current_user_is :f_admin
    program = programs(:albers)
    groups = program.groups.where(status: Group::Status::OPEN_CRITERIA).order(:published_at, :pending_at)
    get :auto_complete_for_name
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    response = JSON.parse(@response.body)
    assert_equal groups.count, response["total_count"]
    assert_equal groups.collect(&:id), response["groups"].map{ |group| group["groupId"] }
  end

  def test_auto_complete_for_name_with_id_to_ignore
    current_program_is :albers
    current_user_is :f_admin
    program = programs(:albers)
    groups = program.groups.where(status: Group::Status::OPEN_CRITERIA).order(:published_at, :pending_at)
    get :auto_complete_for_name, params: { groupIdToIgnore: groups.first.id }
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    response = JSON.parse(@response.body)
    assert_equal groups.count - 1, response["total_count"]
    assert_equal groups.collect(&:id)[1..groups.count], response["groups"].map{ |group| group["groupId"] }
  end

   def test_auto_complete_for_name_search_text
    current_program_is :albers
    current_user_is :f_admin
    program = programs(:albers)
    group = program.groups.where(status: Group::Status::OPEN_CRITERIA).first
    get :auto_complete_for_name, params: { search: "madankumarrajan" }
    assert_response :success
    @response.stubs(:content_type).returns "application/json"
    response = JSON.parse(@response.body)
    assert_equal 1, response["total_count"]
    assert_equal [group.id], response["groups"].map{ |group| group["groupId"] }
  end

  def test_get_similar_circles
    current_program_is :pbe
    current_user_is :f_admin_pbe
    program = programs(:pbe)
    groups = program.groups.where(status: Group::Status::OPEN_CRITERIA).order(:published_at, :pending_at)

    get :get_similar_circles, xhr: true
    assert_response :success
    assert_equal_unordered groups, assigns(:similar_circles)
  end

  def test_get_similar_circles_for_name_search_text
    current_program_is :pbe
    current_user_is :f_admin_pbe
    groups = [groups(:group_pbe_0), groups(:group_pbe_1), groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_4), groups(:group_pbe)]
    get :get_similar_circles, params: { search: "project_" }, xhr: true

    assert_response :success
    assert_equal_unordered groups, assigns(:similar_circles)
  end

  def test_get_similar_circles_should_not_list_circles_without_slot
    current_program_is :pbe
    current_user_is :pbe_mentor_0
    groups = [groups(:group_pbe_0), groups(:group_pbe_1), groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_4), groups(:group_pbe)]
    get :get_similar_circles, params: { search: "project_" }, xhr: true

    assert_response :success
    assert_equal_unordered groups, assigns(:similar_circles)

    group = groups(:group_pbe)
    assert 1, group.mentors.count
    role = programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME)
    group.membership_settings.create(role_id: role.id, max_limit: 1)
    reindex_documents(updated: group)
    get :get_similar_circles, params: { search: "project_" }, xhr: true

    assert_response :success
    assert_false assigns(:similar_circles).include?(group)
  end

  def test_update_from_admin_view
    current_program_is :albers
    current_user_is :f_admin
    @controller.expects(:handle_update_from_admin_view).once
    post :update, xhr: true, params: { id: groups(:mygroup).id, group: { src: "admin_view" }}
    assert_response :success
  end

  def test_update_bulk_actions_redirect
    current_user_is :f_admin_pbe
    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: programs(:pbe).groups.collect(&:id).join(" ") } }
    assert_redirected_to groups_path
  end

  def test_bulk_duplicate_groups
    current_user_is :f_admin
    user = users(:f_admin)
    program = programs(:albers)
    groups = program.groups.first(3)
    groups.each_with_index do |group, i|
      group.update_columns(name: i.to_s, status: Group::Status::CLOSED)
    end
    group_ids = groups.collect(&:id)
    note = "This is a note"

    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.join(" "), notes: note, message: message } }
    assert_response :success
    cloned_groups = program.groups.where(name: groups.collect(&:name)).where.not(id: group_ids)
    assert_equal groups.size, cloned_groups.size
    groups.each do |group|
      cloned_group = cloned_groups.find{ |cg| cg.name == group.name }
      assert_equal note, cloned_group.notes
      assert_equal group.members, cloned_group.members
      assert_equal group.mentors, cloned_group.mentors
      assert_equal group.students, cloned_group.students
      assert_equal group.custom_users, cloned_group.custom_users
    end
    assert_equal "Mentoring Connections published successfully", assigns(:success_flash)
    assert_equal "cjs_ongoing_count", assigns(:tab_id)
  end

  def test_bulk_duplicate_groups_with_mentoring_model
    current_user_is :f_admin
    user = users(:f_admin)
    program = programs(:albers)
    groups = program.groups.first(3)
    group_ids = groups.collect(&:id)
    groups.each_with_index do |group, i|
      group.update_columns(name: i.to_s, status: Group::Status::CLOSED)
    end
    mentoring_model = program.mentoring_models.last

    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.join(" "), assign_new_template: true }, mentoring_model: mentoring_model }
    assert_response :success
    cloned_groups = program.groups.where(name: groups.collect(&:name)).where.not(id: group_ids)
    assert_equal groups.size, cloned_groups.size
    groups.each do |group|
      cloned_group = cloned_groups.find{ |cg| cg.name == group.name }
      assert_equal mentoring_model, cloned_group.mentoring_model
      assert_equal group.members, cloned_group.members
      assert_equal group.mentors, cloned_group.mentors
      assert_equal group.students, cloned_group.students
      assert_equal group.custom_users, cloned_group.custom_users
    end
  end

  def test_bulk_duplicate_draft_groups
    current_user_is :f_admin
    user = users(:f_admin)
    program = programs(:albers)
    groups = program.groups.first(3)
    groups.each_with_index do |group, i|
      group.update_columns(name: i.to_s, status: Group::Status::CLOSED)
    end

    group_ids = groups.collect(&:id)

    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.join(" ") }, draft: "Save as draft" }
    assert_response :success
    cloned_groups = program.groups.where(name: groups.collect(&:name)).where.not(id: group_ids)
    assert_equal groups.size, cloned_groups.size
    groups.each do |group|
      cloned_group = cloned_groups.find{ |cg| cg.name == group.name }
      assert_equal Group::Status::DRAFTED, cloned_group.status
      assert_equal group.members, cloned_group.members
      assert_equal group.mentors, cloned_group.mentors
      assert_equal group.students, cloned_group.students
      assert_equal group.custom_users, cloned_group.custom_users
    end
    assert_equal "Mentoring Connections drafted successfully", assigns(:success_flash)
    assert_equal "cjs_drafted_count", assigns(:tab_id)
  end

  def test_bulk_duplicate_with_error
    current_user_is :f_admin
    user = users(:f_admin)
    program = programs(:albers)
    groups = program.groups.first(3)
    groups.each_with_index do |group, i|
      group.update_columns(name: i.to_s, status: Group::Status::CLOSED)
    end
    group_ids = groups.collect(&:id)
    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.join(" ") }, draft: "Save as draft" }
    assert_response :success

    assert_no_difference "Group.count" do
      post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.join(" ") }, draft: "Save as draft" }
    end
    error_flash = assigns(:error_flash).first
    groups.each do |group|
      assert_match /#{group.name} : /, error_flash
    end
  end

  def test_bulk_duplicate_with_warning
    current_user_is :f_admin
    user = users(:f_admin)
    program = programs(:albers)
    groups = program.groups.first(3)
    groups.each_with_index do |group, i|
      group.update_columns(name: i.to_s, status: Group::Status::CLOSED)
    end
    group_ids = groups.collect(&:id)
    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.first(2).join(" ") } }
    assert_response :success

    assert_difference "Group.count", 1 do
      post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::DUPLICATE, group_ids: group_ids.join(" ") } }
    end
    warning_flash = assigns(:success_flash)
    assert_match "1 out of 3 mentoring connections was duplicated successfully", warning_flash
    assert_match "2 mentoring connections were not duplicated", warning_flash
    groups.first(2).each do |group|
      assert_match /#{group.name} : /, warning_flash
    end
  end

  def test_export_csv_option_for_non_admin_non_member
    enable_project_based_engagements!
    current_user_is :rahim
    program = programs(:albers)
    search_filters = { :available_to_join => "all_projects"}
    get :find_new, xhr: true, params: { search_filters: search_filters, "view"=>"", "sort"=>"", "order"=>"", "tab"=>""}
    assert_response :success
    assert_no_match(/Export Mentoring Connection/, @response.body)
  end

  def test_profile_action_for_pending_groups_with_plan_tab
    current_user_is :pbe_mentor_0
    current_program_is :pbe
    p = programs(:pbe)
    g = p.groups.pending.first
    g.update_attribute(:global, false)
    mentoring_model = g.mentoring_model
    milestone_template = mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    task_template = mentoring_model.mentoring_model_task_templates.create!({
      milestone_template_id: milestone_template.id,
      required: true,
      title: "title",
      description: "description",
      duration: 10,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT,
      role_id: p.roles.first.id
    })

    get :profile, params: { :id => g.id}

    assert_response :success
    assert_equal assigns(:mentoring_model_milestones), [milestone_template]
    assert_equal assigns(:mentoring_model_tasks), [task_template]
    assert assigns(:is_pending_group_show_plan_tab)
    assert assigns(:is_group_profile_view)
    assert_select "ul.nav-tabs" do
      assert_select "li", count: 2
      assert_select "li.active" do
        assert_select "span", text: "Plan"
      end
      assert_select "li" do
        assert_select "span", text: "Discussion Board"
      end
    end
  end

  def test_profile_of_pending_group_with_profile_tab
    current_user_is :pbe_mentor_0
    group = groups(:group_pbe_0)
    program = group.program

    program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")

    get :profile, params: { id: group.id}
    assert_response :success
    assert assigns(:is_pending_group_show_profile_tab)
    assert assigns(:is_group_profile_view)
    assert_select "ul.nav-tabs" do
      assert_select "li.active" do
        assert_select "span", text: "Information"
      end
      assert_select "li" do
        assert_select "span", text: "Discussion Board"
      end
    end
  end

  def test_profile_action_for_pending_groups_obeys_tab_params
    current_user_is :pbe_mentor_0
    current_program_is :pbe
    program = programs(:pbe)
    group = program.groups.pending.first
    group.update_attribute(:global, false)
    mentoring_model = group.mentoring_model
    milestone_template = mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    task_template = mentoring_model.mentoring_model_task_templates.create!({
      milestone_template_id: milestone_template.id,
      required: true,
      title: "title",
      description: "description",
      duration: 10,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT,
      role_id: program.roles.first.id
    })

    program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")

    get :profile, params: { id: group.id, show_plan: true}

    assert_response :success
    assert_equal assigns(:mentoring_model_milestones), [milestone_template]
    assert_equal assigns(:mentoring_model_tasks), [task_template]
    assert assigns(:is_pending_group_show_plan_tab)
    assert assigns(:is_group_profile_view)
    assert_select "ul.nav-tabs" do
      assert_select "li", count: 3
      assert_select "li" do
        assert_select "span", text: "Information"
      end
      assert_select "li" do
        assert_select "span", text: "Discussion Board"
      end
      assert_select "li.active" do
        assert_select "span", text: "Plan"
      end
    end
  end

  def test_profile_of_pending_group_redirected_to_forum
    current_user_is :pbe_mentor_0
    group = groups(:group_pbe_0)

    assert group.forum_enabled?
    
    get :profile, params: { id: group.id, manage_circle_members: "true", show_set_start_date_popup: "true"}
    assert_redirected_to forum_path(group.forum, manage_circle_members: "true", show_set_start_date_popup: "true")

    assert_nil assigns(:is_pending_group_show_plan_tab)
    assert_nil assigns(:is_pending_group_show_profile_tab)
    assert_no_select "ul.nav-tabs"
  end

  def test_profile_of_pending_group_redirected_to_scraps
    current_user_is :pbe_mentor_0
    group = groups(:group_pbe_0)

    MentoringModel.any_instance.stubs(:allow_forum?).returns(false)
    MentoringModel.any_instance.stubs(:allow_messaging?).returns(true)

    get :profile, params: { id: group.id, manage_circle_members: "true", show_set_start_date_popup: "true"}
    assert_redirected_to group_scraps_path(group_id: group.id, manage_circle_members: "true", show_set_start_date_popup: "true")

    assert_nil assigns(:is_pending_group_show_plan_tab)
    assert_nil assigns(:is_pending_group_show_profile_tab)
    assert_no_select "ul.nav-tabs"
  end

  def test_profile_of_pending_group_not_redirected_to_forum_for_non_member
    current_user_is :pbe_mentor_1
    group = groups(:group_pbe_0)

    assert group.forum_enabled?
    get :profile, params: { id: group.id}
    assert_response :success
    assert_nil assigns(:is_pending_group_show_plan_tab)
    assert_nil assigns(:is_pending_group_show_profile_tab)
    assert_no_select "ul.nav-tabs"
  end

  def test_profile_of_pending_group_not_show_forum_for_non_member
    current_user_is :pbe_mentor_1
    group = groups(:group_pbe_0)
    program = group.program
    program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")
    milestone_template = group.mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")
    assert group.forum_enabled?

    get :profile, params: { id: group.id}
    assert_response :success
    assert assigns(:is_pending_group_show_profile_tab)
    assert assigns(:is_group_profile_view)
    assert_select "ul.nav-tabs" do
      assert_select "li", count: 2
      assert_select "li.active" do
        assert_select "span", text: "Information"
      end
      assert_select "li" do
        assert_select "span", text: "Plan"
      end
    end
  end

  def test_profile_action_for_pending_groups_for_admin
    current_user_is :f_admin_pbe
    current_program_is :pbe
    program = programs(:pbe)
    group = program.groups.pending.first
    group.update_attribute(:global, false)
    mentoring_model = group.mentoring_model
    milestone_template = mentoring_model.mentoring_model_milestone_templates.create!(title: "title", description: "description")

    task_template = mentoring_model.mentoring_model_task_templates.create!({
      milestone_template_id: milestone_template.id,
      required: true,
      title: "title",
      description: "description",
      duration: 10,
      action_item_type: MentoringModel::TaskTemplate::ActionItem::DEFAULT,
      role_id: program.roles.first.id
    })

    program.connection_questions.create!(question_type: CommonQuestion::Type::STRING, question_text: "Skyler or Claire ?")

    get :profile, params: { id: group.id}

    assert_response :success
    assert_equal assigns(:mentoring_model_milestones), [milestone_template]
    assert_equal assigns(:mentoring_model_tasks), [task_template]
    assert assigns(:is_pending_group_show_profile_tab)
    assert assigns(:is_group_profile_view)
    assert_select "ul.nav-tabs" do
      assert_select "li", count: 3
      assert_select "li.active" do
        assert_select "span", text: "Information"
      end
      assert_select "li" do
        assert_select "span", text: "Discussion Board"
      end
      assert_select "li" do
        assert_select "span", text: "Plan"
      end
    end
    assert_select "a", count: 0, text: "Start a Conversation"
  end

  def test_fetch_custom_task_status_filter_failure
    current_user_is :f_student
    assert_permission_denied  do
      get :fetch_custom_task_status_filter, xhr: true
    end
  end

  def test_fetch_custom_task_status_filter_success
    current_user_is :f_admin
    mm = create_mentoring_model
    get :fetch_custom_task_status_filter, xhr: true
    assert_response :success
    assert_equal programs(:albers).mentoring_models, assigns(:templates)
    assert_equal programs(:albers).default_mentoring_model, assigns(:selected_template)

    get :fetch_custom_task_status_filter, xhr: true, params: { template: "#{mm.id}"}
    assert_response :success
    assert_equal programs(:albers).mentoring_models, assigns(:templates)
    assert_equal mm, assigns(:selected_template)
  end

  def test_reset_task_options_for_custom_task_status_filter_failure
    current_user_is :f_student
    assert_permission_denied  do
      get :reset_task_options_for_custom_task_status_filter, xhr: true
    end
  end

  def test_reset_task_options_for_custom_task_status_filter_success
    current_user_is :f_admin
    mm = create_mentoring_model
    get :reset_task_options_for_custom_task_status_filter, xhr: true
    assert_response :success
    assert_equal programs(:albers).default_mentoring_model, assigns(:selected_template)

    get :reset_task_options_for_custom_task_status_filter, xhr: true, params: { template: "#{mm.id}"}
    assert_response :success
    assert_equal mm, assigns(:selected_template)
  end

  def test_redirect_to_groups_listing_career_based_new_html_erb
    # For career based mentoring programs, GroupsController#new is a JS request. Hence, when the user sends a HTML request, redirecting to GroupsController#index.
    current_user_is :f_admin
    get :new
    assert_redirected_to groups_path(show_new: true, tab: Group::Status::ACTIVE)
  end

  def test_redirect_to_group_scrap
    current_user_is :f_mentor
    Program.any_instance.stubs(:mentoring_connections_v2_enabled?).returns(false)
    get :show, params: { :id => groups(:mygroup).id, src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST, show_plan: false}
    assert_redirected_to group_scraps_path(groups(:mygroup), src: EngagementIndex::Activity::ACCEPT_MENTOR_REQUEST)
  end

  def test_get_users_of_role_group_member
    group = groups(:mygroup)
    mentor_role = group.program.find_role(RoleConstants::MENTOR_NAME)
    assert group.scraps_enabled?

    current_user_is group.mentors.first
    get :get_users_of_role, xhr: true, params: { id: group, role_id: mentor_role.id}
    assert assigns(:show_skype)
    assert_false assigns(:allow_individual_messaging)
    assert_equal group.mentors, assigns(:members_in_role)
    assert_equal mentor_role.id, assigns(:role_id)
  end

  def test_get_users_of_role_admin
    group = groups(:mygroup)
    student_role = group.program.find_role(RoleConstants::STUDENT_NAME)
    Group.any_instance.stubs(:scraps_enabled?).returns(false)

    current_user_is :f_admin
    get :get_users_of_role, xhr: true, params: { id: group, role_id: student_role.id}
    assert assigns(:show_skype)
    assert_false assigns(:allow_individual_messaging)
    assert_equal group.students, assigns(:members_in_role)
    assert_equal student_role.id, assigns(:role_id)
  end

  def test_get_users_of_role_skype_disabled_individual_messaging_enabled
    group = groups(:mygroup)
    student_role = group.program.find_role(RoleConstants::STUDENT_NAME)
    Group.any_instance.stubs(:scraps_enabled?).returns(false)
    Organization.any_instance.stubs(:skype_enabled?).returns(false)

    current_user_is group.mentors.first
    get :get_users_of_role, xhr: true, params: { id: group, role_id: student_role.id}
    assert_false assigns(:show_skype)
    assert assigns(:allow_individual_messaging)
    assert_equal group.students, assigns(:members_in_role)
    assert_equal student_role.id, assigns(:role_id)
  end

  def test_bulk_set_expiry_date_skip_validation
    current_user_is :f_admin
    group = groups(:mygroup)
    # For Perf, skipping check_only_one_group_for_a_student_mentor_pair validation. Ideally this validation is not needed for bulk set expiry date, only on going connections bulk expiry date can be performed.
    group.students << groups(:group_3).students
    group.mentors << groups(:group_3).mentors
    new_expiry_date = group.expiry_time + 4.months
    member_size = groups(:mygroup).members.size + groups(:group_2).members.size
    assert_difference 'PendingNotification.count', member_size do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:action_type => Group::BulkAction::SET_EXPIRY_DATE, :group_ids => [groups(:mygroup).id, groups(:group_2).id].join(" "), :mentoring_period => new_expiry_date, :reason => "Testing Expiry date"}}
    end
    assert_response :success
    assert_equal "#{Group::BulkAction::SET_EXPIRY_DATE}", assigns(:action_type)
    assert_equal_unordered ["#{groups(:mygroup).id}", "#{groups(:group_2).id}"], assigns(:group_ids)
    assert_equal_unordered [groups(:mygroup), groups(:group_2)], assigns(:groups)
    assert_equal [], assigns(:error_flash)
    assert_equal [], assigns(:error_groups)
    assert_equal new_expiry_date, groups(:mygroup).reload.expiry_time
    assert_equal new_expiry_date, groups(:group_2).reload.expiry_time
  end

  def test_update_bulk_actions_reactivate_should_fail_for_validation
    group = groups(:mygroup)
    group.terminate!(users(:f_admin),"Test reason", group.program.permitted_closure_reasons.first.id)
    groups(:group_2).terminate!(users(:f_admin),"Test reason", groups(:group_2).program.permitted_closure_reasons.first.id)
    group.students << groups(:group_3).students
    group.mentors << groups(:group_3).mentors
    new_expiry_date = group.expiry_time + 4.months

    current_user_is :f_admin
    post :update_bulk_actions, xhr: true, params: { bulk_actions: { action_type: Group::BulkAction::REACTIVATE, group_ids: [groups(:mygroup).id, groups(:group_2).id].join(" "), mentoring_period: new_expiry_date, reason: "Testing Expiry date" }}
    assert_equal ["Non requestable mentor preferred not to have more than 2 students and Non requestable mentor is already a mentor to student_d example"], assigns(:error_flash)
  end

  def test_edit_join_settings_permission_denied
    current_user_is :f_mentor
    assert_permission_denied  do
      get :edit_join_settings, params: { :id => groups(:group_inactive).id}
    end

    current_user_is :f_admin
    assert_permission_denied  do
      get :edit_join_settings, params: { :id => groups(:drafted_group_1).id}
    end

    group = groups(:group_pbe)
    group.program.stubs(:allows_users_to_apply_to_join_in_project).returns(false)
    assert_permission_denied  do
      get :edit_join_settings, params: { :id => groups(:drafted_group_1).id}
    end
  end

  def test_edit_join_settings_admin_owner
    student_user = users(:pbe_student_0)
    current_user_is student_user
    group = groups(:group_pbe_0)
    group.membership_of(student_user).update_attributes(owner: true)
    group.update_column(:status, Group::Status::ACTIVE)

    assert student_user.can_manage_or_own_group?(group)
    assert_false student_user.can_manage_connections?

    get :edit_join_settings, params: { :id => group.id}
    assert_template partial: "_edit_join_settings"
    assert_equal group, assigns(:group)
  end

  def test_edit_join_settings_admin
    current_user_is :f_admin_pbe
    group = groups(:group_pbe_0)
    group.update_column(:status, Group::Status::ACTIVE)

    get :edit_join_settings, params: { :id => group.id}
    assert_template partial: "_edit_join_settings"
    assert_equal group, assigns(:group)
  end

  def test_update_join_settings_deny_join
    pbe_group_setup
    current_user_is :f_admin_pbe

    teacher_role_id = @program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    student_role_id = @program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    @group.update_column(:status, Group::Status::ACTIVE)
    params = {
      id: @group.id,
      group: {
        role_permission: {
          teacher_role_id.to_s => "false",
          student_role_id.to_s => "false"
        }
      }
    }

    patch :update_join_settings, xhr: true, params: params
    group_setting = @group.setting_for_role_id(teacher_role_id)
    assert_nil group_setting
    group_setting = @group.setting_for_role_id(student_role_id)
    assert_false group_setting.allow_join
  end

  def test_update_join_settings_allow_join
    pbe_group_setup
    current_user_is :f_admin_pbe

    teacher_role = @program.roles.find_by(name: RoleConstants::TEACHER_NAME)
    student_role = @program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    @group.update_column(:status, Group::Status::ACTIVE)
    teacher_role.add_permission(RolePermission::SEND_PROJECT_REQUEST)
    params = {
      id: @group.id,
      group: {
        role_permission: {
          teacher_role.id.to_s => "false",
          student_role.id.to_s => "true"
        }
      }
    }

    patch :update_join_settings, xhr: true, params: params
    assert_false @group.setting_for_role_id(teacher_role.id).allow_join
    assert_nil @group.setting_for_role_id(student_role.id)
  end

  def test_clone_success
    current_user_is :f_admin
    current_program_is :albers
    source_group = groups(:group_4)
    source_group.update_attributes!(notes: "Test Notes", status: Group::Status::CLOSED)
    get :clone, xhr: true, params: { id: source_group.id}
    cloned_group = assigns(:group)
    assert assigns(:is_clone)
    assert_equal source_group.name, cloned_group.name
    assert_equal source_group.memberships.collect{|a| a.user.member.name(name_only: true)}, cloned_group.memberships.collect{|a| a.user.member.name(name_only: true)}
  end

  def test_clone_redirected
    current_user_is :f_admin
    current_program_is :albers
    source_group = groups(:group_4)
    source_group.update_attributes!(status: Group::Status::CLOSED)
    get :clone, params: { id: source_group.id }
    assert_redirected_to groups_path(show_clone: true, clone_group_id: source_group.id, tab: Group::Status::ACTIVE)
  end

  def test_clone_failure_for_project_based
    current_user_is :f_admin_pbe
    current_program_is :pbe
    source_group = groups(:group_pbe_0)
    assert_permission_denied do
      get :clone, xhr: true, params: { id: source_group.id}
    end
    assert_false assigns(:group)
    assert_false assigns(:is_clone)
  end

  def test_clone_failure_for_active_group
    current_user_is :f_admin
    current_program_is :albers
    source_group = groups(:mygroup)
    assert_permission_denied do
      get :clone, xhr: true, params: { id: source_group.id}
    end
    assert_false assigns(:group)
    assert_false assigns(:is_clone)
  end

  def test_clone_failure_for_non_admin
    current_user_is :f_mentor
    current_program_is :albers
    source_group = groups(:group_4)
    assert_permission_denied do
      get :clone, xhr: true, params: { id: source_group.id}
    end
    assert_false assigns(:group)
    assert_false assigns(:is_clone)
  end

  private

  def _mentoring_connections
    "mentoring connections"
  end

  def _mentoring_connection
    "mentoring connection"
  end

  def setup_engagement_survey_answers_for_text_based
    prog = programs(:albers)
    mentoring_model = prog.default_mentoring_model
    @group = groups(:mygroup)
    mentoring_model.update_attribute(:should_sync, true)
    @group.update_attribute(:mentoring_model_id, mentoring_model.id)
    tem_task1 = create_mentoring_model_engagement_survey_task_template
    membership = @group.mentor_memberships.first
    task = @group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, connection_membership_id: membership.id).first
    task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
      ans = task.survey_answers.new(:user_id => membership.user_id, :answer_text => "i am not good", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
  end

  def setup_engagement_survey_answers_for_choice_based
    prog = programs(:albers)
    mentoring_model = prog.default_mentoring_model
    @group = groups(:mygroup)
    mentoring_model.update_attribute(:should_sync, true)
    @group.update_attribute(:mentoring_model_id, mentoring_model.id)
    @survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    @question = create_survey_question({allow_other_option: true, :question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => "get,set,go", :survey => @survey})
    tem_task1 = create_mentoring_model_engagement_survey_task_template(action_item_id: @survey.id)
    membership = @group.mentor_memberships.first
    answers = []
    task = @group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, connection_membership_id: membership.id).first
    ans = task.survey_answers.new(:user_id => membership.user_id, :answer_value => {answer_text: ["set", "run"], question: @question}, :last_answered_at => Time.now.utc)
    ans.survey_question = @question
    ans.save!
  end

  def setup_for_update_view_mode_filter
    current_user_is users(:f_mentor)
    @user = users(:f_mentor)
    @group = groups(:mygroup)
    @program = @group.program
    @group.allow_manage_mm_tasks!(@program.roles.for_mentoring_models)
  end

  def assert_feedback_link_present
    assert_select 'a#contact_admin', "Contact Administrator"
  end

  def assert_no_feedback_link_present
    assert_no_select 'div#send_feedback'
  end

  def create_skype_answer(role, text, user)
    ProfileAnswer.create!(:profile_question_id => programs(:org_primary).profile_questions.skype_question.first.id,
      :ref_obj => user.member, :answer_text => text)
  end

  def group_setup
    @user = users(:f_student)
    @mentor = users(:f_mentor)
    @program = programs(:albers)
    @group = create_group(:students => [@user], :mentor => @mentor, :program => @program)
  end

  def pbe_group_setup
    @user = users(:pbe_student_0)
    @mentor = users(:f_mentor_pbe)
    @program = programs(:pbe)
    @group = create_group(:students => [@user], :mentor => @mentor, :program => @program)
  end

  def pbe_slot_config_test_setup
    @slot_config_test__program = programs(:pbe)
    @slot_config_test__student_role = @slot_config_test__program.get_role(RoleConstants::STUDENT_NAME)
    @slot_config_test__group = groups(:group_pbe)
  end

  def create_engagement_survey_and_its_answers
    @mentoring_model = @program.default_mentoring_model
    @mentoring_model.update_attributes(:should_sync => true)
    @group.update_attribute(:mentoring_model_id, @mentoring_model.id)
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    create_matrix_survey_question({survey: survey})
    tem_task = create_mentoring_model_task_template
    tem_task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => @program.roles.with_name([RoleConstants::MENTOR_NAME]).first })
    MentoringModel.trigger_sync(@mentoring_model.id, I18n.locale)

    @response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    @user = @group.mentors.first
    @task = @group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first
    @task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
      ans = @task.survey_answers.new(:user => @user, :response_id => @response_id, :answer_text => "lorem ipsum", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
    @task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
      ans = @task.survey_answers.new(:user => @user, :response_id => @response_id, :answer_text => "Good", :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
  end

  ## TODO: The fixture itself should be fixed.
  ## Currently the fixture values - is_admin_only are populated to be nil
  def initialize_connection_questions(program)
    program.connection_questions.each do |connection_question|
      connection_question.update_attributes!(is_admin_only: false)
    end
  end

  def get_mentoring_role_id_name_map(program)
    program.roles.for_mentoring.inject({}) { |h, role| h[role.name] = role.id; h }
  end
end