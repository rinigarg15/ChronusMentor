require_relative './../test_helper.rb'

class FacilitationDeliveryLogTest < ActiveSupport::TestCase
  def test_user_and_facilitation_message_required
    assert_multiple_errors([{:field => :facilitation_delivery_loggable}, {:field => :facilitation_delivery_loggable_type}, {:field => :user}]) do
      assert_no_difference 'FacilitationDeliveryLog.count' do
        FacilitationDeliveryLog.create!
      end
    end
  end

end
