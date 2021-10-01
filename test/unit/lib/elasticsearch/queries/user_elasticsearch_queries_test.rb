require_relative './../../../../test_helper'

class UserElasticsearchQueriesTest < ActiveSupport::TestCase

  def test_get_filtered_users
    users = users(:psg_mentor, :ceg_mentor, :requestable_mentor, :nch_mentor, :f_mentor_student, :moderated_mentor, :no_mreq_mentor, :no_mreq_admin, :not_requestable_mentor, :inactive_user, :no_mreq_student)
    assert_equal_unordered users.map(&:id), User.get_filtered_users("mentor", match_fields: ["name_only", "email"]).to_a.map(&:id)

    users = users(:not_requestable_mentor, :requestable_mentor, :f_mentor_student)
    assert_equal_unordered users.map(&:id), User.get_filtered_users("mentor", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }).to_a.map(&:id)

    assert_empty User.get_filtered_users("mentor", match_fields: ["name_only", "email"], with: { organization_id: programs(:ceg).id }, without: {"member.state": Member::Status::SUSPENDED}).to_a.map(&:id)

    assert_equal_unordered [users(:ceg_mentor).id], User.get_filtered_users("mentor", match_fields: ["name_only", "email"], with: { program_id: programs(:ceg).id }, without: {"member.state": Member::Status::SUSPENDED}, source_columns: [:id]).to_a

    users = users(:not_requestable_mentor, :requestable_mentor, :f_mentor_student)
    assert_equal_unordered users.map { |user| ["#{user.id}", user.name] } , User.get_filtered_users("mentor", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, source_columns: [:id, :name_only]).to_a.map{|user| [user.id, user.name_only]}

    users = users(:f_mentor_nwen_student, :f_onetime_mode_mentor, :portal_employee, :f_mentor_pbe, :f_mentor, :no_mreq_mentor)
    assert_equal_unordered users.map(&:id), User.get_filtered_users(nil, geo: {point: [80.2496, 13.0604], distance: "1km", field: "member.location_answer.location.point"}).to_a.map(&:id) # 1km from Chennai

    users = users(:f_mentor_nwen_student, :f_onetime_mode_mentor, :robert, :portal_employee, :f_mentor_pbe, :f_mentor, :inactive_user, :no_mreq_student, :no_mreq_mentor)
    assert_equal_unordered users.map(&:id), User.get_filtered_users(nil, geo: {point: [80.2496, 13.0604], distance: "2000km", field: "member.location_answer.location.point"}).to_a.map(&:id) # 2000km from Chennai. Includes New Delhi

    users = users(:f_mentor_student, :not_requestable_mentor, :requestable_mentor)
    assert_equal users.map(&:id), User.get_filtered_users("mentor", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }, sort_field: "email.sort", sort_order: "asc").to_a.map(&:id)

    users = users(:requestable_mentor, :moderated_mentor)
    assert_equal users.map(&:id), User.get_filtered_users("mentor", match_fields: ["name_only", "email"], sort_field: "id", sort_order: "asc", per_page: 2, page: 2).to_a.map(&:id)

    users = users(:f_mentor, :mentor_1, :mentor_3)
    member1 = members(:mentor_1)
    member2 = members(:f_mentor)
    member1.update_attributes!(first_name: "boys")
    member2.update_attributes!(first_name: "boys")
    reindex_documents(updated: member1.users + member2.users)
    assert_equal users.map(&:id), User.get_filtered_users("boys", with: { program_id: "6" }, per_page: 3, sort_field: "_score", sort_order: "desc", fields: ["name_only", "profile_answer_text.language_*"], boost_hash: { "name_only" => 0.7, "profile_answer_text.language_*" => 0.3 }, apply_boost: true).to_a.map(&:id)

    qc1 = question_choices(:single_choice_q_1)
    explicit_preference = QueryHelper::Filter.simple_bool_should([{constant_score: {filter: {terms: {profile_answer_choices: [qc1.id]}}, boost: 3}}])
    member_ids = ProfileAnswer.where(id: qc1.answer_choices.where(ref_obj_type: 'ProfileAnswer').pluck(:ref_obj_id), ref_obj_type: 'Member').pluck(:ref_obj_id).uniq
    user_ids1 = User.get_filtered_users(nil, with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, source_columns: [:id])
    user_ids2 = User.get_filtered_users(nil, with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, explicit_preference: explicit_preference, source_columns: [:id])
    assert_equal [users(:f_mentor)].collect(&:id), user_ids2
    assert_equal_unordered user_ids1 & user_ids2, user_ids2
    assert_equal_unordered member_ids, User.where(id: user_ids2).pluck(:member_id)

    qc2 = question_choices(:single_choice_q_3)
    explicit_preference = QueryHelper::Filter.simple_bool_should([{constant_score: {filter: {terms: {profile_answer_choices: [qc1.id]}}, boost: 3}}, {constant_score: {filter: {terms: {profile_answer_choices: [qc2.id]}}, boost: 1}}])
    user_ids3 = User.get_filtered_users(nil, with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, explicit_preference: explicit_preference, source_columns: [:id])
    assert_equal users(:f_mentor, :robert).collect(&:id), user_ids3
    assert_equal_unordered user_ids1 & user_ids3, user_ids3

    assert_equal [3.0, 1.0], User.get_filtered_users(nil, with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, explicit_preference: explicit_preference).response.map{|h| h['_score']}

    users = users(:robert, :f_mentor)
    assert_equal users.collect(&:id), User.get_filtered_users("robert", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, source_columns: [:id])
    assert_equal users.collect(&:id), User.get_filtered_users("robert", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, explicit_preference: explicit_preference, source_columns: [:id])

    assert_equal users.reverse.collect(&:id), User.get_filtered_users("robert", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, explicit_preference: explicit_preference, sort_by_explicit_preference: true, source_columns: [:id])
    explicit_preference = QueryHelper::Filter.simple_bool_should([{constant_score: {filter: {terms: {profile_answer_choices: [qc1.id]}}, boost: 3}}])
    assert_equal [users(:f_mentor)].collect(&:id), User.get_filtered_users("robert", match_fields: ["name_only", "email"], with: { program_id: programs(:albers).id }, without: {"member.state": Member::Status::SUSPENDED}, explicit_preference: explicit_preference, source_columns: [:id])
  end

  def test_get_availability_slots_for
    program = programs(:albers)
    mentors = program.mentor_users
    hsh = User.get_availability_slots_for(mentors.map(&:id))
    mentors.each do |mentor|
      assert_equal hsh[mentor.id], mentor.slots_available
    end
  end

  def test_get_ids_of_users_active_between
    nested_es_query_mock = mock
    NestedEsQuery::ActiveUsers.expects(:new).once.with("program", "start_time", "end_time", options: "options").returns(nested_es_query_mock)
    nested_es_query_mock.expects(:get_filtered_ids).once.returns("filtered_user_ids")
    assert_equal "filtered_user_ids", User.get_ids_of_users_active_between("program", "start_time", "end_time", options: "options")
  end

  def test_get_ids_of_connected_users_active_between
    nested_es_query_mock = mock
    NestedEsQuery::ActiveConnectedUsers.expects(:new).once.with("program", "start_time", "end_time", options: "options").returns(nested_es_query_mock)
    nested_es_query_mock.expects(:get_filtered_ids).once.returns("filtered_user_ids")
    assert_equal "filtered_user_ids", User.get_ids_of_connected_users_active_between("program", "start_time", "end_time", options: "options")
  end

  def test_get_ids_of_new_active_users
    nested_es_query_mock = mock
    NestedEsQuery::NewRoleStateUsers.expects(:new).once.with("program", "start_time", "end_time", options: "options", include_new_role_users: true).returns(nested_es_query_mock)
    nested_es_query_mock.expects(:get_filtered_ids).once.returns("filtered_user_ids")
    assert_equal "filtered_user_ids", User.get_ids_of_new_active_users("program", "start_time", "end_time", options: "options")
  end

  def test_get_ids_of_new_suspended_users
    nested_es_query_mock = mock
    NestedEsQuery::NewRoleStateUsers.expects(:new).once.with("program", "start_time", "end_time", options: "options", user_status: User::Status::SUSPENDED).returns(nested_es_query_mock)
    nested_es_query_mock.expects(:get_filtered_ids).once.returns("filtered_user_ids")
    assert_equal "filtered_user_ids", User.get_ids_of_new_suspended_users("program", "start_time", "end_time", options: "options")
  end

  def test_search_within_program
    primary_org_search = User.get_filtered_objects(must_filters: {'member.organization_id': programs(:org_primary).id}).records
    assert primary_org_search.include?(users(:rahim))
    assert primary_org_search.include?(users(:moderated_student))
    assert_false primary_org_search.include?(users(:foster_mentor7))
    assert User.get_filtered_objects(must_filters: {'member.organization_id': programs(:org_foster).id}).records.include?(users(:foster_mentor7))
  end

  # Education, experience and publication should be searched.
  def test_search_will_not_include_education_and_experience_and_publication
    program_id = programs(:albers).id
    users = User.get_filtered_objects(search_conditions: { search_text: "lead developer mechanical", fields: UserElasticsearchQueries::MATCH_FIELDS }, must_filters: { program_id: program_id } ).records
    assert_equal_unordered [users(:f_mentor).id], users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "lead", fields: UserElasticsearchQueries::MATCH_FIELDS }, must_filters: { program_id: program_id }).records
    assert_equal_unordered users(:f_mentor, :mentor_3).map(&:id), users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "American school", fields: UserElasticsearchQueries::MATCH_FIELDS }, must_filters: { program_id: program_id } ).records
    assert_equal_unordered users(:f_mentor, :mentor_3).map(&:id), users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "Indian", fields: UserElasticsearchQueries::MATCH_FIELDS }, must_filters: { program_id: program_id } ).records
    assert_equal [users(:f_mentor).id], users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "indian mechanical", fields: UserElasticsearchQueries::MATCH_FIELDS, operator: "OR" }, must_filters: { program_id: program_id } ).records
    assert_equal_unordered users(:f_mentor, :mentor_3).map(&:id), users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "Publication", fields: UserElasticsearchQueries::MATCH_FIELDS }, must_filters: { program_id: program_id } ).records
    assert_equal_unordered users(:f_mentor, :mentor_3).map(&:id), users.map(&:id)
  end

  def test_sort_for_created_at
    users = User.get_filtered_objects(sort: { created_at: "asc" } )
    assert users.index(users(:ram)) < users.index(users(:rahim))
  end

  def test_search_includes_location
    # rahim, f_mentor_student and mkr_student belong to delhi
    users = User.get_filtered_objects(search_conditions: { search_text: "delhi", fields: UserElasticsearchQueries::MATCH_FIELDS } ).records
    assert_equal_unordered users(:robert, :inactive_user, :no_mreq_student).map(&:id), users.map(&:id)

    # sarat mentor last name is chennai
    chennai_users = users(:f_mentor, :f_mentor_pbe, :sarat_mentor_ceg, :f_mentor_nwen_student, :f_onetime_mode_mentor, :no_mreq_mentor, :portal_employee)
    users = User.get_filtered_objects(search_conditions: { search_text: "chennai", fields: UserElasticsearchQueries::MATCH_FIELDS } ).records
    assert_equal_unordered chennai_users.map(&:id).sort, users.map(&:id).sort
  end

  def test_search_role_filter
    program = programs(:albers)
    mentor_role = roles("#{program.id}_#{RoleConstants::MENTOR_NAME}")
    student_role = roles("#{program.id}_#{RoleConstants::STUDENT_NAME}")
    assert_equal_unordered program.mentor_users.map(&:id), User.get_filtered_objects(per_page: 1000000, must_filters: { "roles.id" => mentor_role.id } ).map(&:id)
    assert_equal_unordered program.student_users.map(&:id), User.get_filtered_objects(per_page: 1000000, must_filters: { "roles.id" => student_role.id } ).map(&:id)
  end

  def test_search_should_not_return_suspended_users
    users = User.get_filtered_objects(search_conditions: { search_text: "delhi", fields: UserElasticsearchQueries::MATCH_FIELDS } ).records
    assert_equal_unordered users(:robert, :inactive_user, :no_mreq_student).map(&:id), users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "delhi", fields: UserElasticsearchQueries::MATCH_FIELDS }, must_filters: { state: User::Status::ACTIVE } ).records
    assert_equal_unordered users(:robert, :no_mreq_student).map(&:id), users.map(&:id)
  end

  def test_search_should_not_include_answers_for_private_questions
    users = User.get_filtered_objects(search_conditions: { search_text: "Bike race", fields: UserElasticsearchQueries::MATCH_FIELDS } ).records
    assert_equal_unordered [users(:mentor_3).id], users.map(&:id)

    users = User.get_filtered_objects(search_conditions: { search_text: "ooty", fields: UserElasticsearchQueries::MATCH_FIELDS } ).records
    assert_false users.include?([users(:f_mentor)])
  end

  def test_search_results_admins_as_well
    # ram is not just admin. He is a mentor too.
    users = User.get_filtered_objects.records
    assert users.include?(users(:ram))
    assert users.include?(users(:f_admin))
  end

  def test_search_should_not_include_busy_mentors
    mentor_role_id = roles("#{programs(:albers).id}_#{RoleConstants::MENTOR_NAME}").id
    results = User.get_filtered_objects(must_filters: { can_accept_request: true, "roles.id" => mentor_role_id } )
    assert results.include?(users(:mentor_3))
    assert results.include?(users(:requestable_mentor))
    assert_false results.include?(users(:not_requestable_mentor))
    assert_equal users(:requestable_mentor).max_connections_limit, users(:requestable_mentor).students(:all).size
    assert_equal_unordered users(:f_mentor, :not_requestable_mentor, :robert).map(&:id), User.get_filtered_objects(per_page: 1000, must_filters: { can_accept_request: false, "roles.id" => mentor_role_id } ).map(&:id)
  end

  def test_search_with_never_connected_user
    student_role_id = roles("#{programs(:albers).id}_#{RoleConstants::STUDENT_NAME}").id
    results = User.get_filtered_objects(per_page: 1000, must_filters: { total_user_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } )
    # for active connection
    assert results.include?(users(:mkr_student)), "results should include user with connections"
    assert_false results.include?(users(:f_student)), "results should not include user without connections"
    # for closed connection
    assert results.include?(users(:student_4)), "results should include user with only closed connections"
    # for drafted connection
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { total_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } )
    # for active connection
    assert_false results.include?(users(:mkr_student)), "results should not include user with connections"
    assert results.include?(users(:f_student)), "results should include user without connections"
    # for closed connection
    assert_false results.include?(users(:student_4)), "results should not include user with only closed connections"
    # for drafted connection
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"
  end

  def test_search_with_is_connected_user
    student_role_id = roles("#{programs(:albers).id}_#{RoleConstants::STUDENT_NAME}").id
    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_user_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } )
    # for active connection
    assert results.include?(users(:mkr_student)), "results should include user with connections"
    # for no connections
    assert_false results.include?(users(:f_student)), "results should not include user without connections"
    # for closed connection
    assert_false results.include?(users(:student_4)), "results should not include user with only closed connections"
    # for drafted connection
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } )
    # for active connection
    assert_false results.include?(users(:mkr_student)), "results should not include user with connections"
    # for no connections
    assert results.include?(users(:f_student)), "results should include user without connections"
    # for closed connection
    assert results.include?(users(:student_4)), "results should include user with only closed connections"
    # for drafted connection
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"

    # checking based on closed connections counts
    assert User.get_filtered_objects(per_page: 1000, must_filters: { closed_user_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } ).include?(users(:student_4)), "results should include user with closed connections"
    assert_false User.get_filtered_objects(per_page: 1000, must_filters: { closed_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } ).include?(users(:student_4)), "results should not include user with closed connections"
  end

  def test_search_with_never_connected_mentee
    student_role_id = roles("#{programs(:albers).id}_#{RoleConstants::STUDENT_NAME}").id
    results = User.get_filtered_objects(per_page: 1000, must_filters: { total_mentee_connections_count: 1..Float::INFINITY, "roles.id" => student_role_id } )
    # for active connection
    assert results.include?(users(:mkr_student)), "results should include user with connections"
    assert_false results.include?(users(:f_student)), "results should not include user without connections"
    # for closed connection
    assert results.include?(users(:student_4)), "results should include user with only closed connections"
    # for drafted connection
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { total_mentee_connections_count: 0, "roles.id" => student_role_id } )
    # for active connection
    assert_false results.include?(users(:mkr_student)), "results should not include user with connections"
    assert results.include?(users(:f_student)), "results should include user without connections"
    # for closed connection
    assert_false results.include?(users(:student_4)), "results should not include user with only closed connections"
    # for drafted connection
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"
  end

  def test_search_with_is_connected_mentee
    student_role_id = roles("#{programs(:albers).id}_#{RoleConstants::STUDENT_NAME}").id
    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_mentee_connections_count: 1..Float::INFINITY, "roles.id" => student_role_id } )
    # for active connection
    assert results.include?(users(:mkr_student)), "results should include user with connections"
    assert_false results.include?(users(:f_student)), "results should not include user without connections"
    # for closed connection
    assert_false results.include?(users(:student_4)), "results should not include user with only closed connections"
    # for drafted connection
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_mentee_connections_count: 0, "roles.id" => student_role_id } )
    # for active connection
    assert_false results.include?(users(:mkr_student)), "results should not include user with connections"
    assert results.include?(users(:f_student)), "results should include user without connections"
    # for closed connection
    assert results.include?(users(:student_4)), "results should include user with only closed connections"
    # for drafted connection
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"
  end

  def test_search_with_has_draft_connections
    student_role_id = roles("#{programs(:albers).id}_#{RoleConstants::STUDENT_NAME}").id
    results = User.get_filtered_objects(per_page: 1000, must_filters: { draft_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } )
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"
    assert results.include?(users(:student_1)), "results should include user with ongoing and drafted connections"
    assert_false results.include?(users(:mkr_student)), "results should not include user with ongoing connections but no drafted"
    assert_false results.include?(users(:f_student)), "results should not include user without connections"
    assert_false results.include?(users(:student_4)), "results should not include user with only closed connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { draft_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } )
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"
    assert_false results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"
    assert results.include?(users(:mkr_student)), "results should include user with ongoing connections but no drafted"
    assert results.include?(users(:f_student)), "results should include user without connections"
    assert results.include?(users(:student_4)), "results should include user with only closed connections"
  end

  def test_search_with_has_draft_connections_and_connection_status
    student_role_id = roles("#{programs(:albers).id}_#{RoleConstants::STUDENT_NAME}").id
    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_user_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), draft_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } )
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"
    assert results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, draft_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } )
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"
    assert_false results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { total_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, draft_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), "roles.id" => student_role_id } )
    assert results.include?(users(:drafted_group_user)), "results should include user with only drafted connections"
    assert_false results.include?(users(:student_2)), "results should included user with only ongoing connections"
    assert_false results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, draft_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } )
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"
    assert_false results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"
    assert results.include?(users(:f_student)), "results should include user without connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { active_user_connections_count: (1..AdminView::CONNECTION_STATUS_FILTER_MAX_VALUE), draft_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } )
    assert results.include?(users(:student_2)), "results should include user with only ongoing connections"
    assert_false results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"

    results = User.get_filtered_objects(per_page: 1000, must_filters: { total_user_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, draft_connections_count: AdminView::CONNECTION_STATUS_FILTER_MIN_VALUE, "roles.id" => student_role_id } )
    assert results.include?(users(:f_student)), "results should include user without connections"
    assert_false results.include?(users(:student_1)), "results should not include user with ongoing and drafted connections"
    assert_false results.include?(users(:drafted_group_user)), "results should not include user with only drafted connections"
  end

  def test_search_mentor_availability
    program_id = programs(:albers).id
    assert_equal 7, User.get_filtered_objects(must_filters: { availability: 1..3, program_id: program_id } ).size
    assert_equal 3, User.get_filtered_objects(must_filters: { availability: 1, program_id: program_id } ).size
    assert_equal_unordered users(:f_mentor, :mentor_1, :requestable_mentor).map(&:id), User.get_filtered_objects(must_filters: { availability: 1, program_id: program_id } ).map(&:id)

    user = users(:f_student)
    assert_nil user.max_connections_limit
    assert_equal 0, user.groups.active.size
    assert_false User.get_filtered_objects(must_filters: { availability: 1, program_id: program_id } ).map(&:id).include?(user.id)
    assert User.get_filtered_objects(must_filters: { availability: 0, program_id: program_id } ).map(&:id).include?(user.id)
  end

  def test_search_mentor_availability_should_consider_pending_offers
    user = users(:f_mentor)
    program = user.program
    assert_equal_unordered [user.id] + users(:mentor_1, :requestable_mentor).map(&:id), User.get_filtered_objects(must_filters: { availability: 1, program_id: program.id } ).map(&:id)

    program.organization.enable_feature(FeatureName::OFFER_MENTORING, true)
    program.reload.update_attribute(:mentor_offer_needs_acceptance, true)
    mentor_offer = create_mentor_offer(mentor: user, max_connection_limit: user.max_connections_limit)
    reindex_documents(updated: user)
    assert_equal_unordered users(:mentor_1, :requestable_mentor).map(&:id), User.get_filtered_objects(must_filters: { availability: 1, program_id: program.id } ).map(&:id)

    mentor_offer.destroy
    reindex_documents(updated: user)
    assert_equal_unordered [user.id] + users(:mentor_1, :requestable_mentor).map(&:id), User.get_filtered_objects(must_filters: { availability: 1, program_id: program.id } ).map(&:id)
  end

  def test_sort_for_es
    es_users = User.get_filtered_objects(per_page: (User.all.count), sort: { "state" => "asc" } )
    rails_users = User.order(:state)
    assert_equal es_users.map(&:state), rails_users.map(&:state)

    users = User.get_filtered_objects(search_conditions: { search_text: "ram@example.com", fields: UserElasticsearchQueries::MATCH_FIELDS } )
    users.each do |user|
      assert_equal "ram@example.com", user.member.email
    end
    es_users = User.get_filtered_objects(per_page: (User.all.count), sort: { active_user_connections_count: "asc" } )
    active_group_count = es_users.map(&:groups).map(&:active).map(&:size)
    assert_equal active_group_count, active_group_count.sort
  end

  def test_never_seen_in_program
    program = programs(:albers)
    never_seen_users = program.all_users.where(last_seen_at: nil)
    assert never_seen_users.include?(users(:f_mentor))
    assert_false never_seen_users.include?(users(:mentor_1))
    assert_false never_seen_users.include?(users(:mentor_2))

    never_seen_es_users = User.get_filtered_objects(per_page: 1000, must_filters: { program_id: program.id }, should_not_filters: [ { exists_query: :last_seen_at } ], page: 1)
    assert never_seen_es_users.include?(users(:f_mentor))
    assert_false never_seen_es_users.include?(users(:mentor_1))
    assert_false never_seen_es_users.include?(users(:mentor_2))
  end

  def test_search_users_with_mentoring_mode_ongoing_or_one_time_and_ongoing
    program_id = programs(:moderated_program).id
    role_ids = [roles("#{program_id}_#{RoleConstants::MENTOR_NAME}").id]
    user_ids = User.get_filtered_ids(page: 1, per_page: 1000000, must_filters: { "roles.id" => role_ids, program_id: program_id, mentoring_mode: User::MentoringMode.ongoing_sanctioned, can_accept_request: true, state: [User::Status::ACTIVE, User::Status::PENDING] } )
    assert user_ids.include?(users(:moderated_mentor).id)
    assert_false user_ids.include?(users(:f_onetime_mode_mentor).id)
  end

  def test_get_explicit_user_preferences_should_query
    user = users(:f_admin)
    QueryHelper::Filter.stubs(:simple_bool_should).with([]).once
    user.get_explicit_user_preferences_should_query

    user = users(:arun_albers)
    preferences = [explicit_user_preferences(:explicit_user_preference_1), explicit_user_preferences(:explicit_user_preference_2), explicit_user_preferences(:explicit_user_preference_3)]
    QueryHelper::Filter.stubs(:simple_bool_should).with(preferences.map{|p| {constant_score: {filter: {terms: {profile_answer_choices: p.question_choices.pluck(:id)}}, boost: p.preference_weight}}}).once
    user.get_explicit_user_preferences_should_query
  end

  def test_get_explicit_user_preferences_should_query_for_location_type
    user = users(:f_admin)
    QueryHelper::Filter.stubs(:simple_bool_should).with([]).once
    user.get_explicit_user_preferences_should_query

    user = users(:drafted_group_user)
    preferences = [explicit_user_preferences(:explicit_user_preference_4)]
    QueryHelper::Filter.stubs(:get_match_phrase_query).with("member.location_answer.location.full_location", "Chennai,Tamilnadu,India").once.returns("phrase_query")
    QueryHelper::Filter.stubs(:simple_bool_should).with(preferences.map{|p| {constant_score: {filter: "phrase_query", boost: p.preference_weight}}}).once
    user.get_explicit_user_preferences_should_query
  end
end