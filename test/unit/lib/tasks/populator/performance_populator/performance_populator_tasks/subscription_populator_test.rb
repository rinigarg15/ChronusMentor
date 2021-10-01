require_relative './../../../../../../test_helper'

class SubscriptionPopulatorTest < ActiveSupport::TestCase
  def test_add_subscriptions
    program = programs(:albers)
    to_add_user_ids = program.mentor_users.active.pluck(:id).first(5)
    to_add_user_ids -= program.student_users.where(:id => to_add_user_ids).pluck(:id)
    to_remove_user_ids = Subscription.pluck(:user_id).uniq.last(5)
    populator_add_and_remove_objects("subscription", "user", to_add_user_ids, to_remove_user_ids, {program: program})
  end

  def test_add_subscriptions_for_portal
    user = users(:portal_employee)
    user.subscriptions.destroy_all
    program = programs(:primary_portal)
    create_forum(program: program, name: "Test Forum", access_role_names: [:employee])
    to_add_user_ids = program.reload.employee_users.active.pluck(:id).first(5)
    to_remove_user_ids = Subscription.pluck(:user_id).uniq.last(5)
    populator_add_and_remove_objects("subscription", "user", to_add_user_ids, to_remove_user_ids, {program: program})
  end
end