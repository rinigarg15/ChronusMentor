require_relative './../test_helper.rb'

class SubscriptionTest < ActiveSupport::TestCase
  def test_validate_user_unique_for_ref_obj
    assert_difference 'Subscription.count' do
      Subscription.create! :ref_obj => forums(:forums_1), :user => users(:f_mentor_student)
    end

    assert_no_difference 'RoleReference.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user_id do
        Subscription.create! :ref_obj => forums(:forums_1), :user => users(:f_mentor_student)
      end
    end
  end
end
