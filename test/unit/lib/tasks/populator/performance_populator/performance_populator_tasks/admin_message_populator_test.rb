require_relative './../../../../../../test_helper'

class AdminMessagePopulatorTest < ActiveSupport::TestCase

  def test_add_remove_admin_messages
    program = programs(:albers)
    to_add_member_ids = 5.times.map { |i| members("mentor_#{i}").id }
    admin_message_ids = program.admin_messages.where(campaign_message_id: nil, auto_email: false).pluck(:id)
    to_remove_member_ids = program.admin_message_receivers.where(message_id: admin_message_ids).pluck(:member_id).uniq.first(5)
    populator_add_and_remove_objects("admin_message", "user", to_add_member_ids, to_remove_member_ids, program: program, admin_member: members(:f_admin), auto_email: false)
  end
end