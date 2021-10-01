require_relative './../test_helper.rb'

class GroupTransactionTest < ActiveSupport::TestCase

  def test_update_members_error_invalid_member
    group = groups(:mygroup)
    mentors = group.mentors.clone
    students = group.students.clone
    assert_false group.update_members([users(:student_3)], [users(:student_4)])
    group.reload
    assert_equal mentors.reload, group.mentors
    assert_equal students.reload, group.students
  end

  def test_update_members
    g = groups(:mygroup)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert_equal [users(:f_mentor)], g.mentors

    # Invalid update. Should preserve the old memberships
    assert_no_difference 'Connection::Membership.count' do
      assert_false g.update_members(
        [users(:student_4)],
        [users(:mkr_student)])
    end

    assert g.errors[:mentors]
    g.reload
    assert_equal [users(:f_mentor)], g.mentors
    assert_equal [users(:mkr_student)], g.students

    assert_no_difference 'Connection::Membership.count' do
      assert_false g.update_members(
        [users(:f_mentor)],
        [users(:mkr_student), users(:mentor_3)])
    end

    assert g.errors[:students]
    g.reload
    assert_equal [users(:f_mentor)], g.mentors
    assert_equal [users(:mkr_student)], g.students

    assert_difference 'Connection::Membership.count', 1 do
      assert g.update_members(
        [users(:f_mentor)],
        [users(:student_3), users(:mkr_student)])
    end
    assert g.errors.empty?

    g.reload
    assert g.has_member?(users(:f_mentor))
    assert g.has_member?(users(:mkr_student))
    assert g.has_member?(users(:student_3))

    assert_no_difference 'Connection::Membership.count' do
      assert g.update_members(
        [users(:f_mentor)],
        [users(:student_4), users(:student_6)])
    end

    # All members must be active.
    assert_equal [Connection::Membership::Status::ACTIVE],
      g.memberships.collect(&:status).uniq

    assert_no_difference 'Connection::Membership.count' do
      assert_false g.update_members([users(:f_mentor)], [])
    end

    assert g.errors[:students]

    g.reload
    assert g.has_member?(users(:f_mentor))
    assert g.has_member?(users(:student_4))
    assert g.has_member?(users(:student_6))

    users(:mentor_4).update_attribute :max_connections_limit, 1

    assert_no_difference 'Connection::Membership.count' do
      assert_false g.update_members(
        [users(:mentor_4)],
        [users(:student_4), users(:student_6)])
    end

    assert_false g.valid?
    g.reload
    assert g.has_member?(users(:f_mentor))
    assert g.has_member?(users(:student_4))
    assert g.has_member?(users(:student_6))

    g.mentors = [users(:f_mentor)]
    g.students = [users(:mkr_student)]
    g.save!
  end
end