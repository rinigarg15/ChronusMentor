require_relative './../../test_helper.rb'

class GroupUserSplitterTest < ActiveSupport::TestCase

  def test_split_users_by_roles_and_options
    group_setup
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.default_mentoring_model
    
    assert_equal 2, @group.members.count
    assert_equal 1, @group.mentors.count
    assert_equal 1, @group.students.count

    teacher_role = create_role(name: "teacher", for_mentoring: true)
    new_teacher = users(:f_admin)
    new_teacher.roles += [teacher_role]
    new_teacher.save!

    program_roles = program.roles.group_by(&:name)
    group_params = {
        users(:mentor_5).id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>users(:mentor_5).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"1", "'replacement_id'"=>""}},
        users(:student_4).id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>users(:student_4).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}},
        @user.id.to_s => {program_roles[RoleConstants::STUDENT_NAME].first.id.to_s => {"'id'"=>@group.students.first.id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"REMOVE", "'option'"=>"0", "'replacement_id'"=>""}},
        @mentor.id.to_s => {program_roles[RoleConstants::MENTOR_NAME].first.id.to_s => {"'id'"=>@mentor.id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"REPLACE", "'option'"=>"", "'replacement_id'"=>users(:mentor_3).id.to_s}},
        users(:f_admin).id.to_s => {teacher_role.id.to_s => {"'id'"=>users(:f_admin).id.to_s, "'role_id'"=>teacher_role.id.to_s, "'action_type'"=>"ADD", "'option'"=>"1", "'replacement_id'"=>""}}
    }

    members_by_roles = GroupUserSplitter.new(program, @group, group_params).split_users_by_roles_and_options
    assert_equal members_by_roles[0], [users(:mentor_5), users(:mentor_3)]
    assert_equal members_by_roles[1], [users(:student_4)]
    options = members_by_roles[2]
    assert_equal({teacher_role => [users(:f_admin)]}, options[:other_roles_hash])
    assert_equal [users(:mentor_5).id, users(:f_admin).id], options[:new_members_with_no_default_tasks]
    assert_equal [@user.id], options[:removed_members_with_tasks_removed]
    assert_equal({@mentor.id => users(:mentor_3).id}, options[:replaced_members_list])
  end

  private

  def group_setup
    @user = users(:f_student)
    @mentor = users(:f_mentor)
    @program = programs(:albers)
    @group = create_group(:students => @user, :mentor => @mentor, :program => @program)
  end
end