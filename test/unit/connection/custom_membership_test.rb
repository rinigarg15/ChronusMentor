require_relative './../../test_helper.rb'

class Connection::CustomMembershipTest < ActiveSupport::TestCase
  def test_user_belongs_to_that_role
    teacher_role = create_role(:name => 'teacher', for_mentoring: true)
    sample_role = create_role(:name => 'sample', for_mentoring: true)
    mentor_user = users(:mentor_3)
    mentor_user.roles += [teacher_role]
    mentor_user.save!
    mentor_user.reload
    custom_membership = nil
    assert_nothing_raised do
      custom_membership = groups(:mygroup).custom_memberships.create!(
        role_id: teacher_role.id,
        user: mentor_user
      )
    end
    custom_membership.role_id = sample_role.id
    assert_raise ActiveRecord::RecordInvalid, "Validation failed: mentor_d chronus cannot be a sample" do
      custom_membership.save!
    end
  end
end
