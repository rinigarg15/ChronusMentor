require_relative './../test_helper.rb'

class PasswordTest < ActiveSupport::TestCase
  def test_create
    assert_difference "Password.count", 2 do
      assert_nothing_raised do
        @password_1 = Password.create!(member: members(:ram))
        @password_2 = Password.create!(email_id: members(:ram).email)
      end
    end
    assert_equal members(:ram), @password_1.member
    assert_nil @password_1.email_id
    assert_not_nil @password_1.reset_code

    assert_equal members(:ram).email, @password_2.email_id
    assert_nil @password_2.member
    assert_not_nil @password_2.reset_code
  end

  def test_validates_presence
    assert_no_difference "Password.count" do
      e = assert_raise ActiveRecord::RecordInvalid do
        Password.create!
      end
      assert_equal "Validation failed: Either member id or email should be present", e.message
      e = assert_raise ActiveRecord::RecordInvalid do
        Password.create!(member_id: members(:f_admin).id, email_id: members(:f_admin).email)
      end
      assert_equal "Validation failed: Either member id or email should be present", e.message
    end
  end

  def test_expired_scope
    assert_equal 0, Password.count

    p1 = Password.create!(:member => members(:f_admin))
    p2 = Password.create!(:member => members(:f_mentor))
    assert_blank Password.expired

    p1.update_attribute(:expiration_date, 1.day.ago)
    assert_equal [p1], Password.expired

    p2.update_attribute(:expiration_date, 3.days.ago)
    assert_equal [p1, p2], Password.expired
  end

  def test_destroy_expired
    assert_equal 0, Password.count

    p1 = Password.create!(:member => members(:f_admin))
    p2 = Password.create!(:member => members(:f_mentor))
    assert_blank Password.expired

    assert_no_difference('Password.count') do
      Password.destroy_expired
    end

    p1.update_attribute(:expiration_date, 1.day.ago)
    assert_equal [p1], Password.expired


    assert_difference('Password.count', -1) do
      Password.destroy_expired
    end

    assert_blank Password.expired
    assert_equal [p2], Password.all
  end
end
