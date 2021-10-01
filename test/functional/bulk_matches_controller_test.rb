require_relative './../test_helper.rb'

class BulkMatchesControllerTest < ActionController::TestCase

  def setup
    super
    programs(:albers).enable_feature(FeatureName::BULK_MATCH)
  end

  def test_permission_denied_feature_disabled
    programs(:albers).enable_feature(FeatureName::BULK_MATCH, false)
    current_user_is :f_admin
    assert_permission_denied do
      get :bulk_match
    end
  end

  def test_bulk_match_should_be_admin
    current_user_is :f_mentor
    assert_permission_denied do
      get :bulk_match
    end
  end

  def test_bulk_match_with_default_as_create_matches
    program = programs(:albers)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])
    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :f_admin
    get :bulk_match
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    assert_equal mentor_views[0], assigns(:mentor_view)
    assert_equal student_views[0], assigns(:mentee_view)
    assert_equal mentor_views, assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
    assert_equal bulk_matches(:bulk_match_1), assigns(:bulk_match)
    expected_source_info = { "controller" => "bulk_matches", "action" => "bulk_match" }
    assert_equal expected_source_info, assigns(:set_source_info)
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
  end

  def test_bulk_match_from_admin_view_unmatched_roles
    program = programs(:albers)
    admin_view = AdminView.create!(title: "New View", program: program, filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::ADMIN_NAME] } } }.to_yaml)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])
    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :f_admin
    get :bulk_match, params: { admin_view: admin_view.id}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    assert_equal mentor_views, assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
  end

  def test_bulk_match_from_admin_view_matched_roles
    program = programs(:ceg)
    program.enable_feature(FeatureName::BULK_MATCH)
    new_mentor_view = AdminView.create!(title: "New View", program: program, filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::MENTOR_NAME] } } }.to_yaml)
    mentor_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::AVAILABLE_MENTORS, AbstractView::DefaultType::MENTORS, AbstractView::DefaultType::MENTORS_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTORS_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTORS_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTORS_YET_TO_BE_DRAFTED, AbstractView::DefaultType::NEVER_CONNECTED_MENTORS, AbstractView::DefaultType::MENTORS_WITH_PENDING_MENTOR_REQUESTS])
    student_views = program.admin_views.default.where(default_view: [AbstractView::DefaultType::MENTEES, AbstractView::DefaultType::NEVER_CONNECTED_MENTEES, AbstractView::DefaultType::CURRENTLY_NOT_CONNECTED_MENTEES, AbstractView::DefaultType::MENTEES_REGISTERED_BUT_NOT_ACTIVE, AbstractView::DefaultType::MENTEES_WITH_LOW_PROFILE_SCORES, AbstractView::DefaultType::MENTEES_IN_DRAFTED_CONNECTIONS, AbstractView::DefaultType::MENTEES_YET_TO_BE_DRAFTED, AbstractView::DefaultType::MENTEES_WHO_SENT_REQUEST_BUT_NOT_CONNECTED, AbstractView::DefaultType::MENTEES_WHO_HAVENT_SENT_MENTORING_REQUEST])

    current_user_is :ceg_admin
    get :bulk_match, params: { admin_view_id: new_mentor_view.id}
    assert_response :success
    assert_equal [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], assigns(:admin_view_role_hash).keys
    assert_equal_unordered mentor_views + [new_mentor_view], assigns(:admin_view_role_hash)[RoleConstants::MENTOR_NAME]
    assert_equal_unordered student_views, assigns(:admin_view_role_hash)[RoleConstants::STUDENT_NAME]
    assert_equal new_mentor_view, assigns(:mentor_view)
    assert_nil assigns(:mentee_view)
  end

  def test_bulk_match_xhr_with_existing_bulk_match
    program = programs(:albers)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]

    set_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    @controller.expects(:get_user_ids).at_least(0).with(student_view, false).returns([s1_id, s2_id])
    @controller.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([m1_id, m2_id])
    current_user_is :f_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, type: BulkMatch.name, format: :js}
    assert_response :success
    assert_equal [m1_id, m2_id], assigns(:mentor_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_mentor_hash).keys
    assert_equal [[[m1_id, 90], [m2_id, 10]], [[m1_id, 57], [m2_id, 26]]], assigns(:student_mentor_hash).values
    assert_equal [[m1_id], [m2_id]], assigns(:selected_mentors).values
    assert_equal [[[m1_id, 90], [m2_id, 10]], [[m1_id, 57], [m2_id, 26]]], assigns(:suggested_mentors).values
    assert_equal_unordered [users(:f_mentor), users(:robert)], assigns(:mentor_users)
    assert_equal_unordered [users(:f_student), users(:rahim)], assigns(:student_users)
    assert_equal_unordered program.groups.active, assigns(:active_groups)
    assert_equal_unordered program.groups.drafted, assigns(:drafted_groups)
    assert_equal_unordered program.groups.active_or_drafted, assigns(:active_drafted_groups)
    assert (assigns(:mentor_slot_hash)[m2_id] > assigns(:mentor_slot_hash)[m1_id])
    assert_equal_hash( { m1_id => users(:f_mentor).slots_available, m2_id => users(:robert).slots_available }, assigns(:mentor_slot_hash))
    assert_equal bulk_matches(:bulk_match_1), assigns(:bulk_match)
    reset_cache_values(program, s1_id, s2_id, m1_id, m2_id)
  end

  def test_bulk_match_xhr_for_mentor_to_mentee_orientation_with_existing_bulk_match
    program = programs(:albers)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]

    set_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    @controller.expects(:get_user_ids).at_least(0).with(student_view, false).returns([s1_id, s2_id])
    @controller.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([m1_id, m2_id])
    current_user_is :f_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, type: BulkMatch.name, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE, format: :js}
    assert_response :success
    assert_equal [m1_id, m2_id], assigns(:mentor_user_ids)
    assert_equal [s1_id, s2_id], assigns(:student_user_ids)
    assert_equal [m1_id, m2_id], assigns(:mentor_student_hash).keys
    assert_equal [[[s1_id, 90], [s2_id, 57]], [[s2_id, 26], [s1_id, 10]]], assigns(:mentor_student_hash).values
    assert_equal [[s1_id], [s2_id]], assigns(:selected_mentees).values
    assert_equal [[[s1_id, 90], [s2_id, 57]], [[s2_id, 26], [s1_id, 10]]], assigns(:suggested_mentees).values
    assert_equal_unordered [users(:f_mentor), users(:robert)], assigns(:mentor_users)
    assert_equal_unordered [users(:f_student), users(:rahim)], assigns(:student_users)
    assert_equal_unordered program.groups.active, assigns(:active_groups)
    assert_equal_unordered program.groups.drafted, assigns(:drafted_groups)
    assert_equal_unordered program.groups.active_or_drafted, assigns(:active_drafted_groups)
    assert (assigns(:mentor_slot_hash)[m2_id] > assigns(:mentor_slot_hash)[m1_id])
    assert_equal_hash( { m1_id => users(:f_mentor).slots_available, m2_id => users(:robert).slots_available }, assigns(:mentor_slot_hash))
    assert_equal bulk_matches(:bulk_match_2), assigns(:bulk_match)
    reset_cache_values(program, s1_id, s2_id, m1_id, m2_id)
  end

  def test_bulk_match_xhr_without_existing_bulk_match
    program = programs(:ceg)
    program.enable_feature(FeatureName::BULK_MATCH)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    s1_id = users(:arun_ceg).id
    m1_id, m2_id = [users(:f_mentor_ceg).id, users(:ceg_mentor).id]

    set_cache_values(program, s1_id, nil, m1_id, m2_id)
    @controller.expects(:get_user_ids).at_least(0).with(student_view, false).returns([s1_id])
    @controller.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([m1_id, m2_id])
    current_user_is :ceg_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, format: :js}
    assert_response :success
    assert_equal [m1_id, m2_id], assigns(:mentor_user_ids)
    assert_equal [s1_id], assigns(:student_user_ids)
    assert_equal [s1_id], assigns(:student_mentor_hash).keys
    assert_equal [[[m1_id, 90], [m2_id, 10]]], assigns(:student_mentor_hash).values
    assert_equal [[m1_id]], assigns(:selected_mentors).values
    assert_equal [[[m1_id, 90], [m2_id, 10]]], assigns(:suggested_mentors).values
    assert_equal_unordered [users(:f_mentor_ceg), users(:ceg_mentor)], assigns(:mentor_users)
    assert_equal [users(:arun_ceg)], assigns(:student_users)
    assert_equal_unordered program.groups.active, assigns(:active_groups)
    assert_equal_unordered program.groups.drafted, assigns(:drafted_groups)
    assert_equal_unordered program.groups.active_or_drafted, assigns(:active_drafted_groups)
    assert_equal_hash( { m1_id => users(:f_mentor_ceg).slots_available, m2_id => users(:ceg_mentor).slots_available }, assigns(:mentor_slot_hash))
    assert_equal program.default_max_connections_limit, assigns(:bulk_match).max_pickable_slots
    assert_nil assigns(:bulk_match).max_suggestion_count
    assert assigns(:bulk_match).request_notes
    reset_cache_values(program, s1_id, nil, m1_id, m2_id)
  end

  def test_bulk_match_xhr_for_mentor_to_mentee_orientation_without_existing_bulk_match
    program = programs(:ceg)
    program.enable_feature(FeatureName::BULK_MATCH)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    s1_id = users(:arun_ceg).id
    m1_id, m2_id = [users(:f_mentor_ceg).id, users(:ceg_mentor).id]

    set_cache_values(program, s1_id, nil, m1_id, m2_id)
    @controller.expects(:get_user_ids).at_least(0).with(student_view, false).returns([s1_id])
    @controller.expects(:get_user_ids).at_least(0).with(mentor_view, true).returns([m1_id, m2_id])
    current_user_is :ceg_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE, format: :js}
    assert_response :success
    assert_equal [m1_id, m2_id], assigns(:mentor_user_ids)
    assert_equal [s1_id], assigns(:student_user_ids)
    assert_equal [m1_id, m2_id], assigns(:mentor_student_hash).keys
    assert_equal [[[s1_id, 90]], [[s1_id, 10]]], assigns(:mentor_student_hash).values
    assert_equal [[s1_id], []], assigns(:selected_mentees).values
    assert_equal [[[s1_id, 90]], [[s1_id, 10]]], assigns(:suggested_mentees).values
    assert_equal_unordered [users(:f_mentor_ceg), users(:ceg_mentor)], assigns(:mentor_users)
    assert_equal [users(:arun_ceg)], assigns(:student_users)
    assert_equal_unordered program.groups.active, assigns(:active_groups)
    assert_equal_unordered program.groups.drafted, assigns(:drafted_groups)
    assert_equal_unordered program.groups.active_or_drafted, assigns(:active_drafted_groups)
    assert_equal_hash( { m1_id => users(:f_mentor_ceg).slots_available, m2_id => users(:ceg_mentor).slots_available }, assigns(:mentor_slot_hash))
    assert_nil assigns(:bulk_match).max_suggestion_count
    assert assigns(:bulk_match).request_notes
    reset_cache_values(program, s1_id, nil, m1_id, m2_id)
  end

  def test_bulk_match_xhr_for_not_default_views
    program = programs(:albers)
    mentor_view = program.admin_views.create!(title: "Mentors", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::MENTOR_NAME] }, state: { active: User::Status::ACTIVE } } }.to_yaml)
    student_view = program.admin_views.create!(title: "Students", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::STUDENT_NAME] }, state: { active: User::Status::ACTIVE } } }.to_yaml)

    current_user_is :f_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, format: :js}
    assert_response :success
    assert_equal_unordered assigns(:student_mentor_hash).keys, assigns(:selected_mentors).keys
    assert_blank assigns(:selected_mentors).values.flatten.uniq - assigns(:mentor_user_ids)
  end

  def test_update_bulk_match_pair_bulk_publish_request
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = group.program.student_bulk_match
    group.save!
    student = group.students.first
    mentor = group.mentors.first
    stubs(:current_program).returns(programs(:albers))
    mentoring_model = mentoring_models(:mentoring_models_1)

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::PUBLISH, group_ids: [group.id], mentoring_model_id: mentoring_model.id}
    end
    assert_response :success
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
    assert_equal Group::Status::ACTIVE, group.reload.status
    assert_equal mentoring_model, group.mentoring_model
  end

  def test_update_bulk_match_pair_bulk_publish_request_mentor_to_mentee_match
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = group.program.mentor_bulk_match
    group.save!
    student = group.students.first
    mentor = group.mentors.first
    stubs(:current_program).returns(programs(:albers))
    mentoring_model = mentoring_models(:mentoring_models_1)

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::PUBLISH, group_ids: [group.id], mentoring_model_id: mentoring_model.id, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    end
    assert_response :success
    assert_equal( { error_flash: nil, object_id_group_id_map: { mentor.id => group.id } }.to_json, @response.body)
    assert_equal Group::Status::ACTIVE, group.reload.status
  end

  def test_update_bulk_match_pair_bulk_publish_request_with_message
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = bulk_matches(:bulk_match_1)
    group.save!
    student = group.students.first
    mentor = group.mentors.first

    Group.any_instance.expects(:message=).twice
    current_user_is :f_admin
    assert_no_difference "Group.count" do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::PUBLISH, group_ids: [group.id], message: 'Test message', orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
    assert_equal Group::Status::ACTIVE, group.reload.status
  end

  def test_update_bulk_match_pair_bulk_undraft_request
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = bulk_matches(:bulk_match_1)
    group.save!

    current_user_is :f_admin
    assert_difference "Group.count", -1 do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::DISCARD, group_ids: [group.id], orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal( { error_flash: nil, object_id_group_id_map: {} }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_bulk_draft_request
    student = users(:f_student)
    mentor = users(:f_mentor)
    bulk_match = student.program.student_bulk_match
    bulk_match.request_notes = false
    bulk_match.save!

    current_user_is :f_admin
    assert_difference "Group.count", 1 do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::DRAFT, group_ids: [], student_mentor_map: { student.id => [mentor.id] }, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    group = Group.last
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
    assert_equal [student], group.students
    assert_equal [mentor], group.mentors
    assert_equal users(:f_admin), group.created_by
    assert_equal bulk_match, group.bulk_match
    assert_false bulk_match.reload.request_notes
  end

  def test_update_bulk_match_pair_bulk_draft_request_mentor_to_mentee
    student = users(:f_student)
    mentor = users(:f_mentor)
    bulk_match = student.program.mentor_bulk_match
    bulk_match.request_notes = false
    bulk_match.save!

    current_user_is :f_admin
    assert_difference "Group.count", 1 do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::DRAFT, group_ids: [], student_mentor_map: { mentor.id => [student.id] }, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    end
    assert_response :success
    group = Group.last
    assert_equal( { error_flash: nil, object_id_group_id_map: { mentor.id => group.id } }.to_json, @response.body)
    assert_equal [student], group.students
    assert_equal [mentor], group.mentors
  end

  def test_update_bulk_match_pair_bulk_draft_request_existing_drafted_pair
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.bulk_match = group.program.student_bulk_match
    group.created_by = users(:f_admin)
    group.save!

    student = group.students.first
    mentor = group.mentors.first
    current_user_is :f_admin
    assert_no_difference "Group.count" do
      post :bulk_update_bulk_match_pair, xhr: true, params: { update_type: BulkMatch::UpdateType::DRAFT, group_ids: [], student_mentor_map: { student.id => [mentor.id] } }
    end

    assert_response :success
    assert_equal "There are some problems with your request. Please fix the following errors and try again.<br/>mkr_student madankumarrajan is already drafted with Good unique name. Please select a different mentor.", JSON.parse(@response.body)["error_flash"]
  end

  def test_update_bulk_match_pair_normal_request_group_exists
    group = groups(:mygroup)

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id_list: "#{group.mentors.first.id}", student_id: group.students.first.id, update_type: BulkMatch::UpdateType::PUBLISH}
    end
    assert_response :success
    assert_nil assigns(:group)
    assert_equal( { error_flash: "The Mentoring Connection already exists between the pair.", object_id_group_id_map: {} }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_normal_request_undraft_group
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.bulk_match = group.program.student_bulk_match
    group.created_by = users(:f_admin)
    group.save!

    current_user_is :f_admin
    assert_difference "Group.count", -1 do
      get :update_bulk_match_pair, xhr: true, params: { group_id: group.id, mentor_id_list: "#{group.mentors.first.id}", student_id: group.students.first.id, update_type: BulkMatch::UpdateType::DISCARD, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal( { error_flash: nil, object_id_group_id_map: {} }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_normal_request_draft_new_group
    student = users(:rahim)

    current_user_is :f_admin
    assert_difference "Group.count", 1 do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id_list: "#{users(:ram).id}", student_id: student.id, update_type: BulkMatch::UpdateType::DRAFT, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    group = Group.last
    assert_equal group, assigns(:group)
    assert_equal Group::Status::DRAFTED, group.status
    assert_equal users(:f_admin), group.created_by
    assert_equal bulk_matches(:bulk_match_1), group.bulk_match
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_normal_request_draft_existing_drafted_pair
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.notes = "My Notes"
    group.save!
    student = group.students.first
    mentor = group.mentors.first
    assert_nil group.bulk_match

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id_list: "#{mentor.id}", student_id: student.id, update_type: BulkMatch::UpdateType::DRAFT, notes: "", orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal group.reload, assigns(:group)
    assert_equal Group::Status::DRAFTED, group.status
    assert_equal users(:f_admin), group.created_by
    assert_equal "My Notes", group.notes
    assert_not_nil group.bulk_match
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_normal_request_publish_new_group
    student = users(:rahim)
    bulk_match = bulk_matches(:bulk_match_1)
    group_name = "Group name"
    stubs(:current_program).returns(programs(:albers))
    mentoring_model = mentoring_models(:mentoring_models_1)

    current_user_is :f_admin
    assert_difference "Group.count", 1 do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id_list: "#{users(:ram).id}", student_id: student.id, update_type: BulkMatch::UpdateType::PUBLISH, mentoring_model_id: mentoring_model.id, group_name: group_name, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    group = Group.last
    assert_equal group, assigns(:group)
    assert_equal Group::Status::ACTIVE, group.status
    assert_equal users(:f_admin), group.created_by
    assert_equal group_name, group.name
    assert_equal mentoring_model, group.mentoring_model
    assert_equal bulk_match, group.bulk_match
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_normal_request_publish_drafted_group
    bulk_match = bulk_matches(:bulk_match_1)
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.save!
    student = group.students.first

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id_list: "#{group.mentors.first.id}", student_id: student.id, update_type: BulkMatch::UpdateType::PUBLISH, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal Group::Status::ACTIVE, group.reload.status
    assert_equal bulk_match, group.bulk_match
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_draft_with_notes
    student = users(:rahim)
    bulk_match = bulk_matches(:bulk_match_1)
    assert bulk_match.request_notes

    current_user_is :f_admin
    assert_difference "Group.count", 1 do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id_list: "#{users(:ram).id}", student_id: student.id, update_type: BulkMatch::UpdateType::DRAFT, request_notes: "false", notes: "Test Notes", orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    group = Group.last
    assert_equal group, assigns(:group)
    assert_equal Group::Status::DRAFTED, group.status
    assert_equal users(:f_admin), group.created_by
    assert_equal bulk_match, group.bulk_match
    assert_equal "Test Notes", group.notes
    assert_equal false, bulk_match.reload.request_notes
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_draft_with_notes_mentor_to_mentee
    student = users(:rahim)
    bulk_match = programs(:albers).mentor_bulk_match
    assert bulk_match.request_notes

    current_user_is :f_admin
    assert_difference "Group.count", 1 do
      get :update_bulk_match_pair, xhr: true, params: { mentor_id: users(:ram).id, student_id_list: "#{student.id}", update_type: BulkMatch::UpdateType::DRAFT, request_notes: "false", notes: "Test Notes", orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    end
    assert_response :success
    group = Group.last
    assert_equal group, assigns(:group)
    assert_equal Group::Status::DRAFTED, group.status
    assert_equal users(:f_admin), group.created_by
    assert_equal bulk_match, group.bulk_match
    assert_equal "Test Notes", group.notes
    assert_equal false, bulk_match.reload.request_notes
    assert_equal( { error_flash: nil, object_id_group_id_map: { users(:ram).id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_publish_with_notes
    bulk_match = bulk_matches(:bulk_match_1)
    assert bulk_match.request_notes
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = bulk_match
    group.save!
    student = group.students.first

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      get :update_bulk_match_pair, xhr: true, params: { group_id: group.id, mentor_id_list: "#{group.mentors.first.id}", student_id: student.id, request_notes: "false", notes: "Test Notes", update_type: BulkMatch::UpdateType::PUBLISH, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal Group::Status::ACTIVE, group.reload.status
    assert_nil group.notes
    assert_equal false, bulk_match.reload.request_notes
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_publish_with_message
    bulk_match = bulk_matches(:bulk_match_1)
    assert bulk_match.request_notes
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = bulk_match
    group.save!
    student = group.students.first

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      get :update_bulk_match_pair, xhr: true, params: { group_id: group.id, mentor_id_list: "#{group.mentors.first.id}", student_id: group.students.first.id, request_notes: "false", message: "Test message", update_type: BulkMatch::UpdateType::PUBLISH, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    end
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal "Test message", assigns(:group).message
    assert_equal( { error_flash: nil, object_id_group_id_map: { student.id => group.id } }.to_json, @response.body)
  end

  def test_update_bulk_match_pair_publish_with_message_mentor_to_mentee
    bulk_match = programs(:albers).mentor_bulk_match
    assert bulk_match.request_notes
    group = groups(:mygroup)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = bulk_match
    group.save!
    student = group.students.first
    mentor = group.mentors.first

    current_user_is :f_admin
    assert_no_difference "Group.count" do
      get :update_bulk_match_pair, xhr: true, params: { group_id: group.id, mentor_id: group.mentors.first.id, student_id_list: "#{group.students.first.id}", request_notes: "false", message: "Test message", update_type: BulkMatch::UpdateType::PUBLISH, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    end
    assert_response :success
    assert_equal group, assigns(:group)
    assert_equal "Test message", assigns(:group).message
    assert_equal( { error_flash: nil, object_id_group_id_map: { mentor.id => group.id } }.to_json, @response.body)
  end

  def test_fetch_summary_details_non_admin
    # student_cache_normalized is used in this action for (admin=true). 
    current_user_is :f_mentor
    assert_permission_denied do
      get :fetch_summary_details, params: { mentor_id: users(:robert).id, student_id: users(:rahim).id}
    end
  end

  def test_fetch_summary_details
    admin = users(:f_admin)

    current_user_is admin
    get :fetch_summary_details, xhr: true, params: { mentor_id: users(:robert).id, student_id: users(:rahim).id, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_response :success
    assert_equal admin.program.match_configs.order("weight DESC"), assigns(:match_configs)
    assert_equal BulkMatch::OrientationType::MENTOR_TO_MENTEE, assigns(:orientation_type)
  end

  def test_fetch_summary_with_supplementary_question_creation
    admin = users(:f_admin)
    student_question_id = role_questions(:role_questions_15).id
    mentor_question_id = role_questions(:role_questions_16).id
    current_user_is admin
    assert_difference "SupplementaryMatchingPair.count", 1 do
      get :fetch_summary_details, xhr: true, params: { mentor_id: users(:robert).id, student_id: users(:rahim).id, add_supplementary_question: true, student_question_id: student_question_id, mentor_question_id: mentor_question_id}
    end
    assert_response :success
    supplementary_matching_pair = SupplementaryMatchingPair.last
    assert_equal student_question_id, supplementary_matching_pair.student_role_question_id
    assert_equal mentor_question_id, supplementary_matching_pair.mentor_role_question_id
  end

  def test_fetch_summary_with_supplementary_question_deletion
    admin = users(:f_admin)
    supplementary_matching_pair = create_supplementary_matching_question_pair

    current_user_is admin
    current_program_is supplementary_matching_pair.program

    assert_difference "SupplementaryMatchingPair.count", -1 do
      get :fetch_summary_details, xhr: true, params: { mentor_id: users(:robert).id, student_id: users(:rahim).id, delete_supplementary_question: true, question_pair_id: supplementary_matching_pair.id}
    end
    assert_response :success
    assert_false SupplementaryMatchingPair.exists?(supplementary_matching_pair.id)
  end

  def test_fetch_bulk_match_settings
    current_user_is :f_admin
    get :fetch_settings, xhr: true
    assert_response :success
    assert_equal bulk_matches(:bulk_match_1), assigns(:bulk_match)
    assert_equal BulkMatch::OrientationType::MENTEE_TO_MENTOR, assigns(:orientation_type)
  end

  def test_fetch_bulk_match_settings_for_mentor_to_mentee_view
    current_user_is :f_admin
    get :fetch_settings, xhr: true, params: {orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_response :success
    assert_equal bulk_matches(:bulk_match_2), assigns(:bulk_match)
    assert_equal BulkMatch::OrientationType::MENTOR_TO_MENTEE, assigns(:orientation_type)
  end

  def test_update_bulk_match_settings_update_sort_value
    bulk_match = bulk_matches(:bulk_match_1)
    assert_equal true, bulk_match.sort_order
    assert_nil bulk_match.sort_value

    current_user_is :f_admin
    get :update_settings, xhr: true, params: { sort: true, sort_value: "-selected_mentor", sort_order: false}
    assert_response :success
    assert_equal false, bulk_match.reload.sort_order
    assert_equal "-selected_mentor", bulk_match.sort_value
  end

  def test_update_bulk_match_settings_update_sort_value_for_mentor_to_mentee_view
    bulk_match = bulk_matches(:bulk_match_2)
    assert_equal true, bulk_match.sort_order
    assert_nil bulk_match.sort_value

    current_user_is :f_admin
    get :update_settings, xhr: true, params: { sort: true, sort_value: "-selected_mentor", sort_order: false, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_response :success
    assert_equal false, bulk_match.reload.sort_order
    assert_equal "-selected_mentor", bulk_match.sort_value
    assert_equal BulkMatch::OrientationType::MENTOR_TO_MENTEE, assigns(:orientation_type)
  end

  def test_update_bulk_match_settings_update_hiding_options
    bulk_match = bulk_matches(:bulk_match_1)
    assert_false bulk_match.show_drafted
    assert_false bulk_match.show_published
    assert bulk_match.request_notes
    @controller.expects(:compute_bulk_match_results).once

    current_user_is :f_admin
    get :update_settings, xhr: true, params: { bulk_match: { show_published: false, show_drafted: false, request_notes: false, max_pickable_slots: 2 }}
    assert_response :success
    assert_equal false, bulk_match.reload.show_drafted
    assert_equal false, bulk_match.show_published
    assert_equal false, bulk_match.request_notes
    assert assigns(:refresh_results)

    get :update_settings, xhr: true, params: { bulk_match: { show_published: false, show_drafted: false, request_notes: false, max_pickable_slots: 2 }}
    assert_response :success
    assert_equal false, assigns(:refresh_results)
  end

  def test_update_bulk_match_settings_update_hiding_options_for_mentor_to_mentee_view
    bulk_match = bulk_matches(:bulk_match_2)
    assert_false bulk_match.show_drafted
    assert_false bulk_match.show_published
    assert bulk_match.request_notes
    @controller.expects(:compute_bulk_match_results).once

    current_user_is :f_admin
    get :update_settings, xhr: true, params: { bulk_match: { show_published: true, show_drafted: true, request_notes: false}, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_response :success
    assert bulk_match.reload.show_drafted
    assert bulk_match.show_published
    assert_false bulk_match.request_notes  
  end

  def test_update_bulk_match_settings_update_pickable_slots
    bulk_match = bulk_matches(:bulk_match_1)
    bulk_match.max_pickable_slots = 4
    bulk_match.save!

    current_user_is :f_admin
    get :update_settings, xhr: true, params: { bulk_match: { show_published: false, show_drafted: false, request_notes: false, max_pickable_slots: "2" }}
    assert_response :success
    assert_equal false, bulk_match.reload.show_drafted
    assert_equal false, bulk_match.show_published
    assert_equal false, bulk_match.request_notes
    assert_equal 2, bulk_match.max_pickable_slots
    assert assigns(:refresh_results)
  end

  def test_preview_view_details
    admin_view = programs(:albers).admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)

    current_user_is :f_admin
    get :preview_view_details, xhr: true, params: { role: RoleConstants::MENTOR_NAME, admin_view_id: admin_view.id}
    assert_response :success
    assert_equal RoleConstants::MENTOR_NAME, assigns(:role)
    assert_equal admin_view, assigns(:admin_view)
    assert_equal 1, assigns(:admin_view_filters).keys.size
    assert_equal "Roles", assigns(:admin_view_filters).keys.first
    assert_equal "#{RoleConstants::MENTOR_NAME}".capitalize, assigns(:admin_view_filters).values.first
  end

  def test_fetch_notes
    group = groups(:mygroup)
    bulk_match = group.program.student_bulk_match
    student = group.students.first
    mentor = group.mentors.first
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.bulk_match = bulk_match
    group.save!

    current_user_is :f_admin
    get :fetch_notes, xhr: true, params: { mentor_id: mentor.id, student_id: student.id, group_id: group.id}
    assert_response :success
    assert_template "_bulk_match_notes_popup"
    assert_equal group, assigns(:group)
    assert_equal bulk_match, assigns(:bulk_match)
    assert_equal group.mentors.first, assigns(:mentor)
    assert_equal group.students.first, assigns(:student)
  end

  def test_fetch_notes_for_publish_bulk_action
    bulk_match = programs(:albers).student_bulk_match
    group = create_group(status: Group::Status::DRAFTED, created_by: users(:f_admin), bulk_match: bulk_match)
    student = group.students.first
    mentor = group.mentors.first

    current_user_is :f_admin
    get :fetch_notes, xhr: true, params: { bulk_action: true, action_type: BulkMatch::UpdateType::PUBLISH, group_ids: [group.id]}
    assert_response :success
    assert_template "_bulk_pairs_message_popup"
    assert_equal bulk_match, assigns(:bulk_match)
    assert_equal BulkMatch::UpdateType::PUBLISH, assigns(:action_type)
    assert_equal [group.id], assigns(:drafted_group_ids)
  end

  def test_fetch_notes_for_draft_bulk_action
    student = users(:student_9)
    mentor = users(:mentor_9)

    current_user_is :f_admin
    assert_permission_denied do
      get :fetch_notes, xhr: true, params: { bulk_action: true, action_type: BulkMatch::UpdateType::DRAFT, student_mentor_map: { student.id => [mentor.id] }}
    end
  end

  def test_update_notes
    admin = users(:f_admin)
    group = groups(:mygroup)
    bulk_match = group.program.student_bulk_match
    group.status = Group::Status::DRAFTED
    group.created_by = admin
    group.bulk_match = bulk_match
    group.save!
    assert_nil group.notes

    current_user_is admin
    get :update_notes, xhr: true, params: { group_id: group.id, notes: "Test Notes"}
    assert_response :success
    assert_equal bulk_match, assigns(:bulk_match)
    assert_equal group.reload, assigns(:group)
    assert_equal "Test Notes", group.notes
  end

  def test_export_csv_non_admin
    current_user_is :f_mentor
    assert_permission_denied do
      post :export_csv
    end
  end

  def test_export_csv_admin
    set_mentor_cache(users(:mkr_student).id, users(:f_mentor).id, 0.0)
    bulk_match = bulk_matches(:bulk_match_1)
    group = groups(:mygroup)
    group.bulk_match = bulk_matches(:bulk_match_1)
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.published_at = nil
    group.save!
    active_pending_ids = bulk_match.program.all_users.select('id, state').active_or_pending.collect(&:id)
    @controller.stubs(:get_user_ids).with(bulk_match.mentee_view, false).returns(active_pending_ids)
    @controller.stubs(:get_user_ids).with(bulk_match.mentor_view, true).returns(active_pending_ids)

    student = bulk_match.program.student_users.first
    mentor = bulk_match.program.mentor_users.first
    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.drafted".translate, group.id)

    current_user_is :f_admin
    post :export_csv, params: {students: students, mentors: mentors}
    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_equal "#{group.students.first.name},#{group.mentors.first.name},90,Drafted,#{group.created_at.strftime("%d-%b-%Y")},,,0", csv_response[1]
    assert_match /Bulk match drafted mentoring connections/, @response.header["Content-Disposition"]
    assert_equal active_pending_ids, assigns(:student_user_ids)
    assert_equal active_pending_ids, assigns(:mentor_user_ids)
  end

  def test_export_csv_admin_mentor_to_mentee
    set_mentor_cache(users(:mkr_student).id, users(:f_mentor).id, 0.0)
    bulk_match = programs(:albers).mentor_bulk_match
    group = groups(:mygroup)
    group.bulk_match = bulk_match
    group.status = Group::Status::DRAFTED
    group.created_by = users(:f_admin)
    group.published_at = nil
    group.save!
    active_pending_ids = bulk_match.program.all_users.select('id, state').active_or_pending.collect(&:id)
    @controller.stubs(:get_user_ids).with(bulk_match.mentee_view, false).returns(active_pending_ids)
    @controller.stubs(:get_user_ids).with(bulk_match.mentor_view, true).returns(active_pending_ids)

    student = bulk_match.program.student_users.first
    mentor = bulk_match.program.mentor_users.first
    students, mentors = get_student_and_mentor_hash_for_mentor_to_mentee(student, mentor, "feature.bulk_match.js_message.drafted".translate, group.id)

    current_user_is :f_admin
    post :export_csv, params: {students: students, mentors: mentors, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_response :success
    csv_response = @response.body.split("\n")
    assert_equal active_pending_ids, assigns(:student_user_ids)
    assert_equal active_pending_ids, assigns(:mentor_user_ids)
    assert_match "Mentor Name,Student Name,Match %,Available Slots,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_equal "#{group.mentors.first.name},#{group.students.first.name},90,1,Drafted,#{group.created_at.strftime("%d-%b-%Y")},,,0", csv_response[1]
    assert_match /Bulk match drafted mentoring connections/, @response.header["Content-Disposition"]
  end

  def test_alter_pickable_slots_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :alter_pickable_slots, xhr: true, params: { mentor_id: users(:f_mentor).id, student_id: users(:f_student).id}
    end
  end

  def test_alter_pickable_slots
    current_user_is :f_admin
    get :alter_pickable_slots, xhr: true, params: { mentor_id: users(:f_mentor).id, student_id: users(:f_student).id}
    assert_response :success
    assert_equal programs(:albers).student_bulk_match, assigns(:bulk_match)
    assert_equal users(:f_mentor), assigns(:mentor)
    assert_equal users(:f_student), assigns(:student)
  end

  def test_refresh_results_permission_denied
    current_user_is :f_mentor
    assert_permission_denied do
      get :refresh_results, xhr: true
    end
  end

  def test_refresh_results
    current_user_is :f_admin
    get :refresh_results, xhr: true
    assert_response :success
    assert_equal bulk_matches(:bulk_match_1), assigns(:bulk_match)
  end

  def test_refresh_results_for_mentor_to_mentee_view
    current_user_is :f_admin
    get :refresh_results, xhr: true, params: {orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_response :success
    assert_equal bulk_matches(:bulk_match_2), assigns(:bulk_match)
  end

  def test_get_best_match_mentor_id_for_mentor_12_with_one_time_mentoring_mode
    program = programs(:albers)
    # setting consider_mentoring_mode? true for program
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    student_view = program.admin_views.create!(title: "Students", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::STUDENT_NAME] }, state: { active: User::Status::ACTIVE } } }.to_yaml)
    mentor_view = program.admin_views.create!(title: "Mentors", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::MENTOR_NAME] }, state: { active: User::Status::ACTIVE } } }.to_yaml)
    #changing mentoring mode of mentor to one time
    users(:mentor_12).update_attribute(:mentoring_mode, User::MentoringMode::ONE_TIME)

    current_user_is :f_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, type: BulkMatch.name, format: :js}
    assert_false (assigns(:selected_mentors).values).include?(users(:mentor_12).id)
  end

  def test_get_best_match_mentor_id_for_mentor_12_without_one_time_mentoring_mode
    program = programs(:albers)
    # setting consider_mentoring_mode? true for program
    program.enable_feature(FeatureName::CALENDAR)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    student_view = program.admin_views.create!(title: "Students", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::STUDENT_NAME] }, state: { active: User::Status::ACTIVE } } }.to_yaml)
    mentor_view = program.admin_views.create!(title: "Mentors", filter_params: { roles_and_status: { role_filter_1: { type: :include, roles: [RoleConstants::MENTOR_NAME] }, state: { active: User::Status::ACTIVE } } }.to_yaml)

    current_user_is :f_admin
    get :bulk_match, xhr: true, params: { mentor_view_id: mentor_view.id, mentee_view_id: student_view.id, type: BulkMatch.name, format: :js}
    assert (assigns(:selected_mentors).values).include?([users(:mentor_12).id])
  end

  def test_bulk_match_not_accessible_for_program_with_disabled_ongoing_mentoring
    # changing engagement type of program to career based
    programs(:albers).update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)

    # for ongoing mentoring disabled program none of the action of bulk match will be acessible, testing for one here
    current_user_is :f_admin
    assert_permission_denied do
      get :bulk_match
    end
  end

  def test_change_match_orientation_towards_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTOR_TO_MENTEE_MATCHING)
    set_default(bulk_matches(:bulk_match_1), 0)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    mentor_bulk_match = program.mentor_bulk_match
    assert_equal 0, mentor_bulk_match.default

    current_user_is :f_admin
    get :change_match_orientation, xhr: true, params: { type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    assert_equal mentor_bulk_match, assigns(:bulk_match)
    assert_equal mentor_view, assigns(:mentor_view)
    assert_equal student_view, assigns(:mentee_view)
    assert_equal 1, mentor_bulk_match.reload.default
    assert_equal "Step 2: Assign Matches", assigns(:step_2_tab_title)
  end

  def test_change_match_orientation_towards_mentee
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTOR_TO_MENTEE_MATCHING)
    set_default(bulk_matches(:bulk_match_1), 0)
    mentor_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTORS)
    student_view = program.admin_views.default.find_by(default_view: AbstractView::DefaultType::MENTEES)
    student_bulk_match = program.student_bulk_match
    assert_equal 0, student_bulk_match.default

    current_user_is :f_admin
    get :change_match_orientation, xhr: true, params: { type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    assert_equal student_bulk_match, assigns(:bulk_match)
    assert_equal mentor_view, assigns(:mentor_view)
    assert_equal student_view, assigns(:mentee_view)
    assert_equal 1, student_bulk_match.reload.default
    assert_equal "Step 2: Assign Matches", assigns(:step_2_tab_title)
  end

  def test_groups_alert_permission_denied
    current_user_is :f_admin
    assert_permission_denied do
      get :groups_alert, xhr: true, params: { student_id: users(:mkr_student).id, mentor_id_list: users(:f_mentor).id, update_type: BulkMatch::UpdateType::PUBLISH}
    end
  end

  def test_groups_alert_empty
    current_user_is :f_admin
    get :groups_alert, xhr: true, params: { student_id: users(:mkr_student).id, mentor_id_list: users(:f_mentor).id, update_type: BulkMatch::UpdateType::DRAFT}
    assert_response :success
    assert_equal [[[users(:mkr_student).id], [users(:f_mentor).id]]], assigns(:student_id_mentor_id_sets)
    assert_equal( { groups_alert: "" }.to_json, @response.body)
  end

  def test_groups_alert_individual_action
    group = groups(:mygroup)
    group.update_attributes!(bulk_match: programs(:albers).student_bulk_match)
    student = group.students.first
    mentor = group.mentors.first

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is :f_admin
    get :groups_alert, xhr: true, params: { student_id: student.id, mentor_id_list: mentor.id, update_type: BulkMatch::UpdateType::DRAFT}
    assert_response :success
    assert_equal [[[student.id], [mentor.id]]], assigns(:student_id_mentor_id_sets)
    assert_match /#{mentor.name} is a mentor to #{student.name} in.*#{h group.name}/, JSON.parse(@response.body)["groups_alert"]
  end

  def test_export_all_pairs_selected
    program = programs(:albers)
    student = program.student_users.first
    mentor = program.mentor_users.first
    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.selected".translate, nil)
    current_user_is :f_admin

    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_match "#{student.name(name_only: true)},#{mentor.name(name_only: true)},90,Selected,,,,#{mentor.groups.active.count}", csv_response[1]
  end

  def test_export_all_pairs_selected_with_unmatched_data
    program = programs(:albers)
    student = users(:robert)
    mentor = users(:f_mentor)
    profile_questions = [profile_questions(:profile_questions_3), profile_questions(:single_choice_q)]
    student_question_ids = profile_questions.collect(&:id)
    mentor_question_ids = profile_questions.collect(&:id)
    headers = "||,Student ans-question1,Mentor ans-question1,||,Student ans-question2,Mentor ans-question2".split(",")

    BulkMatch.any_instance.stubs(:populate_match_config_header).returns([headers, mentor_question_ids, student_question_ids])

    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.unmatched_v1".translate, nil, true)
    current_user_is :f_admin

    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil}

    assert_response :success
    csv_response = @response.body.split("\n")

    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor,||,Student ans-question1,Mentor ans-question1,||,Student ans-question2,Mentor ans-question2", csv_response[0]
    assert_equal "robert user,,,Unmatched,,,,,||,\"New Delhi, Delhi, India\",\"\",||,opt_3,\"\"", csv_response[1]
  end

  def test_export_all_pairs_recommendation
    program = programs(:albers)
    student = program.student_users.first
    mentor = program.mentor_users.first
    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.selected".translate, nil)
    current_user_is :f_admin

    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: true}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Student Name,Mentor Name,Match %,Recommendation preference,Status,Ongoing mentoring connections of the mentor,Number of times recommended", csv_response[0]
    assert_match "#{student.name(name_only: true)},#{mentor.name(name_only: true)},90,1,Selected,#{mentor.groups.active.count},1", csv_response[1]
  end

  def test_export_all_pairs_recommendation_with_unmatched_data
    program = programs(:albers)
    student = users(:robert)
    mentor = users(:f_mentor)
    profile_questions = [profile_questions(:profile_questions_3), profile_questions(:single_choice_q)]
    student_question_ids = profile_questions.collect(&:id)
    mentor_question_ids = profile_questions.collect(&:id)
    headers = "||,Student ans-question1,Mentor ans-question1,||,Student ans-question2,Mentor ans-question2".split(",")

    BulkMatch.any_instance.stubs(:populate_match_config_header).returns([headers, mentor_question_ids, student_question_ids])

    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.unmatched_v1".translate, nil, true)
    current_user_is :f_admin

    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: true}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Student Name,Mentor Name,Match %,Recommendation preference,Status,Ongoing mentoring connections of the mentor,Number of times recommended,||,Student ans-question1,Mentor ans-question1,||,Student ans-question2,Mentor ans-question2", csv_response[0]
    assert_equal "robert user,,,,Unmatched,,,||,\"New Delhi, Delhi, India\",\"\",||,opt_3,\"\"", csv_response[1]
  end

  def test_export_all_pairs_drafted
    program = programs(:albers)
    student = program.student_users.first
    mentor = program.mentor_users.first
    current_user_is :f_admin

    group = create_group(students: [student], mentor: mentor, program: program, status: Group::Status::DRAFTED, created_by: users(:f_admin))
    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.drafted".translate, group.id)
    
    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_match "#{student.name(name_only: true)},#{mentor.name(name_only: true)},90,Drafted,#{DateTime.localize(group.created_at, format: :default_dashed)},,,#{mentor.groups.active.count}", csv_response[1]

    group.notes = "New Note"
    group.save!

    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "#{student.name(name_only: true)},#{mentor.name(name_only: true)},90,Drafted,#{DateTime.localize(group.created_at, format: :default_dashed)},New Note,,#{mentor.groups.active.count}", csv_response[1]

  end

  def test_export_all_pairs_drafted_mentor_to_mentee
    program = programs(:albers)
    student = program.student_users.first
    mentor = program.mentor_users.first
    current_user_is :f_admin

    group = create_group(students: [student], mentor: mentor, program: program, status: Group::Status::DRAFTED, created_by: users(:f_admin))
    students, mentors = get_student_and_mentor_hash_for_mentor_to_mentee(student, mentor, "feature.bulk_match.js_message.drafted".translate, group.id)
    
    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Mentor Name,Student Name,Match %,Available Slots,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_match "#{mentor.name(name_only: true)},#{student.name(name_only: true)},90,1,Drafted,#{DateTime.localize(group.created_at, format: :default_dashed)},,,#{mentor.groups.active.count}", csv_response[1]

    group.notes = "New Note"
    group.save!

    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "#{mentor.name(name_only: true)},#{student.name(name_only: true)},90,1,Drafted,#{DateTime.localize(group.created_at, format: :default_dashed)},New Note,,#{mentor.groups.active.count}", csv_response[1]

  end

  def test_export_all_pairs_published
    program = programs(:albers)
    student = program.student_users.first
    mentor = program.mentor_users.first
    current_user_is :f_admin

    group = create_group(students: [student], mentor: mentor, program: program)
    students, mentors = get_student_and_mentor_hash(student, mentor, "feature.bulk_match.js_message.published".translate, group.id)
    
    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Student Name,Mentor Name,Match %,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_match "#{student.name(name_only: true)},#{mentor.name(name_only: true)},90,Published,#{DateTime.localize(group.created_at, format: :default_dashed)},,#{DateTime.localize(group.published_at, format: :default_dashed)},#{mentor.groups.active.count}", csv_response[1]
  end

  def test_export_all_pairs_published_mentor_to_mentee
    program = programs(:albers)
    student = program.student_users.first
    mentor = program.mentor_users.first
    current_user_is :f_admin

    group = create_group(students: [student], mentor: mentor, program: program)
    students, mentors = get_student_and_mentor_hash_for_mentor_to_mentee(student, mentor, "feature.bulk_match.js_message.published".translate, group.id)
    
    post :export_all_pairs, xhr: true, params: { students: students, mentors: mentors, recommendation: nil, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}

    assert_response :success
    csv_response = @response.body.split("\n")
    assert_match "Mentor Name,Student Name,Match %,Available Slots,Status,Drafted Date,Note Added,Published Date,Ongoing mentoring connections of the mentor", csv_response[0]
    assert_match "#{mentor.name(name_only: true)},#{student.name(name_only: true)},90,1,Published,#{DateTime.localize(group.created_at, format: :default_dashed)},,#{DateTime.localize(group.published_at, format: :default_dashed)},#{mentor.groups.active.count}", csv_response[1]
  end

  def test_groups_alert_bulk_action
    group = groups(:mygroup)
    student = group.students.first
    mentor = group.mentors.first

    Program.any_instance.stubs(:show_existing_groups_alert?).returns(true)
    current_user_is :f_admin
    get :groups_alert, xhr: true, params: { bulk_action: true, student_mentor_map: { student.id => [mentor.id] }, update_type: BulkMatch::UpdateType::DRAFT}
    assert_response :success
    groups_alert = JSON.parse(@response.body)["groups_alert"]
    assert_equal [[[student.id], [mentor.id]]], assigns(:student_id_mentor_id_sets)
    assert_match /The selected users are already connected with each other in the following mentoring connections./, groups_alert
    assert_match /#{mentor.name} is a mentor to #{student.name} in.*#{h group.name}/, groups_alert
  end

  private

  def set_default(bulk_record, value = 1)
    bulk_record.default = value
    bulk_record.save!
  end

  def set_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    set_mentor_cache(s1_id, m1_id, 0.6)
    set_mentor_cache(s1_id, m2_id, 0.1)
    unless s2_id.nil?
      set_mentor_cache(s2_id, m1_id, 0.4)
      set_mentor_cache(s2_id, m2_id, 0.2)
    end
    program.match_setting.update_attributes!({min_match_score: 0.1, max_match_score: 0.6})
  end

  def get_student_and_mentor_hash(student, mentor, status, group_id, unmatched = false)
    [%Q[[{"id":#{student.id},"group_status":"#{status}","group_id":#{group_id.to_i},"selected_mentors":[#{mentor.id unless unmatched}]}]], %Q[[{"id":#{mentor.id}, "connections_count":#{mentor.groups.active.count}, "recommended_count": 1}]]]
  end

  def get_student_and_mentor_hash_for_mentor_to_mentee(student, mentor, status, group_id, unmatched = false)
    [%Q[[{"id":#{student.id}}]], %Q[[{"pickable_slots":1, "id":#{mentor.id}, "connections_count":#{mentor.groups.active.count}, "recommended_count": 1,"group_status":"#{status}","group_id":#{group_id.to_i},"selected_students":[#{student.id unless unmatched}]}]]]
  end

  def reset_cache_values(program, s1_id, s2_id, m1_id, m2_id)
    set_mentor_cache(s1_id, m1_id, 0.0)
    set_mentor_cache(s1_id, m2_id, 0.0)
    unless s2_id.nil?
      set_mentor_cache(s2_id, m1_id, 0.0)
      set_mentor_cache(s2_id, m2_id, 0.0)
    end
    program.match_setting.update_attributes!({min_match_score: 0.0, max_match_score: 0.0})
  end
end