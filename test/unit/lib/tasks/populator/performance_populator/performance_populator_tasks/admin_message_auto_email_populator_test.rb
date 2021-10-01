require_relative './../../../../../../test_helper'

class AdminMessageAutoEmailPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_admin_message_auto_emails
    program = programs(:albers)
    to_add_member_ids = program.users.active.pluck(:member_id).first(5)
    admin_message_ids = program.admin_messages.where(:campaign_message_id => nil, auto_email: true) 
    to_remove_member_ids = program.admin_message_receivers.where(:message_id => admin_message_ids).pluck(:member_id).uniq.first(5)

    populator_add_and_remove_objects("admin_message_auto_email", "user", to_add_member_ids, to_remove_member_ids, {program: program, admin_member: program.admin_users.pluck(:member_id).first, model: "admin_message"})   
  end
end