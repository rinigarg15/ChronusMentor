require_relative './../../../test_helper.rb'

class ChronusAbTestSplitUserTest < ActiveSupport::TestCase
  def test_ab_user
    Split::User.stubs(:new).with(self).returns("something")
    assert_equal "something", ChronusAbTestSplitUser.new(self).send(:ab_user)
  end

  def test_alternative_choosen
    ChronusAbTestSplitUser.any_instance.stubs(:ab_user).returns({"something" => "nothing"})
    assert_equal "nothing", ChronusAbTestSplitUser.new("self").alternative_choosen("something")

    ChronusAbTestSplitUser.any_instance.stubs(:ab_user).raises("Some Exception")
    Airbrake.stubs(:notify).once
    assert_nil ChronusAbTestSplitUser.new("self").alternative_choosen("something")
  end

  private

  def current_member_or_cookie
    "self"
  end
end