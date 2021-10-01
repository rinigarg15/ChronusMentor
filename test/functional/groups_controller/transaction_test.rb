require_relative './../../test_helper.rb'

class GroupsController::TransactionTest < ActionController::TestCase
  tests GroupsController

  def test_update_add_member_error_invalid_member
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2, true)
    @user = users(:f_student)
    @mentor = users(:f_mentor)
    @program = programs(:albers)
    @group = create_group(:students => [@user], :mentor => @mentor, :program => @program)

    current_user_is :f_admin
    allow_one_to_many_mentoring_for_program(@program)
    assert_false @group.has_member?(users(:mentor_3))
    program_roles = @program.roles.group_by(&:name)
    assert_no_difference('RecentActivity.count') do
      assert_no_emails do
        post :update, xhr: true, params: {
          :id => @group.id,
          :connection => {
            :users => {
              users(:student_3).id.to_s => {"'id'"=>users(:student_3).id.to_s, "'role_id'"=>program_roles[RoleConstants::MENTOR_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""},
              users(:student_4).id.to_s => {"'id'"=>users(:student_3).id.to_s, "'role_id'"=>program_roles[RoleConstants::STUDENT_NAME].first.id.to_s, "'action_type'"=>"ADD", "'option'"=>"0", "'replacement_id'"=>""}
            }
          }
        }
      end
    end

    assert_response :success
    @group.reload
    assert_false @group.has_member?(users(:student_3))
    assert_equal [@mentor], @group.mentors
    assert_equal [@user], @group.students
  end
end