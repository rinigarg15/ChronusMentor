require_relative './../../test_helper.rb'

class MembershipRequestObserverTest < ActiveSupport::TestCase

  def test_membership_request_create_should_create_a_recent_activity
    membership_request = nil
    ChronusMailer.expects(:membership_request_sent_notification).once.returns(stub(:deliver_now))
    assert_difference "RecentActivity.count" do
      membership_request = create_membership_request
    end

    # The recent activity should be for the admin.
    ra = RecentActivity.last
    assert_equal membership_request.id, ra.ref_obj_id
    assert_equal MembershipRequest.to_s, ra.ref_obj_type
    assert_equal RecentActivityConstants::Type::CREATE_MEMBERSHIP_REQUEST, ra.action_type
    assert_equal RecentActivityConstants::Target::ADMINS, ra.target
    assert_difference "RecentActivity.count", -1 do
      membership_request.destroy
    end
  end

  def test_membership_request_create_should_not_create_a_recent_activity_for_joined_directly
    assert_no_difference "RecentActivity.count" do
      create_membership_request(joined_directly: true)
    end
  end

  def test_membership_request_acceptance
    membership_request = create_membership_request(roles: [RoleConstants::MENTOR_NAME])

    MembershipRequest.expects(:send_membership_request_accepted_notification).once.with(membership_request.id)
    assert_no_difference "User.count" do
      membership_request.update_attributes!(accepted_role_names: [RoleConstants::MENTOR_NAME], status: MembershipRequest::Status::ACCEPTED, admin: users(:f_admin))
    end
    assert_equal [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], users(:f_student).role_names
  end

  def test_membership_request_acceptance_when_existing_member_in_new_program
    membership_request = create_membership_request(member: members(:f_student), roles: [RoleConstants::MENTOR_NAME], program: programs(:ceg))

    MembershipRequest.expects(:send_membership_request_accepted_notification).once.with(membership_request.id)
    assert_difference "User.count" do
      membership_request.update_attributes!(accepted_role_names: [RoleConstants::MENTOR_NAME], status: MembershipRequest::Status::ACCEPTED, admin: users(:f_admin))
    end
    user = User.last
    assert_equal membership_request.email, user.email
    assert_equal [RoleConstants::MENTOR_NAME], user.role_names
  end

  def test_membership_request_rejection
    membership_request = create_membership_request

    MembershipRequest.expects(:send_membership_request_not_accepted_notification).once.with(membership_request.id)
    membership_request.update_attributes(
      status: MembershipRequest::Status::REJECTED,
      response_text: "Sorry",
      admin: users(:f_admin)
    )

    # Saving again should not trigger rejection email delivery.
    MembershipRequest.expects(:send_membership_request_not_accepted_notification).never
    membership_request.save!
  end

  def test_email_is_set_to_member_email_on_update
    member = members(:f_student)
    membership_request = membership_requests(:membership_request_0)
    assert_not_equal member.email, membership_request.email

    membership_request.member = members(:f_student)
    membership_request.save!
    assert_equal member.email, membership_request.reload.email
  end
end