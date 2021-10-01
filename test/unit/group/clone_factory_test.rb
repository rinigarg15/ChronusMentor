require_relative './../../test_helper.rb'

class Group::CloneFactoryTest < ActiveSupport::TestCase

  def test_make_clone
    source_group = groups(:rejected_group_1)

    factory = Group::CloneFactory.new(source_group, program: source_group.program)
    cloned_group = factory.clone
    assert_equal source_group.name, cloned_group.name
    assert_equal source_group.memberships.collect{|a| a.user.member.name(name_only: true)}, cloned_group.memberships.collect{|a| a.user.member.name(name_only: true)}
  end

  def test_bulk_make_clone
  	source_group = groups(:rejected_group_1)

    factory = Group::CloneFactory.new(source_group, program: source_group.program, bulk_duplicate: true, clone_mentoring_model: true)
    cloned_group = factory.clone
    assert_equal source_group.name, cloned_group.name
    assert_equal source_group.mentoring_model, cloned_group.mentoring_model
    assert_equal source_group.mentors, cloned_group.mentors
    assert_equal source_group.students, cloned_group.students
    assert_equal source_group.custom_users, cloned_group.custom_users
    assert_equal source_group.mentor_memberships.collect{|a| a.user.member.name(name_only: true)}, cloned_group.mentor_memberships.collect{|a| a.user.member.name(name_only: true)}
    assert_equal source_group.student_memberships.collect{|a| a.user.member.name(name_only: true)}, cloned_group.student_memberships.collect{|a| a.user.member.name(name_only: true)}
    assert_equal source_group.custom_memberships.collect{|a| a.user.member.name(name_only: true)}, cloned_group.custom_memberships.collect{|a| a.user.member.name(name_only: true)}
  end

end