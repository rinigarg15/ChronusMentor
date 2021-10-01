require_relative './../../test_helper.rb'

class BulkMatchHelperTest < ActionView::TestCase
  include MentoringModelCommonHelper

  def test_create_students_json_array
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    student = users(:f_student)
    group_status = {
      s1_id => {
        :status => Group::Status::ACTIVE,
        :mentor_list => [m1_id]
        },
      s2_id => {
        :status => Group::Status::DRAFTED,
        :mentor_list => [m1_id]
      }
    }
    selected_mentors = {s1_id => [m1_id], s2_id => [m1_id]}
    suggested_mentors = {s1_id => [[m1_id, 60], [m2_id, 10]], s2_id => [[m1_id, 40], [m2_id, 20]]}
    active_groups = programs(:albers).groups.active
    drafted_groups = programs(:albers).groups.drafted
    options = {selected_mentors: selected_mentors, suggested_mentors: suggested_mentors, active_groups: active_groups, drafted_groups: drafted_groups, group_status: group_status, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}

    self.expects(:get_user_common_details).with(student).returns(some_user_details_hash: "some_user_details")
    self.expects(:get_student_details).with(student, selected_mentors, suggested_mentors, options).returns({some_hash: "some_value"})
    assert_equal "[{\"some_user_details_hash\":\"some_user_details\",\"some_hash\":\"some_value\"}]", create_students_json_array([student], options)
  end

  def test_student_details
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    student = users(:f_student)
    group_status = {
      s1_id => {
        :status => Group::Status::ACTIVE,
        :mentor_list => [m1_id]
        },
      s2_id => {
        :status => Group::Status::DRAFTED,
        :mentor_list => [m1_id]
      }
    }
    selected_mentors = {s1_id => [m1_id], s2_id => [m1_id]}
    suggested_mentors = {s1_id => [[m1_id, 60], [m2_id, 10]], s2_id => [[m1_id, 40], [m2_id, 20]]}
    active_groups = programs(:albers).groups.active
    drafted_groups = programs(:albers).groups.drafted
    options = {active_groups: active_groups, drafted_groups: drafted_groups, group_status: group_status, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR, pickable_slots: {s1_id => 1, s2_id => 1}}

    self.expects(:get_selected_and_suggested_mentor_details).with(student, selected_mentors, suggested_mentors).returns({selected_mentors: [m1_id], selected_count: 1, suggested_mentors: [[m1_id, 60], [m2_id, 10]], suggested_mentors_length: 10})
    self.expects(:get_group_details).with(group_status, student, selected_mentors, BulkMatch.name, {}).returns({group_status: "Published", group_id: 1})
    self.expects(:group_users_links_for_bulk_match).with(student, :drafted, drafted_groups, true).returns({ drafted_mentor_id_group_id_list: [], drafted_mentors_html: "" })
    self.expects(:group_users_links_for_bulk_match).with(student, :connected, active_groups, true).returns({ connected_mentor_id_group_id_list: [], connected_mentors_html: "" })
    self.expects(:get_primary_and_secondary_labels).with("Published", BulkMatch.name).returns({:primary_action_label=>"Draft", :secondary_action_label=>"Publish"})
    expected_hash = {selected_mentors: [m1_id], selected_count: 1, suggested_mentors: [[m1_id, 60], [m2_id, 10]], suggested_mentors_length: 10, group_status: "Published", group_id: 1, primary_action_label: "Draft", secondary_action_label: "Publish", drafted_mentor_id_group_id_list: [], drafted_mentors_html: "", connected_mentor_id_group_id_list: [], connected_mentors_html: ""}
    assert_equal expected_hash, get_student_details(student, selected_mentors, suggested_mentors, options)

    options = {active_groups: active_groups, drafted_groups: drafted_groups, group_status: group_status, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE, pickable_slots: {s1_id => 1, s2_id => 1}}
    self.expects(:group_users_links_for_bulk_match).with(student, :drafted, drafted_groups, true).returns({ drafted_mentor_id_group_id_list: [], drafted_mentors_html: "" })
    self.expects(:group_users_links_for_bulk_match).with(student, :connected, active_groups, true).returns({ connected_mentor_id_group_id_list: [], connected_mentors_html: "" })
    expected_hash = {drafted_mentor_id_group_id_list: [], drafted_mentors_html: "", connected_mentor_id_group_id_list: [], connected_mentors_html: "", pickable_slots: 1}
     assert_equal expected_hash, get_student_details(student, selected_mentors, suggested_mentors, options)
  end

  def test_create_students_json_array_for_bulk_recommendation
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    student_users = [users(:f_student), users(:rahim)]
    group_status = {
      s1_id => {
        :status => MentorRecommendation::Status::DRAFTED,
        :mentor_list => [m1_id]
      },
      s2_id => {
        :status => MentorRecommendation::Status::PUBLISHED,
        :mentor_list => [m1_id]
      }
    }
    selected_mentors = {s1_id => [m1_id], s2_id => [m1_id]}
    suggested_mentors = {s1_id => [[m1_id, 60], [m2_id, 10]], s2_id => [[m1_id, 40], [m2_id, 20]]}
    active_groups = programs(:albers).groups.active
    drafted_groups = programs(:albers).groups.drafted
    options = {group_status: group_status, selected_mentors: selected_mentors, suggested_mentors: suggested_mentors, active_groups: active_groups, drafted_groups: drafted_groups, bulk_match_type: BulkRecommendation.name, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}

    res = JSON.parse create_students_json_array(student_users, options)
    stud1 = res[0]
    stud2 = res[1]
    assert_equal "student example", stud1["name"]
    assert_equal "Drafted", stud1["group_status"]
    assert_equal [3], stud1["selected_mentors"]
    assert_equal 1, stud1["selected_count"]
    assert_equal_unordered [[3, 60], [8, 10]], stud1["suggested_mentors"]
    assert_equal 10, stud1["suggested_mentors_length"]
    assert_false stud1["show_summary_details"]
    assert_equal "Send Recommendations", stud1["primary_action_label"]
    assert_equal "Discard Draft", stud1["secondary_action_label"]

    assert_equal "Recommendations Sent", stud2["group_status"]
    assert_equal "Discard", stud2["primary_action_label"]
    assert_equal "", stud2["secondary_action_label"]

    group_status = {
      s1_id => {
        :status => MentorRecommendation::Status::DRAFTED,
        :mentor_list => [m1_id]
      }
    }
  end


  def test_create_mentors_json_array_for_mentee_to_mentor_view
    current_program = programs(:albers)
    m1_id = users(:f_mentor).id
    options = {program: current_program, pickable_slots: {m1_id => 5}, recommended_count: {}}
    mentor = users(:f_mentor)
    mentor_slot_hash = {m1_id => mentor.slots_available}

    self.expects(:get_user_common_details).with(mentor,  {is_mentor: true, recommend_mentors: nil}).returns(some_user_details_hash: "some_user_details")
    self.expects(:get_mentor_availabilty_details).with(mentor, current_program, mentor_slot_hash, {m1_id => 5}, {}).returns({some_hash: "some_value"})
    self.expects(:get_mentor_details_for_mentor_to_mentee_view).never
    assert_equal "[{\"some_user_details_hash\":\"some_user_details\",\"some_hash\":\"some_value\"}]", create_mentors_json_array([mentor], mentor_slot_hash, options)
  end

  def test_create_mentors_json_array_for_mentor_to_mentee_view
    current_program = programs(:albers)

    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    selected_students = {m1_id => [s1_id], m2_id => [s2_id]}
    suggested_students = {m1_id => [[s1_id, 60], [s2_id, 40]], m2_id => [[s2_id, 20], [s1_id, 10]]}
    active_groups = programs(:albers).groups.active
    drafted_groups = programs(:albers).groups.drafted
    options = {active_groups: active_groups, drafted_groups: drafted_groups, program: current_program, pickable_slots: {m1_id => 5}, recommended_count: {}, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE, selected_students: selected_students, suggested_students: suggested_students, group_status: {}}

    mentor = users(:f_mentor)
    mentor_slot_hash = {m1_id => mentor.slots_available}
    self.expects(:get_user_common_details).with(mentor,  {is_mentor: true, recommend_mentors: nil}).returns(some_user_details_hash: "some_user_details")
    self.expects(:get_mentor_details_for_mentor_to_mentee_view).with(mentor, mentor_slot_hash, selected_students, suggested_students, options).returns({some_hash: "some_value"})
    assert_equal "[{\"some_user_details_hash\":\"some_user_details\",\"some_hash\":\"some_value\"}]", create_mentors_json_array([mentor], mentor_slot_hash, options)
  end

  def test_get_mentor_details_for_mentee_to_mentor_view
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    mentor = users(:f_mentor)
    mentor_slot_hash = {mentor.id => mentor.slots_available}
    options = {bulk_match_type: BulkMatch.name, program: mentor.program, orientation_type: BulkMatch::OrientationType::MENTEE_TO_MENTOR}
    self.expects(:get_mentor_availabilty_details).with(mentor, mentor.program, mentor_slot_hash, nil, nil).returns({some_key: "some_value"})
    self.expects(:get_mentor_details_for_mentor_to_mentee_view).never
    expected_hash = {some_key: "some_value"}
    assert_equal expected_hash, get_mentor_details(mentor, mentor_slot_hash, options)

    options = {bulk_match_type: BulkMatch.name, program: mentor.program, orientation_type: BulkMatch::OrientationType::MENTOR_TO_MENTEE}
    self.expects(:get_mentor_availabilty_details).never
    self.expects(:get_mentor_details_for_mentor_to_mentee_view).with(mentor, mentor_slot_hash, nil, nil, options).returns({some_key: "some_value"})
    expected_hash = {some_key: "some_value"}
    assert_equal expected_hash, get_mentor_details(mentor, mentor_slot_hash, options)
  end


  def test_get_mentor_details_for_mentor_to_mentee_view
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    selected_students = {m1_id => [s1_id], m2_id => [s2_id]}
    suggested_students = {m1_id => [[s1_id, 75], [s2_id, 50]], m2_id => [[s2_id, 75], [s1_id, 50]]}
    group_status = {
      m1_id => {
        status: Group::Status::ACTIVE,
        student_list: [m1_id],
        group_id: 1
      }
    }
    mentor = users(:f_mentor)
    options = {bulk_match_type: BulkMatch.name, program: mentor.program, drafted_groups: [], active_groups: [], group_status: group_status}
    mentor_slot_hash = {mentor.id => mentor.slots_available}
    pickable_slots = {mentor.id => 5}

    self.expects(:get_selected_and_suggested_student_details).with(mentor, selected_students, suggested_students).returns({selected_students: [s1_id], selected_count: 1, suggested_students: [[s1_id, 75], [s2_id, 50]], suggested_students_length: 10})
    self.expects(:get_group_details).with(group_status, mentor, selected_students, options[:bulk_match_type], {pickable_slots: options[:pickable_slots]}).returns({group_status: "Published", group_id: 1})
    self.expects(:get_mentor_availabilty_details).with(mentor, options[:program], mentor_slot_hash, options[:pickable_slots], options[:recommended_count]).returns({slots_available: 1, pickable_slots: 5, recommended_count: nil, connections_count: 1, mentor_prefer_one_time_mentoring_and_program_allowing: false})
    self.expects(:group_users_links_for_bulk_match).with(mentor, :drafted, [], false).returns({ drafted_student_id_group_id_list: [], drafted_students_html: "" })
    self.expects(:group_users_links_for_bulk_match).with(mentor, :connected, [], false).returns({ connected_student_id_group_id_list: [], connected_students_html: "" })
    self.expects(:get_primary_and_secondary_labels).with("Published", BulkMatch.name).returns({:primary_action_label=>"Draft", :secondary_action_label=>"Publish"})
    expected_hash = {selected_students: [s1_id], selected_count: 1, suggested_students: [[s1_id, 75], [s2_id, 50]], suggested_students_length: 10, group_status: "Published", group_id: 1, slots_available: 1, pickable_slots: 5, recommended_count: nil, connections_count: 1, mentor_prefer_one_time_mentoring_and_program_allowing: false, drafted_student_id_group_id_list: [], drafted_students_html: "", connected_student_id_group_id_list: [], connected_students_html: "", primary_action_label: "Draft", secondary_action_label: "Publish"}
    assert_equal expected_hash, get_mentor_details_for_mentor_to_mentee_view(mentor, mentor_slot_hash, selected_students, suggested_students, options)
  end

  def test_group_users_links_for_mentee_to_mentor_bulk_match
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    admin = users(:f_admin)
    mentor.update_attribute(:max_connections_limit, 5)
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    SecureRandom.stubs(:hex).returns(1)
    group_1 = create_group(students: [student], mentors: [mentor], status: Group::Status::DRAFTED, creator_id: admin.id)
    group_2 = create_group(students: [student], mentors: [mentor], status: Group::Status::DRAFTED, creator_id: admin.id)

    assert_equal_hash( { drafted_mentor_id_group_id_list: [], drafted_mentors_html: "" }, group_users_links_for_bulk_match(student, :drafted, []))
    assert_equal_hash( { connected_mentor_id_group_id_list: [], connected_mentors_html: "" }, group_users_links_for_bulk_match(student, :connected, []))

    output = group_users_links_for_bulk_match(student, :drafted, program.groups.drafted)
    assert_equal_unordered [[mentor.id, group_1.id], [mentor.id, group_2.id]], output[:drafted_mentor_id_group_id_list]
    assert_select_helper_function "span.cjs-user-link-container a[title=\"#{mentor.name}\"]", output[:drafted_mentors_html], text: mentor.name, href: member_path(mentor.member), count: 1
    assert_equal_hash( { connected_mentor_id_group_id_list: [], connected_mentors_html: "" }, group_users_links_for_bulk_match(student, :connected, program.groups.active))

    group_2.publish(admin)
    output = group_users_links_for_bulk_match(student, :drafted, program.groups.drafted)
    assert_equal [[mentor.id, group_1.id]], output[:drafted_mentor_id_group_id_list]
    assert_select_helper_function "span.cjs-user-link-container a[title=\"#{mentor.name}\"]", output[:drafted_mentors_html], text: mentor.name, href: member_path(mentor.member), count: 1
    output = group_users_links_for_bulk_match(student, :connected, program.groups.active)
    assert_equal [[mentor.id, group_2.id]], output[:connected_mentor_id_group_id_list]
    assert_select_helper_function "span.cjs-user-link-container a[title=\"#{mentor.name}\"]", output[:connected_mentors_html], text: mentor.name, href: member_path(mentor.member), count: 1
  end

  def test_group_users_links_for_mentor_to_mentee_bulk_match
    program = programs(:albers)
    student = users(:f_student)
    mentor = users(:f_mentor)
    admin = users(:f_admin)
    mentor.update_attribute(:max_connections_limit, 5)
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    SecureRandom.stubs(:hex).returns(1)
    group_1 = create_group(students: [student], mentors: [mentor], status: Group::Status::DRAFTED, creator_id: admin.id)
    group_2 = create_group(students: [student], mentors: [mentor], status: Group::Status::DRAFTED, creator_id: admin.id)

    assert_equal_hash( { drafted_student_id_group_id_list: [], drafted_students_html: "" }, group_users_links_for_bulk_match(mentor, :drafted, [], false))
    assert_equal_hash( { connected_student_id_group_id_list: [], connected_students_html: "" }, group_users_links_for_bulk_match(mentor, :connected, [], false))

    output = group_users_links_for_bulk_match(mentor, :drafted, program.groups.drafted, false)
    assert_equal_unordered [[student.id, group_1.id], [student.id, group_2.id]], output[:drafted_student_id_group_id_list]
    assert_select_helper_function "span.cjs-user-link-container a[title=\"#{student.name}\"]", output[:drafted_students_html], text: student.name, href: member_path(student.member), count: 1
    groups(:mygroup).update_column(:status, Group::Status::CLOSED)
    assert_equal_hash( { connected_student_id_group_id_list: [], connected_students_html: "" }, group_users_links_for_bulk_match(mentor, :connected, program.groups.active, false))

    group_2.publish(admin)
    output = group_users_links_for_bulk_match(mentor, :drafted, program.groups.drafted, false)
    assert_equal [[student.id, group_1.id]], output[:drafted_student_id_group_id_list]
    assert_select_helper_function "span.cjs-user-link-container a[title=\"#{student.name}\"]", output[:drafted_students_html], text: student.name, href: member_path(student.member), count: 1
    output = group_users_links_for_bulk_match(mentor, :connected, program.groups.active, false)
    assert_equal [[student.id, group_2.id]], output[:connected_student_id_group_id_list]
    assert_select_helper_function "span.cjs-user-link-container a[title=\"#{student.name}\"]", output[:connected_students_html], text: student.name, href: member_path(student.member), count: 1
  end

  def test_get_publish_action_label
    assert_equal "Publish", get_publish_action_label(BulkMatch.name)
    assert_equal "Send Recommendations", get_publish_action_label(BulkRecommendation.name)
  end

  def test_build_bulk_match_vars
    bulk_match = bulk_matches(:bulk_match_1)
    assert_equal "{\"sort_order\":true,\"sort_value\":\"best_mentor_score\",\"show_drafted\":false,\"show_published\":false,\"request_notes\":true,\"update_status_path\":\"/bulk_matches/update_bulk_match_pair\",\"bulk_update_status_path\":\"/bulk_matches/bulk_update_bulk_match_pair\",\"update_settings_path\":\"/bulk_matches/update_settings.js\",\"fetch_notes_path\":\"/bulk_matches/fetch_notes\",\"summary_details_path\":\"/bulk_matches/fetch_summary_details\",\"alter_pickable_slots_path\":\"/bulk_matches/alter_pickable_slots\",\"groups_alert_path\":\"/bulk_matches/groups_alert\",\"recommend_mentors\":false,\"type\":\"BulkMatch\",\"max_suggestion_count\":1,\"range\":\"NA\",\"average_score\":\"NA\",\"deviation\":\"NA\",\"update_type\":{\"draft\":\"draft\",\"publish\":\"publish\",\"discard\":\"discard\"},\"orientation_type\":0}", build_bulk_match_vars(bulk_match)
  end

  def test_build_bulk_match_vars_for_bulk_recommendation
    bulk_match = bulk_matches(:bulk_recommendation_1)
    res = JSON.parse build_bulk_match_vars(bulk_match)
    assert_false res["show_drafted"]
    assert_false res["show_published"]
    assert_false res["request_notes"]
    assert res["sort_order"]
    assert_equal "best_mentor_score", res["sort_value"]
    assert_equal BulkRecommendation.name, res["type"]
    assert res["recommend_mentors"]
    assert_equal_hash( { BulkMatch::UpdateType::DRAFT => BulkMatch::UpdateType::DRAFT, BulkMatch::UpdateType::PUBLISH => BulkMatch::UpdateType::PUBLISH, BulkMatch::UpdateType::DISCARD => BulkMatch::UpdateType::DISCARD }, res["update_type"])
  end

  def test_get_primary_and_secondary_labels
    expected_hash = {:primary_action_label=>"Draft", :secondary_action_label=>"Publish"}
    assert_equal expected_hash, get_primary_and_secondary_labels("Selected", BulkMatch.name)
    expected_hash = {:primary_action_label=>"Draft", :secondary_action_label=>"Send Recommendations"}
    assert_equal expected_hash, get_primary_and_secondary_labels("Selected", BulkRecommendation.name)

    expected_hash = {:primary_action_label=>"Publish", :secondary_action_label=>"Discard Draft"}
    assert_equal expected_hash, get_primary_and_secondary_labels("Drafted", BulkMatch.name)
    expected_hash = {:primary_action_label=>"Send Recommendations", :secondary_action_label=>"Discard Draft"}
    assert_equal expected_hash, get_primary_and_secondary_labels("Drafted", BulkRecommendation.name)

    expected_hash = {:primary_action_label=>"", :secondary_action_label=>""}
    assert_equal expected_hash, get_primary_and_secondary_labels("Published", BulkMatch.name)
    expected_hash = {:primary_action_label=>"Discard", :secondary_action_label=>""}
    assert_equal expected_hash, get_primary_and_secondary_labels("Published", BulkRecommendation.name)
  end

  def test_get_user_common_details
    user = users(:f_mentor)
    self.stubs(:display_member_name).returns("member name")
    self.stubs(:user_picture).with(user, {no_name: true, size: :medium, member_name: "member name", bulk_match_view: true, row_fluid: true}, { }).returns("user picture")
    self.stubs(:link_to_user_for_admin).returns("link to user")
    expected_hash = {id: user.id, name: "member name", picture_with_profile_url: "user picture", name_with_profile_url: "link to user"}
    assert_equal expected_hash, get_user_common_details(user)
    self.stubs(:user_picture).with(user, {no_name: true, size: :small, member_name: "member name", bulk_match_view: true, row_fluid: true}, { }).returns("user picture")
    assert_equal expected_hash, get_user_common_details(user, {is_mentor: true, recommend_mentors: true})
  end

  def test_get_mentor_availabilty_details
    user = users(:f_mentor)
    program = user.program
    mentor_slot_hash = {user.id => user.slots_available}
    pickable_slots = {user.id => 5}
    expected_hash = {slots_available: 1, pickable_slots: 5, recommended_count: nil, connections_count: 1, mentor_prefer_one_time_mentoring_and_program_allowing: false}
    assert_equal expected_hash, get_mentor_availabilty_details(user, program, mentor_slot_hash, pickable_slots, {})
    recommended_count = {user.id => 2}
    expected_hash = {slots_available: 1, pickable_slots: 5, recommended_count: 2, connections_count: 1, mentor_prefer_one_time_mentoring_and_program_allowing: false}
    assert_equal expected_hash, get_mentor_availabilty_details(user, program, mentor_slot_hash, pickable_slots, recommended_count)
  end

  def test_get_selected_and_suggested_mentor_details
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    selected_mentors = {s1_id => [m1_id], s2_id => [m2_id]}
    suggested_mentors = {s1_id => [[m1_id, 75], [m2_id, 50]], s2_id => [[m2_id, 75], [m1_id, 50]]}
    expected_hash = {selected_mentors: [m1_id], selected_count: 1, suggested_mentors: [[m1_id, 75], [m2_id, 50]], suggested_mentors_length: 10}
    assert_equal expected_hash, get_selected_and_suggested_mentor_details(users(:f_student), selected_mentors, suggested_mentors)
    expected_hash = {selected_mentors: [m2_id], selected_count: 1, suggested_mentors: [[m2_id, 75], [m1_id, 50]], suggested_mentors_length: 10}
    assert_equal expected_hash, get_selected_and_suggested_mentor_details(users(:rahim), selected_mentors, suggested_mentors)
  end

  def test_get_selected_and_suggested_student_details
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    selected_students = {m1_id => [s1_id], m2_id => [s2_id]}
    suggested_students = {m1_id => [[s1_id, 75], [s2_id, 50]], m2_id => [[s2_id, 75], [s1_id, 50]]}
    expected_hash = {selected_students: [s1_id], selected_count: 1, suggested_students: [[s1_id, 75], [s2_id, 50]], suggested_students_length: 10}
    assert_equal expected_hash, get_selected_and_suggested_student_details(users(:f_mentor), selected_students, suggested_students)
    expected_hash = {selected_students: [s2_id], selected_count: 1, suggested_students: [[s2_id, 75], [s1_id, 50]], suggested_students_length: 10}
    assert_equal expected_hash, get_selected_and_suggested_student_details(users(:robert), selected_students, suggested_students)
  end

  def test_get_group_details
    s1_id, s2_id = [users(:f_student).id, users(:rahim).id]
    m1_id, m2_id = [users(:f_mentor).id, users(:robert).id]
    student_users = [users(:f_student), users(:rahim)]
    group_status = {
      s1_id => {
        status: Group::Status::ACTIVE,
        mentor_list: [m1_id],
        group_id: 1
      }
    }
    selected_users = {s1_id => [m1_id]}
    expected_hash = {group_status: "Published", group_id: 1}
    assert_equal expected_hash, get_group_details(group_status, users(:f_student), selected_users, BulkMatch.name, {})
    expected_hash = {group_status: "Unmatched", group_id: nil}
    assert_equal expected_hash, get_group_details(group_status, users(:rahim), selected_users, BulkMatch.name, {})
    selected_users = {s1_id => [m1_id], s2_id => [m2_id]}
    expected_hash = {group_status: "Selected", group_id: nil}
    assert_equal expected_hash, get_group_details(group_status, users(:rahim), selected_users, BulkMatch.name, {})


    selected_users = {s1_id => [m1_id]}
    group_status = {
      s1_id => {
        status: MentorRecommendation::Status::PUBLISHED,
        mentor_list: [m1_id],
        group_id: 1
      }
    }
    expected_hash = {group_status: "Recommendations Sent", group_id: 1}
    assert_equal expected_hash, get_group_details(group_status, users(:f_student), selected_users, BulkRecommendation.name, {})
    expected_hash = {group_status: "Unmatched", group_id: nil}
    assert_equal expected_hash, get_group_details(group_status, users(:rahim), selected_users, BulkRecommendation.name, {})
    selected_users = {s1_id => [m1_id], s2_id => [m2_id]}
    expected_hash = {group_status: "Selected", group_id: nil}
    assert_equal expected_hash, get_group_details(group_status, users(:rahim), selected_users, BulkRecommendation.name, {})
  end

  def test_get_status_label
    status = Group::Status::DRAFTED
    self.expects(:get_bulk_match_status_label).with(status)
    get_status_label(status, BulkMatch.name)
    self.expects(:get_bulk_match_recommendation_label).with(status)
    get_status_label(status, BulkRecommendation.name)
  end

  def test_get_unmatched_label
    user = users(:f_mentor)
    assert_equal "Not Available", get_unmatched_label(user, {pickable_slots: {user.id => 0}})
    assert_equal "Unmatched", get_unmatched_label(user, {})
    assert_equal "Unmatched", get_unmatched_label(user, {pickable_slots: {user.id => 1}})
  end

  def test_get_bulk_match_status_label
    assert_equal "Drafted", get_bulk_match_status_label(Group::Status::DRAFTED)
    assert_equal "Published", get_bulk_match_status_label(Group::Status::ACTIVE)
    assert_equal "Published", get_bulk_match_status_label(Group::Status::INACTIVE)
  end

  def test_get_bulk_match_recommendation_label
    assert_equal "Drafted", get_bulk_match_recommendation_label(MentorRecommendation::Status::DRAFTED)
    assert_equal "Recommendations Sent", get_bulk_match_recommendation_label(MentorRecommendation::Status::PUBLISHED)
  end

  def test_bulk_match_action_text
    bulk_match = bulk_matches(:bulk_match_1)
    assert_equal "Publish", bulk_match_action_text(bulk_match, BulkMatch::UpdateType::PUBLISH, true, '')
    assert_equal "Update notes & Draft", bulk_match_action_text(bulk_match, BulkMatch::UpdateType::DRAFT, false, 'Notes')
    assert_equal "Add notes & Draft", bulk_match_action_text(bulk_match, BulkMatch::UpdateType::DRAFT, false, '')
    assert_equal "Update notes", bulk_match_action_text(bulk_match, '', false, 'Notes')
    assert_equal "Add notes", bulk_match_action_text(bulk_match, '', false, '')
  end

  def test_get_view_user_details
    program = programs(:albers)
    user_details_hash = get_view_user_details(program, program.users.collect(&:id))
    program.groups.drafted.each do |group|
      group.status = Group::Status::ACTIVE
      group.expiry_time = Time.current + 3.days
      group.save!
    end
    new_user_details_hash = get_view_user_details(program, program.users.collect(&:id))
    assert_equal 0, new_user_details_hash[:drafted]
    assert_equal user_details_hash[:connected] + user_details_hash[:drafted], new_user_details_hash[:connected]
  end

  def test_render_mentoring_model_selector
    @current_program = programs(:albers)
    mentoring_models = get_all_mentoring_models(programs(:albers))
    assert_nil render_mentoring_model_selector(mentoring_models)
    @current_program.expects(:mentoring_connections_v2_enabled?).returns(true).times(3)
    mentoring_model_selector = render_mentoring_model_selector(mentoring_models)
    set_response_text mentoring_model_selector
    assert_select "select#cjs_assign_mentoring_model", name: "mentoring_model" do
      mentoring_models.each do |mentoring_model|
        assert_select "option", text: mentoring_model_pane_title(mentoring_model)
      end
    end
    assert_select_helper_function "label[for=cjs_assign_mentoring_model]", mentoring_model_selector
    assert_select_helper_function "label[for=cjs_assign_mentoring_model]", render_mentoring_model_selector(mentoring_models, without_label: true), { count: 0 }
    assert_select_helper_function "select#cjs_assign_mentoring_model_element_id", render_mentoring_model_selector(mentoring_models, id_suffix: "element_id")
  end

  def test_get_drafted_and_published_labels_for_settings
    assert_equal ["Show mentees with drafted mentoring_connections?", "Show mentees with published mentoring_connections?"], get_drafted_and_published_labels_for_settings(false, BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    assert_equal ["Show Drafted Recommendations?", "Show Published Recommendations?"], get_drafted_and_published_labels_for_settings(true, BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    assert_equal ["Show mentors with drafted mentoring_connections?", "Show mentors with published mentoring_connections?"], get_drafted_and_published_labels_for_settings(false, BulkMatch::OrientationType::MENTOR_TO_MENTEE)
  end

  def test_is_mentee_to_mentor_view
    assert_false is_mentee_to_mentor_view?(nil)
    assert_false is_mentee_to_mentor_view?(BulkMatch::OrientationType::MENTOR_TO_MENTEE)
    assert is_mentee_to_mentor_view?(BulkMatch::OrientationType::MENTEE_TO_MENTOR)
  end

  def test_is_mentor_to_mentee_view
    assert_false is_mentor_to_mentee_view?(nil)
    assert_false is_mentor_to_mentee_view?(BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    assert is_mentor_to_mentee_view?(BulkMatch::OrientationType::MENTOR_TO_MENTEE)
  end

  def test_get_max_pickable_slots_label_for_settings
    assert_equal ["Limit mentees per mentor to:", "Reducing the limit will refresh the result to select best possible mentor. UnMatched/Selected pairs will not be preserved."], get_max_pickable_slots_label_for_settings(false, BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    assert_equal ["Limit number of times a mentor can be recommended to:", "Reducing limit will refresh the result to select best possible mentors. UnMatched/Selected recommendations will not be preserved."], get_max_pickable_slots_label_for_settings(true, BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    assert_equal ["Limit mentors per mentee to:", "Reducing the limit will refresh the result to select best possible mentee. UnMatched/Selected pairs will not be preserved."], get_max_pickable_slots_label_for_settings(false, BulkMatch::OrientationType::MENTOR_TO_MENTEE)
  end

  def test_get_orientation_based_role_params
    student = users(:f_student)
    mentor = users(:f_mentor)
    assert_equal ["mentee", "mentor", "student example", "Good unique name", "mentees"], get_orientation_based_role_params(student, mentor, BulkMatch::OrientationType::MENTEE_TO_MENTOR)
    assert_equal ["mentor", "mentee", "Good unique name", "student example", "mentors"], get_orientation_based_role_params(student, mentor, BulkMatch::OrientationType::MENTOR_TO_MENTEE)

  end

  private

  def _Mentoring_Connection
    "Mentoring Connection"
  end

  def _mentoring_connections
    "mentoring_connections"
  end

  def _mentees
    "mentees"
  end

  def _mentors
    "mentors"
  end

  def _mentee
    "mentee"
  end

  def _mentor
    "mentor"
  end

  def mentoring_model_pane_title(mentoring_model)
    content = mentoring_model.title
    content += " #{"feature.multiple_templates.header.default_marker".translate}" if mentoring_model.default?
    content
  end
end