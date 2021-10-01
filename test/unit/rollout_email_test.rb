require_relative './../test_helper.rb'

class RolloutEmailTest < ActiveSupport::TestCase
  def test_belongs_to_ref_obj
    re = RolloutEmail.create!(ref_obj: users(:f_admin))
    assert_equal users(:f_admin), re.ref_obj
  end

  def test_ref_obj_presence
    re = RolloutEmail.create
    assert_equal ["can't be blank"], re.errors[:ref_obj]
  end

  def test_email_id_is_valid
    re = RolloutEmail.create(ref_obj: users(:f_admin), email_id: "some random string")
    assert_equal ["is not included in the list"], re.errors[:email_id]
    re2 = RolloutEmail.create(ref_obj: users(:f_admin), email_id: ForgotPassword.mailer_attributes[:uid])
    assert re2.valid?
  end

  def test_action_type_validation
    re = RolloutEmail.create(ref_obj: users(:f_admin), email_id: ForgotPassword.mailer_attributes[:uid], action_type: 6)
    assert_equal ["is not included in the list"], re.errors[:action_type]
    re2 = RolloutEmail.create(ref_obj: users(:f_admin), email_id: ForgotPassword.mailer_attributes[:uid], action_type: RolloutEmail::ActionType::UPDATE_ALL_NON_CUSTOMIZED)
    assert re2.valid?
  end
end