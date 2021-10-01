require_relative './../test_helper.rb'

class AdminViewsControllerTest < ActionController::TestCase

  def test_restricted_actions_for_track_level_only_admin
    restricted_actions_for_track_level_admin = [:new, :toggle_favourite, :on_remove_user_completion, :suspend_membership, :destroy, :reactivate_membership, :suspend_member_membership, :add_or_remove_tags, :reactivate_member_membership, :fetch_admin_view_details, :bulk_add_users_to_project, :remove_member, :update, :remove_user, :locations_autocomplete, :preview_view_details, :edit, :resend_signup_instructions, :auto_complete_for_name, :add_role, :create, :fetch_survey_questions]
    assert_equal restricted_actions_for_track_level_admin.sort, (AdminViewsController.instance_methods(false) - AdminViewsController::MULTI_TRACK_ADMIN_ACCESSIBLE_ACTIONS).sort, "Check whether the added or removed action needs to be handled for track level only admin"
  end

  def test_only_admin_can_access_the_page
    current_user_is :f_mentor

    assert_permission_denied do
      get :show, params: { :id => programs(:albers).admin_views.first}
    end
  end

  def test_track_level_admin_can_access_only_active_license_view
    member = members(:ram)
    current_member_is member
    AdminViewsController.any_instance.stubs(:program_view?).returns(false)
    AdminViewsController.any_instance.stubs(:wob_member).returns(member)
    assert_permission_denied do
      get :show, params: {default_view: AbstractView::DefaultType::ALL_MEMBERS, id: ""}
    end
    get :show, params: {default_view: AbstractView::DefaultType::LICENSE_COUNT, id: ""}
    assert_response :success
    assert assigns(:dynamic_filter_params).require(:multi_track_admin)

    member = members(:f_admin)
    current_member_is member
    AdminViewsController.any_instance.stubs(:wob_member).returns(member)
    get :show, params: {default_view: AbstractView::DefaultType::LICENSE_COUNT, id: ""}
    assert_response :success
    assert_nil assigns(:dynamic_filter_params)
  end

  def test_is_active_license_view
    organization = programs(:org_primary)
    assert AdminViewsController.new.send(:is_active_license_view?, organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT))
    assert_false AdminViewsController.new.send(:is_active_license_view?, organization.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_MEMBERS))
  end

  def test_check_is_admin_or_multi_track_admin
    member = members(:f_admin)
    current_member_is member
    AdminViewsController.any_instance.stubs(:wob_member).returns(member)
    AdminViewsController.any_instance.stubs(:check_is_admin?).returns(true)
    assert AdminViewsController.new.send(:check_is_admin_or_multi_track_admin?)

    member = members(:ram)
    current_member_is member
    AdminViewsController.any_instance.stubs(:wob_member).returns(member)
    AdminViewsController.any_instance.stubs(:check_is_admin?).returns(false)
    AdminViewsController.any_instance.stubs(:track_level_admin_allowed_views?).returns(false)
    assert_false AdminViewsController.new.send(:check_is_admin_or_multi_track_admin?)
    AdminViewsController.any_instance.stubs(:track_level_admin_allowed_views?).returns(true)
    assert AdminViewsController.new.send(:check_is_admin_or_multi_track_admin?)
  end

  def test_show_for_bulk_match
    current_user_is :f_admin

    get :show, params: { :id => programs(:albers).admin_views.first, source_info: {controller: "bulk_matches"}, :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)

    assert assigns(:admin_view).present?
    assert assigns(:source_info)
  end

  def test_show_for_match_report
    current_user_is :f_admin

    get :show, params: { :id => programs(:albers).admin_views.first, source_info: {controller: "match_reports", section: "1"}}
    assert_response :success

    assert assigns(:admin_view).present?
    assert assigns(:source_info)
  end

  def test_show_no_src
    current_user_is :f_admin
    get :show, params: { :id => programs(:albers).admin_views.first, source_info: {controller: "bulk_matches"}}
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_feature_organization_profiles_enabled_for_org_admin_view
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES, false)
    current_member_is :f_admin
    assert_permission_denied do
      get :show, params: { :id => programs(:org_primary).admin_views.first}
    end
  end

  def test_should_render_show_page_for_admins
    current_user_is :f_admin

    get :show, params: { :id => programs(:albers).admin_views.first}
    assert_response :success

    assert assigns(:objects).present?
    assert assigns(:all_admin_views).present?
    assert_false assigns(:used_as_filter)
    assert_equal User.name, assigns(:objects).first.class.name
    assert_equal AdminViewsController::DEFAULT_PER_PAGE, assigns(:objects).size
    assert_equal [], assigns(:profile_answers_hash).keys
    assert_equal [], assigns(:profile_answers_hash)[members(:f_mentor).id].keys
  end

  def test_should_render_show_page_for_default_view
    current_user_is :f_admin

    get :show, params: { :default_view => AbstractView::DefaultType::ALL_USERS, id: ""}
    assert_response :success
    assert_false assigns(:used_as_filter)

    assert_select "div#title_box" do
      assert_select "h1.dropdown-toggle", :text => "All Users"
    end
    assert_nil assigns(:member_program_and_roles)
  end

  def test_should_render_show_page_for_organization_default_view
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)

    get :show, params: { :default_view => AbstractView::DefaultType::ALL_MEMBERS, id: ""}
    assert_response :success
    assert_false assigns(:used_as_filter)

    assert_select "div#title_box" do
      assert_select "h1", :text => "All Members"
    end
    assert_equal Member.name, assigns(:objects).first.class.name
    assert_equal AdminViewsController::DEFAULT_PER_PAGE, assigns(:objects).size
    assert_equal [], assigns(:profile_answers_hash).keys
    assert_equal [], assigns(:profile_answers_hash)[members(:f_mentor).id].keys
    assert assigns(:member_program_and_roles).any?
  end

  def test_dynamic_filter_params
    current_user_is :f_admin

    get :show, params: { :default_view => AbstractView::DefaultType::ALL_USERS, dynamic_filters: {state: User::Status::ACTIVE, connected: true}}
    assert_equal_hash({state: User::Status::ACTIVE, connected: "true"}, assigns(:dynamic_filter_params))
    assert_response :success
    assert_nil flash[:error]
  end

  def test_dynamic_filter_params_missing_columns
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS)
    admin_view.admin_view_columns.find_by(column_key: AdminViewColumn::Columns::Key::GROUPS).destroy

    get :show, params: { :default_view => AbstractView::DefaultType::ALL_USERS, dynamic_filters: {state: User::Status::ACTIVE}}
    assert_equal_hash({state: User::Status::ACTIVE}, assigns(:dynamic_filter_params))
    assert_response :success
    assert_nil flash[:error]

    get :show, params: { :default_view => AbstractView::DefaultType::ALL_USERS, dynamic_filters: {state: User::Status::ACTIVE, connected: true}}
    assert_equal_hash({}, assigns(:dynamic_filter_params))
    assert_response :success
    assert_equal "Ongoing Mentoring Connections column is not selected for display. <a href=\"/p/albers/admin_views/#{admin_view.id}/edit\">Click here</a> to add it to the view to see the filtered results", flash[:error]

    admin_view.admin_view_columns.find_by(column_key: AdminViewColumn::Columns::Key::STATE).destroy
    get :show, params: { :default_view => AbstractView::DefaultType::ALL_USERS, dynamic_filters: {state: User::Status::ACTIVE, connected: true}}
    assert_equal_hash({}, assigns(:dynamic_filter_params))
    assert_response :success
    assert_equal "Status and Ongoing Mentoring Connections columns are not selected for display. <a href=\"/p/albers/admin_views/#{admin_view.id}/edit\">Click here</a> to add them to the view to see the filtered results", flash[:error]
  end

  def test_bulk_confirmation_view_scoped_programs_for_track_level_only_admin
    member = members(:ram)
    programs(:nwen).admin_users[0].update_attribute(:member_id, member.id)
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    organization = member.organization
    active_license_admin_view = organization.admin_views.find_by(default_view: AbstractView::DefaultType::LICENSE_COUNT)
    current_member_is :ram
    post :bulk_confirmation_view, xhr: true, params: { id: active_license_admin_view.id, bulk_action_confirmation: {users: "2", type: AdminViewsHelper::BulkActionType::INVITE_TO_PROGRAM, title: "Invite to Program"}}
    assert_equal_unordered member.users.map(&:program), assigns(:tracks)
  end

  def test_render_bulk_confirmation_view_for_xhr_show
    current_user_is :f_admin

    post :bulk_confirmation_view, xhr: true, params: { :id => programs(:albers).admin_views.first, :bulk_action_confirmation => {:users => "1,2", :type => AdminViewsHelper::BulkActionType::REMOVE_USER, :title => "Remove user"}}
    assert_response :success

    assert_equal "Remove user", assigns(:bulk_action_title)
    assert_equal 3, assigns(:bulk_action_type)
    assert assigns(:users).present?
  end

  def test_render_bulk_confirmation_view_for_xhr_show_at_organization_level
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)

    post :bulk_confirmation_view, xhr: true, params: { :id => programs(:org_primary).admin_views.first, :bulk_action_confirmation => {:users => "2", :type => AdminViewsHelper::BulkActionType::INVITE_TO_PROGRAM, :title => "Invite to Program"}}
    assert_response :success

    assert_equal "Invite to Program", assigns(:bulk_action_title)
    assert_equal 6, assigns(:bulk_action_type)
    assert assigns(:members).present?
  end

  def test_export_csv
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first

    ChronusS3Utils::S3Helper.stubs(:transfer).returns(["admin_views.csv", "/some/path"])

    get :export_csv, params: { format: 'csv', admin_view: {users: "1,2,3"}, id: admin_view.id}
    assert_response :success

    assert assigns(:user_ids).present?
    assert_equal 3, assigns(:user_ids).size
    assert_equal %w[1 2 3], assigns(:user_ids)
  end

  def test_no_users_selected_for_bulk_action
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first

    post :add_role, params: { :admin_view => {:users => "",:role_names => ["student"]}, :id => admin_view.id}
    assert_equal "Please select at least one User", flash[:error]
  end

  def test_add_role_for_users_success
    current_user_is :f_admin
    assert_equal_unordered ["student"], users(:f_student).roles.collect(&:name)
    assert_equal_unordered ["mentor"], users(:f_mentor).roles.collect(&:name)
    assert_equal_unordered ["admin"], users(:f_admin).roles.collect(&:name)

    assert_emails do
      post :add_role, params: { :admin_view => {:users => "1,2,3",:role_names => ["student"]}, :id => programs(:albers).admin_views.first}
    end

    assert_equal_unordered ["student"], users(:f_student).reload.roles.collect(&:name)
    assert_equal_unordered ["mentor", "student"], users(:f_mentor).reload.roles.collect(&:name)
    assert_equal_unordered ["admin", "student"], users(:f_admin).reload.roles.collect(&:name)
  end

  def test_add_user_role_for_users_success
    current_user_is :f_admin

    assert_equal_unordered ["student"], users(:f_student).roles.collect(&:name)
    assert_equal_unordered ["mentor"], users(:f_mentor).roles.collect(&:name)
    assert_equal_unordered ["admin"], users(:f_admin).roles.collect(&:name)
    assert_equal_unordered ["user"], users(:f_user).roles.collect(&:name)

    assert_emails 2 do
      post :add_role, params: { :admin_view => {:users => "1,2,3,4",:role_names => ["user"]}, :id => programs(:albers).admin_views.first}
    end

    assert_equal_unordered ["user"], users(:f_user).reload.roles.collect(&:name)
    assert_equal_unordered ["student", "user"], users(:f_student).reload.roles.collect(&:name)
    assert_equal_unordered ["mentor", "user"], users(:f_mentor).reload.roles.collect(&:name)
    assert_equal_unordered ["admin", "user"], users(:f_admin).reload.roles.collect(&:name)
  end

  def test_add_admin_role_for_users_success
    current_user_is :f_admin
    assert_equal_unordered ["mentor"], users(:f_mentor).roles.collect(&:name)
    assert_emails 1 do
      assert_difference 'UserStateChange.count', 1 do
        assert_difference 'ConnectionMembershipStateChange.count', 1 do
          post :add_role, params: { :admin_view => {:users => "3",:role_names => ["admin"]}, :id => programs(:albers).admin_views.first}
        end
      end
    end
    assert_equal_unordered ["mentor", "admin"], users(:f_mentor).reload.roles.collect(&:name)
  end

  def test_render_bulk_confirmation_view_for_add_role
    current_user_is :f_admin

    post :bulk_confirmation_view, xhr: true, params: { :id => programs(:albers).admin_views.first, :bulk_action_confirmation => {:users => "2", :type => AdminViewsHelper::BulkActionType::ADD_ROLE, :title => "Add Role"}}
    assert_response :success

    assert_equal "Add Role", assigns(:bulk_action_title)
    assert_equal 4, assigns(:bulk_action_type)
    assert assigns(:users).present?
    programs(:albers).roles.each do |role|
      assert_match role.name, @response.body
    end
  end

  def test_add_or_remove_tag_feature_disabled
    current_user_is :f_admin

    assert_permission_denied do
      post :add_or_remove_tags, params: { admin_view: {users: users(:mentor_0).id, tag_list: "a,b,c"}, id: programs(:albers).admin_views.first }
    end

    assert_permission_denied do
      post :add_or_remove_tags, params: { admin_view: {users: users(:mentor_0).id, tag_list: "a,b,c"}, id: programs(:albers).admin_views.first, remove_tags: true}
    end
  end

  def test_add_or_remove_tags_to_users
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)
    current_user_is :f_admin

    assert_difference "users(:mentor_0).tags.count", 3 do
      post :add_or_remove_tags, params: { admin_view: {users: users(:mentor_0).id, tag_list: "a,b,c"}, id: programs(:albers).admin_views.first }
    end

    assert_difference "users(:mentor_0).tags.count", -2 do
      post :add_or_remove_tags, params: { admin_view: {users: users(:mentor_0).id, tag_list: "a,c,d"}, id: programs(:albers).admin_views.first, remove_tags: true }
    end
  end

  def test_tags_created_in_addition_to_existing_tags
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)

    user = users(:mentor_0)
    user.tag_list = "a,b,c"
    user.save!

    assert_difference "users(:mentor_0).tags.count", 1 do
      post :add_or_remove_tags, params: { :admin_view => {:users => users(:mentor_0).id, :tag_list => "a,b,d"}, :id => programs(:albers).admin_views.first }
    end
  end

  def test_tags_removed_from_existing_tags
    current_user_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)

    user = users(:mentor_0)
    user.tag_list = "a,b,c"
    user.save!

    assert_difference "users(:mentor_0).tags.count", -2 do
      post :add_or_remove_tags, params: { :admin_view => {:users => users(:mentor_0).id, :tag_list => "a,b,d"}, :id => programs(:albers).admin_views.first, remove_tags: true }
    end
    assert_equal ["c"], user.reload.tag_list
  end

  def test_remove_user_for_admin
    current_user_is :f_admin

    assert_difference "User.count", -1 do
      post :remove_user, xhr: true, params: { :admin_view => {:users => "1,2"}, :id => programs(:albers).admin_views.first}
    end
  end

  def test_bulk_remove_users_limit_exceeded
    current_user_is :f_admin
    program = programs(:albers)

    assert_difference "User.count", 0 do
      post :remove_user, xhr: true, params: { :admin_view => {:users => program.users.pluck(:id).join(",")}, :id => program.admin_views.first}
    end
    assert_equal "Please select 25 or fewer users to delete at one time.", flash[:error]
    assert_redirected_to admin_view_path(assigns(:admin_view))
  end

  def test_remove_user
    current_user_is :f_admin
    assert_difference "User.count", -2 do
      post :remove_user, xhr: true, params: { admin_view: { users: "#{users(:f_mentor).id},#{users(:f_student).id}" }, id: programs(:albers).admin_views.first}
    end
  end

  def test_remove_user_with_ignored_users
    user = users(:f_mentor)
    admin_view = programs(:albers).admin_views.first

    User.expects(:removal_or_suspension_scope).once.returns([])
    current_user_is :ram
    assert_no_difference "User.count" do
      post :remove_user, xhr: true, params: { admin_view: { users: user.id.to_s }, id: admin_view.id}
    end

    get :on_remove_user_completion, params: { invalid_user_ids: assigns(:user_ids_ignored_for_removal_or_suspension), id: admin_view.id}
    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_equal "#{user.name(name_only: true)} has not been removed", flash[:error]
  end

  def test_remove_user_progress_status
    admin = users(:f_admin)

    current_user_is admin
    assert_difference "User.count", -2 do
      assert_difference "ProgressStatus.count", 1 do
        post :remove_user, xhr: true, params: { admin_view: { users: "#{users(:f_mentor).id},#{users(:f_student).id}" }, id: programs(:albers).admin_views.first}
      end
    end
    progress = ProgressStatus.last
    assert_equal 2, progress.maximum
    assert_equal admin, progress.ref_obj
  end

  def test_suspend_membership
    admin = users(:f_admin)
    user_1 = users(:f_mentor)
    user_2 = users(:f_student)
    admin_view = admin.program.admin_views.first
    User.any_instance.expects(:close_pending_received_requests_and_offers).once

    User.expects(:removal_or_suspension_scope).once.returns(User.where(id: user_1.id))
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user_1.id]).times(3)
    current_user_is :f_admin
    current_time =Time.now

    Timecop.freeze(current_time) do
      assert_difference "UserStateChange.count", 1 do
        assert_difference "ConnectionMembershipStateChange.count", 1 do
          assert_emails 1 do
            post :suspend_membership, params: { admin_view: { users: "#{admin.id},#{user_1.id},#{user_2.id}" }, id: admin_view}
          end
        end
      end
    end
    assert_redirected_to admin_view_path(admin_view)
    assert_equal "The selected users membership have been deactivated from the program.", flash[:notice]
    assert_equal [admin.id, user_2.id], assigns(:user_ids_ignored_for_removal_or_suspension)
    assert_equal [user_1], assigns(:users_for_removal_or_suspension)
    assert_false admin.reload.suspended?
    assert user_1.reload.suspended?
    assert_false user_2.reload.suspended?
    assert_equal current_time.to_i, user_1.last_deactivated_at.to_i
    assert_nil admin.last_deactivated_at
    assert_nil user_2.last_deactivated_at
  end

  def test_reactivate_membership
    current_user_is :f_admin
    user = users(:f_mentor)
    suspend_user(user)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [user.id]).times(3)
    post :reactivate_membership, params: { :admin_view => {:users => "#{users(:f_mentor).id}"}, :id => programs(:albers).admin_views.first}

    assert :success
    assert user.reload.active?
    assert_equal "The selected users membership have been reactivated in the program", flash[:notice]
  end

  def test_invite_users
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    assert members(:f_student).user_in_program(programs(:albers))
    assert_false members(:f_student).user_in_program(programs(:moderated_program))
    assert_emails 1 do
      assert_difference "ProgramInvitation.count" do
        post :invite_to_program, params: { :admin_view => {:members => "#{members(:f_student).id}", :program_id => programs(:moderated_program).id.to_s, :message => 'Welcome to the program' }, :id => programs(:org_primary).admin_views.first, :role => "assign_roles", :assign_roles => ["mentor"]}
      end
    end
    invitation = ProgramInvitation.last
    assert_equal "en", invitation.locale
    assert_equal [RoleConstants::MENTOR_NAME], invitation.role_names
    assert_equal ProgramInvitation::RoleType::ASSIGN_ROLE, invitation.role_type

    assert_no_emails do
      assert_no_difference "ProgramInvitation.count" do
        post :invite_to_program, params: { :admin_view => {:members => "#{members(:f_student).id}", :program_id => programs(:albers).id.to_s, :message => 'Welcome to the program' }, :id => programs(:org_primary).admin_views.first, :role => "assign_roles", :assign_roles => ["student"]}
      end
    end
  end

  def test_invite_users_with_multiple_role_selected
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    assert members(:f_student).user_in_program(programs(:albers))
    assert_emails 1 do
      assert_difference "ProgramInvitation.count" do
        post :invite_to_program, params: { :admin_view => {:members => "#{members(:f_student).id}", :program_id => programs(:moderated_program).id.to_s, :message => 'Welcome to the program' }, :id => programs(:org_primary).admin_views.first, :role => "assign_roles", :assign_roles => ["mentor", "student"]}
      end
    end
    invitation = ProgramInvitation.last
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], invitation.role_names
    assert_equal ProgramInvitation::RoleType::ASSIGN_ROLE, invitation.role_type
    assert_equal "Invitations will be sent to all the selected member(s). <a href=\"/p/modprog/program_invitations\">Click here</a> to visit 'Invitations Sent' listing page which will get updated shortly with the list of sent invitation(s) with it's status. Please note that we won&#39;t be able to send emails to the email addresses that are either invalid or who may correspond to existing users", flash[:notice]
  end

  def test_invite_users_with_allowing_user_to_select_role
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    assert members(:f_student).user_in_program(programs(:albers))
    assert_emails 1 do
      assert_difference "ProgramInvitation.count" do
        post :invite_to_program, params: { :admin_view => {:members => "#{members(:f_student).id}", :program_id => programs(:moderated_program).id.to_s, :message => 'Welcome to the program' }, :id => programs(:org_primary).admin_views.first, :role => "allow_roles", :allow_roles => ["mentor", "student"]}
      end
    end
    invitation = ProgramInvitation.last
    assert_equal_unordered [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], invitation.role_names
    assert_equal ProgramInvitation::RoleType::ALLOW_ROLE, invitation.role_type
  end

  def test_create
    current_user_is :f_admin
    profile_filter = {"questions"=>{"questions_1"=>{"question"=>"6", "operator"=> AdminViewsHelper::QuestionType::IN.to_s, "value"=>"abcd  defg,hig,sdijb"}}}
    section_params = {:title => "Sample Title", :description => "Sample Description", :roles_and_status => "sample", :others => "awesome", :connection_status => {:new_data => ""}, :profile => profile_filter}

    assert_difference "AdminViewColumn.count", 2 do
      assert_difference "AdminView.count", 1 do
        post :create, params: { :admin_view => section_params.merge(:new_key => "sample_value").merge(:admin_view_columns => ["first_name", "last_name"])}
      end
    end

    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_equal 2, assigns(:admin_view).admin_view_columns.reload.size

    filter_hash = YAML.load(assigns(:admin_view).filter_params)

    assert_equal section_params.delete(:title), assigns(:admin_view).title
    assert_equal section_params.delete(:description), assigns(:admin_view).description
    assert_equal "sample", filter_hash[:roles_and_status]
    assert_equal "awesome", filter_hash[:others]
    assert_equal profile_filter, filter_hash[:profile]
    assert_equal filter_hash[:connection_status], {"new_data"=>""}
    assert_false filter_hash.has_key?(:title)
    assert_false filter_hash.has_key?(:new_key)
  end

  def test_create_organization_view
    current_member_is members(:f_admin)
    profile_filter = {"questions"=>{"questions_1"=>{"question"=>"6", "operator"=> AdminViewsHelper::QuestionType::IN.to_s, "value"=>"abcd  defg,hig,sdijb"}}}
    section_params = {:title => "Org view", :member_status => "0", :profile => profile_filter}

    assert_difference "AdminViewColumn.count", 2 do
      assert_difference "AdminView.count", 1 do
        post :create, params: { :admin_view => section_params.merge(:roles_and_status => "sample_value").merge(:admin_view_columns => ["first_name", "last_name"])}
      end
    end

    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_equal 2, assigns(:admin_view).admin_view_columns.reload.size

    filter_hash = YAML.load(assigns(:admin_view).filter_params)

    assert_equal section_params.delete(:title), assigns(:admin_view).title
    assert_equal "0", filter_hash[:member_status]
    assert_equal profile_filter, filter_hash[:profile]
    assert_false filter_hash.has_key?(:title)
    assert_false filter_hash.has_key?(:new_key)
  end

  def test_new
    current_user_is :f_admin

    membership_profile_question = profile_questions(:single_choice_q)
    membership_profile_question.role_questions.destroy_all
    create_role_question(:program => programs(:albers), :role_names => [RoleConstants::MENTOR_NAME], :profile_question => membership_profile_question, available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)

    get :new
    assert_response :success

    assert assigns(:admin_view).present?
    assert assigns(:profile_questions).present?
    assert programs(:albers).organization.skype_enabled?
    assert assigns(:profile_questions).collect(&:question_text).include?("Skype ID")
    assert assigns(:profile_questions).include?(membership_profile_question)
    assert !assigns(:used_as_filter)
  end

  def test_new_admin_view_generic_roles_profile_questions
    current_user_is :portal_admin
    string_question = profile_questions(:nch_string_q)
    single_question = profile_questions(:nch_single_choice_q)

    get :new
    assert_response :success

    assert assigns(:admin_view).present?
    assert assigns(:profile_questions).present?
    assert assigns(:profile_questions).collect(&:question_text).include?(string_question.question_text)
    assert assigns(:profile_questions).collect(&:question_text).include?(single_question.question_text)
    assert !assigns(:used_as_filter)
  end

  def test_new_organization_new
    current_member_is members(:f_admin)
    membership_profile_question = profile_questions(:single_choice_q)
    membership_profile_question.role_questions.destroy_all
    create_role_question(program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], profile_question: membership_profile_question, available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)

    get :new
    assert_response :success

    assert assigns(:admin_view).present?
    assert_equal_unordered assigns(:profile_questions), programs(:org_primary).profile_questions
    assert assigns(:profile_questions).include?(membership_profile_question)
    assert !assigns(:used_as_filter)
  end

  def test_show_meeting_request_columns_with_calendar_enabled_disabled
    user = users(:f_admin)
    program = user.program
    assert_false program.calendar_enabled?
    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1, position: 10)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1, position: 11)
    assert_equal 12, admin_view.admin_view_columns.size

    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 10, assigns(:admin_view_columns).size
  end

  def test_show_meeting_request_columns_with_calendar_enabled_enabled
    user = users(:f_admin)
    program = user.program
    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_RECEIVED_V1, position: 10)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MEETING_REQUESTS_SENT_V1, position: 11)
    assert_equal 12, admin_view.admin_view_columns.size

    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 12, assigns(:admin_view_columns).size
  end

  def test_show_mentoring_mode_column_not_present
    user = users(:f_admin)
    program = user.program
    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 10)

    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 10, assigns(:admin_view_columns).size
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_mentoring_mode_column_not_present_mentoring_mode_editable
    user = users(:f_admin)
    program = user.program
    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 10)

    program.allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    program.save!

    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 10, assigns(:admin_view_columns).size
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_mentoring_mode_column_not_present_calendar_enabled
    user = users(:f_admin)
    program = user.program
    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 10)

    Program.any_instance.stubs(:calendar_enabled?).returns(true)
    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 10, assigns(:admin_view_columns).size
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_mentoring_mode_column_not_present_org_view
    admin_view = programs(:org_primary).admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 7)
    admin_view.reload

    current_member_is members(:f_admin)
    get :show, params: { id: admin_view.id}
    assert_response :success
    assert_equal 7, assigns(:admin_view_columns).size
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_mentoring_mode_column_not_present_mentoring_v2_enabled
    user = users(:f_admin)
    program = user.program

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 9)
    admin_view.reload

    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 10, assigns(:admin_view_columns).size
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_mentoring_mode_column_present
    user = users(:f_admin)
    program = user.program

    program.enable_feature(FeatureName::CALENDAR)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program.allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    program.save!

    admin_view = programs(:albers).admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 10)
    admin_view.reload

    current_user_is user
    get :show, params: { id: admin_view.id}
    assert_equal 11, assigns(:admin_view_columns).size
    assert assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_ongoing_mentoring_dependent_columns_not_present_ongoing_disabled
    current_user_is :f_admin
    program = programs(:albers)

    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::AVAILABLE_SLOTS, position: 8)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME, position: 9)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 10)
    admin_view.reload

    get :show, params: { id: admin_view.id}
    assert_equal 7, assigns(:admin_view_columns).size
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::GROUPS)
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::AVAILABLE_SLOTS)
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME)
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_language_admin_view_column_should_not_be_present_if_disabled
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    get_tmp_language_column(admin_view).save
    programs(:albers).organization.enable_feature(FeatureName::LANGUAGE_SETTINGS, false)
    get :show, params: { id: admin_view.id}
    assert_false assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::LANGUAGE)
  end

  def test_show_ongoing_mentoring_dependent_columns_present_ongoing_enabled
    current_user_is :f_admin
    program = programs(:albers)

    program.update_attributes(engagement_type: Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    program.enable_feature(FeatureName::CALENDAR)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    program.allow_mentoring_mode_change = Program::MENTORING_MODE_CONFIG::EDITABLE
    program.save!

    admin_view = program.admin_views.first
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::AVAILABLE_SLOTS, position: 10)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME, position: 11)
    admin_view.admin_view_columns.create!(column_key: AdminViewColumn::Columns::Key::MENTORING_MODE, position: 12)
    admin_view.reload

    get :show, params: { id: admin_view.id}
    assert_equal 13, assigns(:admin_view_columns).size
    assert assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::GROUPS)
    assert assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::AVAILABLE_SLOTS)
    assert assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::LAST_CLOSED_GROUP_TIME)
    assert assigns(:admin_view_columns).pluck(:column_key).include?(AdminViewColumn::Columns::Key::MENTORING_MODE)
  end

  def test_show_with_alert_id_param
    current_user_is :f_admin
    program = programs(:albers)
    admin_view = program.admin_views.first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "description", abstract_view_id: admin_view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::AdminViewFilters::FILTERS[FilterUtils::AdminViewFilters::CONNECTION_STATUS.to_sym][:value], operator: FilterUtils::Equals::EQUALS, value: "connected"}}.to_yaml.gsub(/--- \n/, "")}
    alert = create_alert_for_metric(metric, alert_params)

    get :show, params: { :id => admin_view.id, :alert_id => alert.id}
    assert_response :success
    assert_equal program.users.joins(:connection_memberships => :group).where('groups.status IN (0, 1)').select("connection_memberships.id, connection_memberships.user_id").collect{|c| c.attributes["user_id"]}.uniq.count, assigns(:objects).count
  end

  def test_edit_organization_view_should_allow_edit_default_view
    current_member_is members(:f_admin)
    admin_view = programs(:org_primary).admin_views.first
    get :edit, params: { id: admin_view.id}
    assert_response :success
  end

  def test_edit_organization_view_not_default_view
    current_member_is members(:f_admin)
    membership_profile_question = profile_questions(:single_choice_q)
    membership_profile_question.role_questions.destroy_all
    create_role_question(program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME], profile_question: membership_profile_question, available_for: RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)

    admin_view = AdminView.create!(:title => "Sample View", :program => programs(:org_primary), :filter_params => {}.to_yaml)
    get :edit, params: { id: admin_view.id}
    assert_response :success
    assert_equal_unordered assigns(:profile_questions), programs(:org_primary).profile_questions
    assert assigns(:profile_questions).include?(membership_profile_question)
  end

  def test_update_organization_view_should_allow_update_columns_for_default_view
    current_member_is members(:f_admin)
    admin_view = programs(:org_primary).admin_views.first
    filter_params = admin_view.filter_params
    post :update, params: { :id => admin_view.id, :admin_view => {:title => "New Title", :member_status => "0"}.merge(:admin_view_columns => ["first_name", "last_name"])}
  end

  def test_update_organization_view_not_default_view
    current_member_is members(:f_admin)
    profile_filter = {"questions"=>{"questions_1"=>{"question"=>"6", "operator"=> AdminViewsHelper::QuestionType::IN.to_s, "value"=>"abcd  defg,hig,sdijb"}}}
    admin_view = AdminView.create!(:title => "Sample View", :program => programs(:org_primary), :filter_params => {:title => "Old Title", :member_status => "0", :profile => profile_filter}.to_yaml )
    filter_params = admin_view.filter_params
    post :update, params: { :id => admin_view.id, :admin_view => {:title => "New Title", :member_status => "1", :profile => profile_filter}.merge(:admin_view_columns => ["first_name", "last_name"])}
    filter_hash = YAML.load(assigns(:admin_view).filter_params)
    assert_equal 'New Title', assigns(:admin_view).title
    assert_equal "1", filter_hash[:member_status]
    assert_equal profile_filter, filter_hash[:profile]
  end

  def test_new_from_bulk_match
    current_user_is :f_admin

    get :new, params: { source_info: {controller: "bulk_matches"}}
    assert_response :success

    assert assigns(:admin_view).present?
    assert assigns(:source_info)
    assert assigns(:used_as_filter)
  end

  def test_should_be_able_to_edit_default_views
    current_user_is :f_admin
    default_admin_view = programs(:albers).admin_views.first
    assert default_admin_view.default?

    get :edit, params: { :id => default_admin_view.id}
    assert_response :success

    assert assigns(:applied_filters).present?
    assert assigns(:profile_questions).present?
  end

  def test_should_not_be_able_to_destroy_default_views
    current_user_is :f_admin
    default_admin_view = programs(:albers).admin_views.first
    assert default_admin_view.default?

    assert_permission_denied do
      post :destroy, params: { :id => default_admin_view.id}
    end
  end

  def test_should_not_be_able_to_destroy_default_views_from_organization
    current_member_is members(:f_admin)

    default_admin_view = programs(:org_primary).admin_views.first
    assert default_admin_view.default?

    assert_permission_denied do
      post :destroy, params: { :id => default_admin_view.id}
    end
  end

  def test_should_update_only_title_and_description_in_filter_params_for_default_view
    admin_view = programs(:albers).admin_views.first
    assert admin_view.default?
    assert_equal "All Users", admin_view.title
    assert_equal 10, admin_view.admin_view_columns.size

    current_user_is :f_admin
    post :update, params: { id: admin_view.reload.id, admin_view: { title: "New Title", description: "New Description",
      roles_and_status: { role_filter_1: { type: :include, roles: "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME}" },
      state: { active: "active" } } }.merge(admin_view_columns: [AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME])
    }
    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_equal 2, assigns(:admin_view).reload.admin_view_columns.reload.size
    filter_hash = YAML.load(assigns(:admin_view).filter_params)
    assert_equal "New Title", assigns(:admin_view).title
    assert_not_equal "All Users", assigns(:admin_view).title
    assert_equal "New Description", assigns(:admin_view).description
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], filter_hash[:roles_and_status][:role_filter_1][:roles]
  end

  def test_destroy
    current_user_is :f_admin
    admin_view = AdminView.create!(:title => "Sample View", :program => programs(:albers), :filter_params => {}.to_yaml)

    assert_difference "AdminView.count", -1 do
      post :destroy, params: { :id => admin_view.id}
    end
    assert_redirected_to admin_view_all_users_path
  end

  def test_destroy_organization_not_default_view
    current_member_is members(:f_admin)
    admin_view = AdminView.create!(:title => "Sample View", :program => programs(:org_primary), :filter_params => {}.to_yaml)

    assert_difference "AdminView.count", -1 do
      post :destroy, params: { :id => admin_view.id}
    end
    assert_redirected_to admin_view_all_members_path
  end

  def test_edit_admin_view
    current_user_is :f_admin
    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}".split(",")}},
      :connection_status => {:status => "", :availability => {:operator => "", :value => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :meeting_requests => {:mentors => "", :mentees => ""}},
      :profile => {:questions => {:questions_1 => {:question => "", :operator => "", :value => ""}}, :score => {:operator => "", :value => ""}},
      :others => {:tags => ""}
    }
    admin_view = programs(:albers).admin_views.create!(:title => "Sample Title", :filter_params => AdminView.convert_to_yaml(filter_params))

    get :edit, params: { :id => admin_view.id}

    assert assigns(:filter_params).present?
    assert_false assigns(:applied_filters)
    assert assigns(:profile_questions).present?
    assert programs(:albers).organization.skype_enabled?
    assert assigns(:profile_questions).collect(&:question_text).include?("Skype ID")
    assert_false assigns(:used_as_filter)
  end

  def test_edit_from_bulk_match
    current_user_is :f_admin
    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}".split(",")}},
      :connection_status => {:status => "", :availability => {:operator => "", :value => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :meeting_requests => {:mentors => "", :mentees => ""}},
      :profile => {:questions => {:questions_1 => {:question => "", :operator => "", :value => ""}}, :score => {:operator => "", :value => ""}},
      :others => {:tags => ""}
    }
    admin_view = programs(:albers).admin_views.create!(:title => "Sample Title", :filter_params => AdminView.convert_to_yaml(filter_params))

    get :edit, params: { :id => admin_view.id, :source_info => {controller: "bulk_matches"}}
    assert_response :success

    assert assigns(:admin_view).present?
    assert assigns(:used_as_filter)
  end

  def test_update_admin_view
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.create!(title: "Sample Title",
      filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::ADMIN_NAME] }, state: { active: "active" } } } )
    filter_params = admin_view.filter_params
    assert_equal "Sample Title", admin_view.title
    admin_view.create_default_columns
    assert_equal 10, admin_view.admin_view_columns.size

    assert_difference "AdminViewColumn.count", -7 do
      post :update, params: { id: admin_view.id, admin_view: { title: "New Title", description: "New Description", roles_and_status:
        { role_filter_1: { type: :include, roles: [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME] }, state: { active: "active" } } }.merge(
          admin_view_columns: [AdminViewColumn::Columns::Key::MEMBER_ID, AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME])
      }
    end

    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_equal 3, admin_view.admin_view_columns.size
    filter_hash = YAML.load(assigns(:admin_view).filter_params)
    assert_equal "New Title", assigns(:admin_view).title
    assert_equal "New Description", assigns(:admin_view).description
    assert_equal [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], filter_hash[:roles_and_status][:role_filter_1][:roles]
    assert_equal "active", filter_hash[:roles_and_status][:state][:active]
  end

  def test_strip_choices_in_operator
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    assert_difference "AdminView.count", 1 do
      post :create, xhr: true, params: { format: :js, admin_view: {"admin_view[default_view]" => AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW,"create_default_columns" => true, "title"=>"new_title", "description"=>"new_description", "role"=> role.id, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"6", "operator"=>AdminViewsHelper::QuestionType::IN.to_s, "value"=>"abcd  defg   ,hig   , sdijb"}, "questions_2"=>{"question"=>"3", "operator"=>AdminViewsHelper::QuestionType::IN.to_s, "scope"=>AdminView::LocationScope::COUNTRY, "value"=>"India|Ukraine"}}}}}
    end
    expected_profile_filters = {"questions"=>{"questions_1"=>{"question"=>"6", "operator"=>"7", "value"=>"abcd  defg,hig,sdijb"}, "questions_2"=>{"question"=>"3", "operator"=>"7", "scope"=>"country", "value"=>"India|Ukraine"}}}
    assert_equal expected_profile_filters, AdminView.last.filter_params_hash[:profile]
  end

  def test_strip_choices_not_in_operator
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    assert_difference "AdminView.count", 1 do
      post :create, xhr: true, params: { format: :js, admin_view: {"admin_view[default_view]" => AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW,"create_default_columns" => true, "title"=>"new_title", "description"=>"new_description", "role"=> role.id, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"6", "operator"=>AdminViewsHelper::QuestionType::NOT_IN.to_s, "value"=>"abcd  defg   ,hig   , sdijb"}, "questions_2"=>{"question"=>"3", "operator"=>AdminViewsHelper::QuestionType::NOT_IN.to_s, "scope"=>AdminView::LocationScope::COUNTRY, "value"=>"India|Ukraine"}}}}}
    end
    expected_profile_filters = {"questions"=>{"questions_1"=>{"question"=>"6", "operator"=>"8", "value"=>"abcd  defg,hig,sdijb"}, "questions_2"=>{"question"=>"3", "operator"=>"8", "scope"=>"country", "value"=>"India|Ukraine"}}}
    assert_equal expected_profile_filters, AdminView.last.filter_params_hash[:profile]
  end

  def test_admin_views_signup_state
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.create!(:title => "Sample Title", :filter_params => {:roles_and_status => {role_filter_1: {type: :include, :roles => "admin,mentor,student".split(',')}, :signup_state => {:accepted_not_signed_up_users => AdminView::RolesStatusQuestions::ACCEPTED_NOT_SIGNED_UP, :added_not_signed_up_users => AdminView::RolesStatusQuestions::ADDED_NOT_SIGNED_UP}}}.to_yaml)
    filter_params = admin_view.filter_params
    admin_view.create_default_columns

    get :show, params: { :id => admin_view.id, :page => 1, :items_per_page => 1000}
    assert_response :success

    filter_hash = YAML.load(assigns(:admin_view).filter_params)
    assert assigns(:objects).present?
    assert_false assigns(:objects).include?(users(:mentor_1))
    assert_false assigns(:objects).include?(users(:mentor_2))
    assert assigns(:objects).include?(users(:f_mentor))
    assert_equal "Sample Title", assigns(:admin_view).title
    assert_equal ["admin", "mentor", "student"], filter_hash[:roles_and_status][:role_filter_1][:roles]
    assert_equal AdminView::RolesStatusQuestions::ADDED_NOT_SIGNED_UP, filter_hash[:roles_and_status][:signup_state][:added_not_signed_up_users]
    assert_equal AdminView::RolesStatusQuestions::ACCEPTED_NOT_SIGNED_UP, filter_hash[:roles_and_status][:signup_state][:accepted_not_signed_up_users]
    assert_nil filter_hash[:roles_and_status][:signup_state][:signed_up_users]
  end

  def test_admin_views_and_columns_in_transaction
    user = users(:f_admin)
    program = user.program

    current_user_is user
    admin_view = program.admin_views.create!(title: "Sample Title", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::ADMIN_NAME] }, state: { active: "active" } } } )
    assert_equal "Sample Title", admin_view.title
    admin_view.create_default_columns
    assert_equal 10, admin_view.admin_view_columns.size

    section_params = { title: "Sample Title", roles_and_status: "sample", others: "awesome", connection_status: { new_data: "" },
      profile: { "questions" => { "questions_1" => { "question" => "5", "operator" => "3", "value" => "ewqcev" }, "questions_2" => { "question" => "4", "operator" => "4", "value" => "" } } } }
    admin_views_size = AdminView.count
    admin_views_columns_size = AdminViewColumn.count
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :title do
      post :create, params: { admin_view: section_params.merge(new_key: "sample_value").merge(admin_view_columns: [AdminViewColumn::Columns::Key::FIRST_NAME, AdminViewColumn::Columns::Key::LAST_NAME])}
    end
    assert_equal admin_views_size, AdminView.count
    assert_equal admin_views_columns_size, AdminViewColumn.count
  end

  def test_select_all_ids
    current_user_is :f_admin
    get :select_all_ids, params: { :id => programs(:albers).admin_views.first}
    assert_response :success
  end

  def test_add_to_program
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)
    assert_false members(:f_student).user_in_program(programs(:moderated_program))
    assert_emails 1 do
      assert_difference "User.count", 1 do
        assert_difference "RecentActivity.count", 1 do
          post :add_to_program, params: { :admin_view => {:members => "2",:role_names => ["mentor"], :program_id => programs(:moderated_program).id}, :id => programs(:org_primary).admin_views.first, :from => AdminViewsController::REFERER::ADMIN_VIEW}
        end
      end
    end
    last_user = User.last
    assert_equal ["mentor"], last_user.role_names
    assert_equal programs(:moderated_program), last_user.program
    assert_equal 2, last_user.member.id
    assert_redirected_to admin_view_path(programs(:org_primary).admin_views.first)

    assert_emails 0 do
      assert_difference "User.count", 0 do
        post :add_to_program, params: { :admin_view => {:members => "2",:role_names => ["mentor"], :program_id => programs(:moderated_program).id}, :id => programs(:org_primary).admin_views.first, :from => AdminViewsController::REFERER::ADMIN_VIEW}
      end
    end
    assert_equal ["mentor"], User.last.role_names
    assert_redirected_to admin_view_path(programs(:org_primary).admin_views.first)

    assert_emails 1 do
      assert_difference "User.count", 0 do
        assert_difference "RecentActivity.count", 1 do
          post :add_to_program, params: { :admin_view => {:members => "2",:role_names => ["mentor", "student"], :program_id => programs(:moderated_program).id}, :id => programs(:org_primary).admin_views.first, :from => AdminViewsController::REFERER::MEMBER_PATH}
        end
      end
    end
    assert_equal ["mentor", "student"], User.last.role_names
    assert_redirected_to member_path(2)
  end

  def test_edit_admin_views_post_and_pre_tags_enabled
    current_user_is :f_admin
    filter_params = {:roles_and_status => {role_filter_1: {type: :include, :roles => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME},#{RoleConstants::STUDENT_NAME}".split(',')}},
      :connection_status => {:status => "", :availability => {:operator => "", :value => ""}, :mentoring_requests => {:mentors => "", :mentees => ""}, :meeting_requests => {:mentors => "", :mentees => ""}},
      :profile => {:questions => {:questions_1 => {:question => "", :operator => "", :value => ""}}, :score => {:operator => "", :value => ""}}
    }
    admin_view = programs(:albers).admin_views.create!(:title => "Sample Title", :filter_params => AdminView.convert_to_yaml(filter_params))

    programs(:org_primary).enable_feature(FeatureName::MEMBER_TAGGING)

    get :edit, params: { :id => admin_view.id}
    assert_response :success

    assert assigns(:filter_params).present?
  end

  def test_organization_admin_views_of_standalone
    current_member_is :foster_admin
    programs(:org_foster).enable_feature(FeatureName::ORGANIZATION_PROFILES, true)

    get :show, params: { :id => programs(:org_foster).admin_views.find_by(title: "All Members")}
    assert_response :success

    assert assigns(:objects).present?

    assert_equal Member.name, assigns(:objects).first.class.name
    assert_equal programs(:org_foster).members.size, assigns(:objects).size

    get :show, params: { :id => programs(:foster).admin_views.first}
    assert_response :success
    assert_equal User.name, assigns(:objects).first.class.name
  end

  def test_get_admin_view_of_standalone
    current_member_is :foster_admin
    programs(:org_foster).enable_feature(FeatureName::ORGANIZATION_PROFILES, true)
    #ActiveRecord::RecordNotFound Exception: Couldn't find AdminView
    assert_raise ActiveRecord::RecordNotFound, "Couldn't find AdminView" do
       get :show, params: { :id => 12345}
    end
    assert_nil @admin_view
  end

  def test_organization_admin_views_of_standalone
    current_member_is :foster_admin
    programs(:org_foster).enable_feature(FeatureName::ORGANIZATION_PROFILES, true)

    get :edit, params: { :id => programs(:org_foster).admin_views.find_by(title: "All Members")}
    assert_response :success
    assert_match /Any Status/, response.body
  end

  def test_organization_admin_views_of_standalone_license_count
    current_member_is :foster_admin

    get :edit, params: { :id => programs(:org_foster).admin_views.find_by(title: "Users Counting Against License")}
    assert_response :success
    assert_match /Members who are active in at least one program/, response.body
  end

  def test_resend_signup_instructions
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first

    assert_difference "Password.count", 2 do
      assert_difference "ActionMailer::Base.deliveries.size", 2 do
        post :resend_signup_instructions, params: { :admin_view => {:users => "1,2"}, :id => admin_view.id}
      end
    end

    assert_equal admin_view.id, assigns(:admin_view).id
    assert_equal 2, assigns(:users).size
    assert_equal_unordered [1, 2], assigns(:users).collect(&:id)
    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_equal 'The signup instructions for the selected users has been sent successfully', flash[:notice]
  end

  def test_resend_signup_instructions_in_case_of_email_disabled
    current_user_is :f_admin
    programs(:albers).mailer_template_enable_or_disable(ResendSignupInstructions, false)
    admin_view = programs(:albers).admin_views.first

    assert_no_difference "Password.count" do
      assert_no_difference "ActionMailer::Base.deliveries.size" do
        post :resend_signup_instructions, params: { :admin_view => {:users => "1,2"}, :id => admin_view.id}
      end
    end

    assert_equal admin_view.id, assigns(:admin_view).id
    assert_equal 2, assigns(:users).size
    assert_equal_unordered [1, 2], assigns(:users).collect(&:id)
    assert_redirected_to admin_view_path(assigns(:admin_view))
    assert_nil flash[:notice]
  end

  def test_resend_signup_instructions_different_referrer
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    user = users(:f_mentor)

    assert_difference "Password.count", 1 do
      assert_difference "ActionMailer::Base.deliveries.size", 1 do
        post :resend_signup_instructions, params: { :admin_view => {:users => "#{user.id}"}, :id => admin_view.id, :from => AdminViewsController::REFERER::MEMBER_PATH}
      end
    end
    assert_redirected_to member_path(user)
    assert_equal 'The signup instructions for the selected user has been sent successfully', flash[:notice]
  end

  def test_render_bulk_confirmation_view_for_xhr_show_resend_signup_instructions
    current_user_is :f_admin

    post :bulk_confirmation_view, xhr: true, params: { :id => programs(:albers).admin_views.first, :bulk_action_confirmation => {:users => "1,2", :type => AdminViewsHelper::BulkActionType::RESEND_SIGNUP_INSTR, :title => "Resend Signup Instructions"}}
    assert_response :success

    assert_match ResendSignupInstructions.mailer_attributes[:uid], response.body
    assert_equal "Resend Signup Instructions", assigns(:bulk_action_title)
    assert_equal 8, assigns(:bulk_action_type)
    assert assigns(:users).present?
  end


  def test_update_admin_view_js
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    assert_difference "AdminView.count", 1 do
      post :create, xhr: true, params: { format: :js, admin_view: {"admin_view[default_view]" => AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW,"create_default_columns" => true, "title"=>"new_title", "description"=>"new_description", "role"=> role.id, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"5", "operator"=>"3", "value"=>"ewqcev"}, "questions_2"=>{"question"=>"4", "operator"=>"4", "value"=>""}}}}}
    end
    admin_view = programs(:albers).admin_views.last
    assert_no_difference "AdminView.count" do
      put :update, xhr: true, params: { format: :js, id: admin_view.id, admin_view: {"title"=>"new_title", "description"=>"new_description", "role"=> role.id, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"5", "operator"=>"3", "value"=>"ewqcev"}, "questions_2"=>{"question"=>"4", "operator"=>"4", "value"=>""}}}}}
    end
    expected_profile_filters = {"profile"=>{"questions"=>{"questions_1"=>{"question"=>"5", "operator"=>"3", "value"=>"ewqcev"}, "questions_2"=>{"question"=>"4", "operator"=>"4", "value"=>""}}}}
    assert_response :success
    admin_view.reload
    assert_equal expected_profile_filters, admin_view.filter_params_hash
  end

  def test_create_admin_view_js
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    # AdminView.any_instance.stubs(:editable?).returns(false)
    assert_difference "AdminView.count", 1 do
      post :create, xhr: true, params: { format: :js, admin_view: {"admin_view[default_view]" => AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW,"create_default_columns" => true, "title"=>"new_title", "description"=>"new_description", "role"=> role.id, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"5", "operator"=>"3", "value"=>"ewqcev"}, "questions_2"=>{"question"=>"4", "operator"=>"4", "value"=>""}}}}}
    end
    expected_profile_filters = {"profile"=>{"questions"=>{"questions_1"=>{"question"=>"5", "operator"=>"3", "value"=>"ewqcev"}, "questions_2"=>{"question"=>"4", "operator"=>"4", "value"=>""}}}}
    assert_response :success
    admin_view = AdminView.last
    admin_view_column_keys = admin_view.admin_view_columns.collect { |c| c.column_key }
    assert_equal expected_profile_filters, admin_view.filter_params_hash
    assert_equal admin_view.get_default_columns.keys, admin_view_column_keys
  end

  def test_get_new_admin_view_js
    current_user_is :f_admin
    get :new, xhr: true, params: { format: :js, role: programs(:albers).roles.first.id}
    assert_response :success
    assert_template "_new"
    assert assigns(:profile_questions)
  end

  def test_edit_admin_view_js
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    AdminView.any_instance.stubs(:editable?).returns(true)
    post :create, xhr: true, params: { format: :js, admin_view: {"title"=>"new_title", "description"=>"new_description", "role"=> role.id, "profile"=>{"questions"=>{"questions_1"=>{"question"=>"5", "operator"=>"3", "value"=>"ewqcev"}, "questions_2"=>{"question"=>"4", "operator"=>"4", "value"=>""}}}}}
    assert_response :success
    admin_view = programs(:albers).admin_views.last
    get :edit, xhr: true, params: { format: :js, id: admin_view.id, role: programs(:albers).roles.first.id}
    assert_response :success
    assert_template "_new"
    assert assigns(:profile_questions)
  end

  def test_non_mandatory_default_views
    current_user_is :f_admin

    assert_difference "AdminView.count" do
      # The default view, we are expecting here is the never signed up non mandatory view
      default = AdminView::DefaultAdminView.non_mandatory_views(programs(:org_primary)).first
      programs(:albers).create_default_admin_views(default)
    end

    admin_view = AdminView.last

    get :show, params: { :id => admin_view.id}

    assert_response :success
    assert assigns(:admin_view).present?
    assert assigns(:objects).present?
    assert assigns(:objects).include?(users(:f_mentor))
    assert_false assigns(:objects).include?(users(:mentor_1))
    assert_false assigns(:objects).include?(users(:mentor_2))
  end

  def test_show_filtering
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    column = admin_view.admin_view_columns.first

    AdminView.any_instance.expects(:generate_view).with("first_name", "asc", true, { page: 1, per_page: 25 }, { role_names: [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME],
      member_id: "1", first_name: "first_name", last_name: "last_name", email: "email",
      profile_field_filters: [ { "field" => "column#{column.id}", "operator" => "eq", "value" => "anna" } ],
      non_profile_field_filters: [
        { "field" => "first_name", "operator" => "eq", "value" => "first_name" },
        { "field" => "last_name", "operator" => "eq", "value" => "last_name" },
        { "field" => "email", "operator" => "eq", "value" => "email" },
        { "field" => "roles", "operator" => "eq", "value" => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME}" },
        { "field" => "member_id", "operator" => "eq", "value" => "1" }
      ] }, nil, nil).returns([])

    get :show, params: { id: admin_view.id, "filter" => { "filters" => {
      "0" => { "field" => "first_name", "operator" => "eq", "value" => "first_name" },
      "1" => { "field" => "last_name", "operator" => "eq", "value" => "last_name" },
      "2" => { "field" => "email", "operator" => "eq", "value" => "email" },
      "3" => { "field" => "roles", "operator" => "eq", "value" => "#{RoleConstants::ADMIN_NAME},#{RoleConstants::MENTOR_NAME}" },
      "4" => { "field" => "member_id", "operator" => "eq", "value" => "1" },
      "5" => { "field" => "column#{column.id}", "operator" => "eq", "value" => "anna" } } }
    }
    assert_response :success
  end

  def test_meeting_requests_date_range_filter
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    get :show, params: { :id => admin_view.id, "filter"=>{"filters"=>{
                                       "0"=>{"field"=>"meeting_requests_received_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "1"=>{"field"=>"meeting_requests_sent_and_accepted_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "2"=>{"field"=>"meeting_requests_sent_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "3"=>{"field"=>"meeting_requests_received_and_accepted_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "4"=>{"field"=>"meeting_requests_sent_and_pending_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "5"=>{"field"=>"meeting_requests_received_and_pending_v1", "operator"=>"eq", "value"=>"7/8/2010"}
                                     }}
                                   }

    assert_equal ({"meeting_requests_received_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day,
                  "meeting_requests_sent_and_accepted_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day,
                  "meeting_requests_sent_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day,
                  "meeting_requests_received_and_accepted_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day, "meeting_requests_sent_and_pending_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day, "meeting_requests_received_and_pending_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day}), assigns(:date_ranges)
  end

  def test_mentoring_requests_date_range_filter
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    get :show, params: { :id => admin_view.id, "filter"=>{"filters"=>{
                                       "0"=>{"field"=>"mentoring_requests_sent_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "1"=>{"field"=>"mentoring_requests_sent_and_pending_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "2"=>{"field"=>"mentoring_requests_received_v1", "operator"=>"eq", "value"=>"7/8/2010"},
                                       "3"=>{"field"=>"mentoring_requests_received_and_pending_v1", "operator"=>"eq", "value"=>"7/8/2010"}
                                     }}
                                   }

    assert_equal ({"mentoring_requests_sent_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day,
                  "mentoring_requests_sent_and_pending_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day,
                  "mentoring_requests_received_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day,
                  "mentoring_requests_received_and_pending_v1"=> "8/7/2010".to_time.."8/7/2010".to_time.end_of_day}), assigns(:date_ranges)
  end

  def test_get_invite_to_program_roles
    current_member_is :f_admin
    admin_view = AdminView.first

    get :get_invite_to_program_roles, xhr: true, params: { program_id: programs(:albers).id, id: admin_view.id}
    assert_response :success

    assert_equal programs(:albers), assigns(:program)
    assert_equal users(:f_admin), assigns(:user)
  end

  def test_get_add_to_program_roles_non_admin_cannot_access
    current_member_is :f_mentor

    assert_permission_denied do
      get :get_add_to_program_roles, xhr: true, params: { program_id: programs(:albers).id}
    end
  end

  def test_get_add_to_program_roles_success
    current_member_is :f_admin
    get :get_add_to_program_roles, xhr: true, params: { program_id: programs(:albers).id}
    assert_response :success

    assert_equal programs(:albers), assigns(:program)
  end

  def test_suspend_member_membership
    admin = members(:f_admin)
    member_1 = members(:f_mentor)
    member_2 = members(:f_student)
    User.any_instance.expects(:close_pending_received_requests_and_offers).times(member_1.users.count)
    admin_view = admin.organization.admin_views.first

    Member.expects(:removal_or_suspension_scope).once.returns(Member.where(id: member_1.id))
    current_member_is admin
    current_time = Time.now

    Timecop.freeze(current_time) do
      assert_emails 1 do
        post :suspend_member_membership, params: { admin_view: { members: "#{admin.id},#{member_1.id},#{member_2.id}", reason: "Suspension Reason" }, id: admin_view}
      end
    end
    assert_redirected_to admin_view_path(admin_view)
    assert_equal "#{admin.name(name_only: true)}, #{member_2.name} have not been suspended", flash[:error]
    assert_equal [admin, member_2], assigns(:members_ignored_for_removal_or_suspension)
    assert_equal [member_1], assigns(:members_for_removal_or_suspension)
    assert_false admin.reload.suspended?
    assert member_1.reload.suspended?
    assert_false member_2.reload.suspended?
    assert current_time, member_1.last_suspended_at
    assert_nil admin.last_suspended_at
    assert_nil member_2.last_suspended_at
  end

  def test_reactivate_member_membership
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::ORGANIZATION_PROFILES)

    members(:f_mentor).update_attribute :state, Member::Status::SUSPENDED
    assert members(:f_mentor).suspended?
    assert_emails 1 do
      post :reactivate_member_membership, params: { :admin_view => {:members => "#{members(:f_mentor).id}"}, :id => programs(:org_primary).admin_views.first}
    end

    assert members(:f_mentor).reload.active?
    assert_equal 'The selected members have been reactivated in the Primary Organization', flash[:notice]
  end

  def test_bulk_remove_members_limit_exceeded
    current_member_is :f_admin
    org = programs(:org_primary)
    org.enable_feature(FeatureName::ORGANIZATION_PROFILES)

    assert_difference "Member.count", 0 do
      post :remove_member, params: { :admin_view => {:members => org.members.pluck(:id).join(",") }, :id => org.admin_views.first}
    end
    assert_equal "Please select 25 or fewer users to delete at one time.", flash[:error]
    assert_redirected_to admin_view_path(assigns(:admin_view))
  end

  def test_remove_member
    member = members(:ram)
    admin = members(:f_admin)
    organization = admin.organization
    organization.enable_feature(FeatureName::ORGANIZATION_PROFILES)

    Member.expects(:removal_or_suspension_scope).once.returns(Member.where(id: member.id))
    current_member_is admin
    assert_difference "Member.count", -1 do
      post :remove_member, params: { admin_view: { members: "#{admin.id},#{member.id}" }, id: organization.admin_views.first}
    end
    assert_response :redirect
    assert_equal "#{admin.name(name_only: true)} has not been removed", flash[:error]
    assert_equal [admin], assigns(:members_ignored_for_removal_or_suspension)
  end

  def test_auto_complete_for_name
    program = programs(:albers)
    admin_view = program.admin_views.first
    admin_view.description = "Sample Admin View"
    admin_view.save!

    current_user_is :f_admin
    get :auto_complete_for_name, xhr: true, params: { format: :json}
    assert_response :success
    output = JSON.parse(response.body)
    assert_equal program.admin_views.count, output.count
    output = output.find { |av| av["id"] == admin_view.id }
    assert_equal "Sample Admin View", output["description"]
    assert_equal "All Users", output["title"]
    assert_equal "fa fa-star", output["icon"]
  end

  def test_locations_autocomplete_city
    current_user_is :f_admin
    get :locations_autocomplete, xhr: true, params: { search: "c", scope: AdminView::LocationScope::CITY}
    assert_response :success
    output = JSON.parse(response.body)
    assert_equal ["Cha-am, Changwat Phetchaburi, Thailand", "Chennai, Tamil Nadu, India", "Pondicherry, Pondicherry, India"], output
  end

  def test_locations_autocomplete_state
    current_user_is :f_admin
    get :locations_autocomplete, xhr: true, params: { search: "t", scope: AdminView::LocationScope::STATE}
    assert_response :success
    output = JSON.parse(response.body)
    assert_equal ["Tamil Nadu, India", "Changwat Phetchaburi, Thailand", "Good State, Nice Country"], output
  end

  def test_locations_autocomplete_country
    current_user_is :f_admin
    get :locations_autocomplete, xhr: true, params: { search: "i", scope: AdminView::LocationScope::COUNTRY}
    assert_response :success
    output = JSON.parse(response.body)
    assert_equal ["India", "Nice Country", "Thailand", "Ukraine", "United Kingdom"], output
  end

  def test_toggle_favourite
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    post :toggle_favourite, params: { :id => admin_view.id, :format => 'js'}
    assert_response :success
    assert_not_equal admin_view.favourite, admin_view.reload.favourite
  end

   def test_fetch_survey_questions_no_params
    current_user_is :f_admin
    prog = programs(:albers)
    get :fetch_survey_questions, xhr: true
    assert_nil assigns(:survey)
    assert_nil assigns(:survey_questions)
    assert_equal 0, assigns(:rows_size)
    assert_equal 0, assigns(:prefix_id)
  end

  def test_fetch_survey_questions
    current_user_is :f_admin
    survey = programs(:albers).surveys.of_engagement_type.sample
    create_matrix_survey_question({survey: survey})
    get :fetch_survey_questions, xhr: true, params: {:survey_id => survey.id, :rows_size => 1, :prefix_id => 1 }
    assert_equal survey, assigns(:survey)
    assert_equal survey.get_questions_in_order_for_report_filters, assigns(:survey_questions)
    assert_equal 1, assigns(:rows_size)
    assert_equal 1, assigns(:prefix_id)
  end

  def test_admin_view_access
    current_organization_is :org_primary
    get :show, params: { :id => programs(:org_primary).admin_views.first}
    assert_redirected_to new_session_url
    current_program_is :albers
    get :show, params: { :id => programs(:albers).admin_views.first}
    assert_redirected_to new_session_url
  end

  def test_fetch_admin_view_details_should_call_generate_view_with_expected_params
    current_user_is :f_admin
    admin_view = programs(:albers).admin_views.first
    AdminView.any_instance.expects(:generate_view).with("", "", false).returns([])
    get :fetch_admin_view_details, xhr: true, params: { :campaign_id => "", :id => admin_view.id, format: :js}
    assert_response :success
  end

  def test_listing_admin_views_ordered
    current_user_is :f_admin
    program = programs(:albers)
    admin_view = program.admin_views.last
    admin_view.favourite ? admin_view.unset_favourite! : admin_view.set_favourite!
    get :show, params: { :id => programs(:albers).admin_views.first}
    assert_equal assigns(:other_admin_views).first, admin_view.reload
    admin_view.favourite ? admin_view.unset_favourite! : admin_view.set_favourite!
    get :show, params: { :id => programs(:albers).admin_views.first}
    assert_equal assigns(:other_admin_views).last, admin_view.reload
  end

  def test_ongoing_filters_present_if_ongoing_mentoring_enabled
    current_user_is :f_admin
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED_WITH_ONGOING)
    programs(:albers).reload

    get :new
    assert_response :success
    assert_select "div.cui_admin_view_step_two" do
      assert_select "select#cjs-connection-status-filter-category-0"
      assert_select "select#new_view_filter_mentor_availability_status"
      assert_select "select#new_view_filter_mentees_mentoring_requests"
      assert_select "select#new_view_filter_mentors_mentoring_requests"
      assert_select "select#cjs_last_connection_type"
    end
  end

  def test_ongoing_filters_not_present_if_ongoing_mentoring_disabled
    current_user_is :f_admin
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    programs(:albers).reload

    get :new
    assert_response :success

    assert_no_select "div#engagement_status_content"
    assert_no_select "select#cjs-connection-status-filter-category-0"
    assert_no_select "select#new_view_filter_mentor_availability_status"
    assert_no_select "select#cjs_last_connection_type"
  end

  def test_create_for_eligibility_message
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    assert_difference "AdminView.count", 1 do
      post :create, xhr: true, params: { format: :js, admin_view: {"admin_view[default_view]" => AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW,"create_default_columns" => true, "title"=>"new_title", "description"=>"new_description", "role"=> role.id, "#{role.name}_eligibility_message" => "Customized Message for Mentor"}}
    end
    assert_equal "Customized Message for Mentor", role.eligibility_message
    current_user_is :f_admin

  end

  def test_update_admin_view_for_eligibility_message
    organization = programs(:org_primary)
    program = programs(:albers)
    role = program.roles.find_by(name: "mentor")
    current_user_is :f_admin
    assert_difference "AdminView.count", 1 do
      post :create, xhr: true, params: { format: :js, admin_view: {"admin_view[default_view]" => AbstractView::DefaultType::ELIGIBILITY_RULES_VIEW,"create_default_columns" => true, "title"=>"new_title", "description"=>"new_description", "role"=> role.id, "#{role.name}_eligibility_message" => "Customized Message for Mentor"}}
    end
    assert_equal "Customized Message for Mentor", role.eligibility_message
  end

  def test_handle_advanced_options_choices
    current_user_is :f_admin

    section_params = {:title => "Sample Title", :description => "Sample Description", :connection_status => {:advanced_options => {:mentoring_requests => {:mentors => {:request_duration => "1", "1" => "", "2" => "", "3" => ""}, :mentees => {:request_duration => "1", "1" => "invalid value", "2" => "", "3" => ""}}, :meeting_requests => {:mentors => {:request_duration => "2", "1" => "", "2" => "invalid date", "3" => ""}, :mentees => {:request_duration => "3", "1" => "", "2" => "", "3" => "invalid date"}}, :meetingconnection_status => {:both => {:request_duration => "2", "1" => "10", "2" => "01/03/2015", "3" => ""}}}}}

    assert_difference "AdminView.count", 1 do
      post :create, params: { :admin_view => section_params.merge(:admin_view_columns => ["first_name", "last_name"])}
    end

    admin_view = AdminView.last

    advanced_options_hash = admin_view.filter_params_hash[:connection_status][:advanced_options]

    assert_equal advanced_options_hash[:mentoring_requests][:mentors], {"request_duration" => "4", "1" => "", "2" => "", "3" => ""}
    assert_equal advanced_options_hash[:mentoring_requests][:mentees], {"request_duration" => "4", "1" => "", "2" => "", "3" => ""}
    assert_equal advanced_options_hash[:meeting_requests][:mentors], {"request_duration" => "4", "1" => "", "2" => "", "3" => ""}
    assert_equal advanced_options_hash[:meeting_requests][:mentors], {"request_duration" => "4", "1" => "", "2" => "", "3" => ""}
    assert_equal advanced_options_hash[:meetingconnection_status][:both], {"request_duration" => "2", "1" => "", "2" => "01/03/2015", "3" => ""}
  end

  def test_handle_profile_filters_for_date_question
    admin_view_controller = AdminViewsController.new
    assert_nil admin_view_controller.send(:handle_profile_filters_for_date_question, nil)
    
    date_question = profile_questions(:date_question)
    profile_question_hash = HashWithIndifferentAccess.new({"questions"=>{"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "number_of_days"=>"222", "date_value"=>" -  - before_last_n_days"}}})
    assert_equal_hash ({"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "number_of_days"=>"222", "date_value"=>" -  - before_last_n_days", "operator"=>"11"}}), admin_view_controller.send(:handle_profile_filters_for_date_question, profile_question_hash)["questions"]

    profile_question_hash = HashWithIndifferentAccess.new({"questions"=>{"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "date_value"=>"01/01/2018 - 01/31/2018 - custom"}}})
    assert_equal_hash ({"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "date_value"=>"01/01/2018 - 01/31/2018 - custom", "operator"=>"11"}}), admin_view_controller.send(:handle_profile_filters_for_date_question, profile_question_hash)["questions"]

    profile_question_hash = HashWithIndifferentAccess.new({"questions"=>{"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "number_of_days"=>"222", "date_value"=>"", "date_operator"=>"in_next"}}})
    assert_equal_hash ({"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "number_of_days"=>"222", "date_value"=>"", "operator"=>"11", "date_operator"=>"in_next"}}), admin_view_controller.send(:handle_profile_filters_for_date_question, profile_question_hash)["questions"]

    profile_question_hash = HashWithIndifferentAccess.new({"questions"=>{"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "date_value"=>"", "date_operator"=>"filled"}}})
    assert_equal_hash ({"questions_1"=>{"question"=>date_question.id.to_s, "value"=>"", "choice"=>"", "date_value"=>"", "operator"=>"4", "date_operator"=>"filled"}}), admin_view_controller.send(:handle_profile_filters_for_date_question, profile_question_hash)["questions"]
  end

  def test_bulk_add_users_to_project
    current_user_is :f_admin
    group = groups(:group_pbe_1)
    program = programs(:pbe)
    roles = program.roles.for_mentoring
    users = program.users
    current_program_is :pbe

    get :bulk_add_users_to_project, xhr: true, params: { group_id: group.id, user_ids: users.collect(&:id) }
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal roles, assigns(:group_roles)
    assert_equal users, assigns(:users)
  end
end
