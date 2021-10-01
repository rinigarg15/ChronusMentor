require_relative './../../test_helper.rb'

class EmailRolloutServiceTest < ActiveSupport::TestCase
  def test_rollout_applicable
    uid = ForgotPassword.mailer_attributes[:uid]
    ers = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers.rollout_applicable?(uid)

    programs(:albers).update_attribute(:rollout_enabled, true)
    ers2 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers2.rollout_applicable?(uid)

    t = programs(:albers).mailer_templates.create!(uid: uid)
    ers2 = EmailRolloutService.new(programs(:albers).reload, users(:f_admin))
    assert ers2.rollout_applicable?(uid)

    programs(:albers).actioned_rollout_emails.create!(email_id: uid)
    ers3 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers3.rollout_applicable?(uid)

    programs(:albers).actioned_rollout_emails.destroy_all
    users(:f_admin).dismissed_rollout_emails.create!(email_id: uid)
    ers4 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers4.rollout_applicable?(uid)

    users(:f_admin).dismissed_rollout_emails.destroy_all
    programs(:albers).actioned_rollout_emails.create!
    ers5 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers5.rollout_applicable?(uid)
  end

  def test_show_rollout_update_all
    ers = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers.show_rollout_update_all?

    programs(:albers).update_attribute(:rollout_enabled, true)
    ers2 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert ers2.show_rollout_update_all?

    programs(:albers).actioned_rollout_emails.create!
    ers3 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers3.show_rollout_update_all?

    programs(:albers).actioned_rollout_emails.destroy_all
    users(:f_admin).dismissed_rollout_emails.create!
    ers4 = EmailRolloutService.new(programs(:albers), users(:f_admin))
    assert_false ers4.show_rollout_update_all?
  end
end