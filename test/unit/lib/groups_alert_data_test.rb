require_relative './../../test_helper.rb'

# More exhaustive test cases are covered as part of groups_alert_helper_test.rb
class GroupsAlertDataTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
  end

  def test_existing_groups_alert_data
    student_ids_mentor_ids_array = []
    active_group = groups(:mygroup)
    active_group_student = active_group.students.first
    active_group_mentor = active_group.mentors.first
    active_group_student_id_mentor_id = [[active_group_student.id], [active_group_mentor.id]]
    student_ids_mentor_ids_array << active_group_student_id_mentor_id

    closed_group = groups(:group_4)
    closed_group_student = closed_group.students.first
    closed_group_mentor = closed_group.mentors.first
    closed_group_student_id_mentor_id = [[closed_group_student.id], [closed_group_mentor.id]]
    student_ids_mentor_ids_array << closed_group_student_id_mentor_id

    drafted_group = groups(:drafted_group_1)
    drafted_group_student = drafted_group.students.first
    drafted_group_mentor = drafted_group.mentors.first
    drafted_group_student_id_mentor_id = [[drafted_group_student.id], [drafted_group_mentor.id]]
    student_ids_mentor_ids_array << drafted_group_student_id_mentor_id

    output_1 = GroupsAlertData.existing_groups_alert_data(@program, [])
    assert_equal 4, output_1.size
    assert_equal_hash({}, output_1[0])
    assert_equal_hash({}, output_1[1])
    assert_equal_hash({}, output_1[2])
    assert_equal_hash({}, output_1[3])

    output_2 = GroupsAlertData.existing_groups_alert_data(@program, student_ids_mentor_ids_array)
    assert_equal 4, output_2.size
    assert_equal_hash( { active_group_student_id_mentor_id => [active_group.id] }, output_2[0])
    assert_equal_hash( { active_group.id => active_group.name }, output_2[1])
    assert_equal_hash( { active_group.id => Group::Status::ACTIVE }, output_2[2])
    assert_equal_hash( { active_group_student.id => active_group_student.name, active_group_mentor.id => active_group_mentor.name }, output_2[3])

    output_3 = GroupsAlertData.existing_groups_alert_data(@program, student_ids_mentor_ids_array, Group::Status::CLOSED)
    assert_equal 4, output_3.size
    assert_equal_hash(output_2[0].merge(closed_group_student_id_mentor_id => [closed_group.id]), output_3[0])
    assert_equal_hash(output_2[1].merge(closed_group.id => closed_group.name), output_3[1])
    assert_equal_hash(output_2[2].merge(closed_group.id => Group::Status::CLOSED), output_3[2])
    assert_equal_hash(output_2[3].merge(closed_group_student.id => closed_group_student.name, closed_group_mentor.id => closed_group_mentor.name), output_3[3])

    output_4 = GroupsAlertData.existing_groups_alert_data(@program, student_ids_mentor_ids_array, Group::Status::DRAFTED)
    assert_equal 4, output_4.size
    assert_equal_hash(output_2[0].merge(drafted_group_student_id_mentor_id => [drafted_group.id]), output_4[0])
    assert_equal_hash(output_2[1].merge(drafted_group.id => drafted_group.name), output_4[1])
    assert_equal_hash(output_2[2].merge(drafted_group.id => Group::Status::DRAFTED), output_4[2])
    assert_equal_hash(output_2[3].merge(drafted_group_student.id => drafted_group_student.name, drafted_group_mentor.id => drafted_group_mentor.name), output_4[3])
  end

  def test_bulk_match_additional_users_alert_data
    drafted_group = groups(:drafted_group_1)
    existing_student = drafted_group.students.first
    existing_mentor = drafted_group.mentors.first
    additional_students = [users(:student_8), users(:student_9)]
    additional_mentors = [users(:mentor_8)]
    bulk_match_id = drafted_group.program.student_bulk_match.id

    output_1 = GroupsAlertData.bulk_match_additional_users_alert_data(@program, [])
    assert_equal 3, output_1.size
    assert_equal_hash({}, output_1[0])
    assert_equal_hash({}, output_1[1])
    assert_equal_hash({}, output_1[2])

    output_2 = GroupsAlertData.bulk_match_additional_users_alert_data(@program, [drafted_group.id])
    assert_equal 3, output_2.size
    assert_equal_hash({}, output_2[0])
    assert_equal_hash({}, output_2[1])
    assert_equal_hash({}, output_2[2])

    drafted_group.update_members(drafted_group.mentors + additional_mentors, drafted_group.students + additional_students)
    output_3 = GroupsAlertData.bulk_match_additional_users_alert_data(@program, [drafted_group.id])
    assert_equal 3, output_3.size
    assert_equal_hash({}, output_3[0])
    assert_equal_hash({}, output_3[1])
    assert_equal_hash({}, output_3[2])

    drafted_group.update_column(:bulk_match_id, bulk_match_id)
    output_4 = GroupsAlertData.bulk_match_additional_users_alert_data(@program, [drafted_group.id])
    assert_equal 3, output_4.size
    assert_equal_hash( { [existing_student.id, existing_mentor.id] => (additional_students + additional_mentors).collect(&:id) }, output_4[0])
    assert_equal_hash( {
      users(:student_8).id => users(:student_8).name,
      users(:student_9).id => users(:student_9).name,
      users(:mentor_8).id => users(:mentor_8).name,
      existing_mentor.id => existing_mentor.name,
      existing_student.id => existing_student.name
    }, output_4[1])
    assert_equal_hash( {
      users(:student_8).id => users(:student_8).member_id,
      users(:student_9).id => users(:student_9).member_id,
      users(:mentor_8).id => users(:mentor_8).member_id,
      existing_mentor.id => existing_mentor.member_id,
      existing_student.id => existing_student.member_id
    }, output_4[2])
  end

  def test_multiple_existing_groups_note_data
    admin = users(:f_admin)
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    allow_one_to_many_mentoring_for_program(@program)

    output_1 = GroupsAlertData.multiple_existing_groups_note_data(@program)
    assert_equal 3, output_1.size
    assert_equal_hash({}, output_1[0])
    assert_equal_hash({}, output_1[1])
    assert_equal_hash({}, output_1[2])

    group_1 = groups(:mygroup)
    mentor = group_1.mentors.first
    student = group_1.students.first
    mentor.update_attribute(:max_connections_limit, 10)
    new_student = users(:f_student)
    group_2 = create_group(mentors: group_1.mentors, students: group_1.students + [users(:f_student)])
    group_3 = create_group(mentors: group_1.mentors, students: group_2.students, status: Group::Status::DRAFTED, creator_id: admin.id)
    group_4 = create_group(mentors: group_1.mentors, students: [users(:f_student)])
    output_2 = GroupsAlertData.multiple_existing_groups_note_data(@program)
    assert_equal 3, output_2.size
    assert_equal_hash( { [student.id, mentor.id] => [group_1.id, group_2.id], [new_student.id, mentor.id] => [group_2.id, group_4.id] }, output_2[0])
    assert_equal_hash( { group_1.id => group_1.name, group_2.id => group_2.name, group_4.id => group_4.name }, output_2[1])
    assert_equal_hash( { mentor.id => mentor.name, student.id => student.name, new_student.id => new_student.name }, output_2[2])

    group_2.terminate!(admin, "Reason", @program.group_closure_reasons.first.id)
    output_3 = GroupsAlertData.multiple_existing_groups_note_data(@program)
    assert_equal 3, output_3.size
    assert_equal_hash({}, output_3[0])
    assert_equal_hash({}, output_3[1])
    assert_equal_hash({}, output_3[2])
  end
end