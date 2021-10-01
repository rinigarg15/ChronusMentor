require_relative './../../test_helper.rb'

class MentoringModel::ActivityTest < ActiveSupport::TestCase
  def test_validate_connection_membership
    assert_no_difference 'MentoringModel::Activity.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :connection_membership) do
        goal = create_mentoring_model_goal
        goal.goal_activities.create!(:message => "Message")
      end
    end
  end

  def test_validate_ref_obj
    membership = Connection::Membership.first
    assert_no_difference 'MentoringModel::Activity.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :ref_obj) do
        activity = MentoringModel::Activity.new(:message => "Message", :connection_membership => membership)
        activity.member_id = membership.user.member_id
        activity.save!
      end
    end
  end
end
