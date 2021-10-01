require_relative '../test_helper'

class LoginTokenTest < ActiveSupport::TestCase
  def test_validations
    login_token = LoginToken.new
    assert_false login_token.valid?
    assert_equal ["can't be blank"], login_token.errors.messages[:member_id]

    login_token.member_id = members(:f_mentor).id
    assert login_token.valid?
  end

  def test_set_token_code
    LoginToken.expects(:make_token).returns("unique_token")
    login_token = LoginToken.new(member: members(:f_mentor))
    login_token.save
    assert_equal "unique_token", login_token.token_code
  end

  def test_expired
    login_token = LoginToken.first
    login_token.expects(:created_at).returns(5.hours.ago)
    assert_false login_token.expired?
    login_token.expects(:created_at).returns(2.days.ago)
    assert login_token.expired?
    login_token.expects(:created_at).returns(5.hours.ago)
    login_token.update_column(:last_used_at, Time.now)
    assert login_token.expired?
  end

  def test_mark_expired
    time = Time.now
    Time.stubs(:now).returns(time)
    login_token = LoginToken.first
    assert_nil login_token.last_used_at
    login_token.mark_expired
    assert_equal time.utc.to_s, login_token.last_used_at.utc.to_s
  end

end