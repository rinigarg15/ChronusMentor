require_relative './../../../../../../test_helper'

class EmailEventLogPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_email_event_logs
    program = programs(:albers)
    to_add_admin_message_ids = program.admin_messages.where("campaign_message_id IS NOT NULL").pluck(:id).first(5)
    to_remove_admin_message_ids = CampaignManagement::EmailEventLog.pluck(:message_id).uniq.last(5)
    populator_add_and_remove_objects("email_event_log", "admin_message", to_add_admin_message_ids, to_remove_admin_message_ids, {program: program, model: "campaign_management/email_event_log"})
  end
end