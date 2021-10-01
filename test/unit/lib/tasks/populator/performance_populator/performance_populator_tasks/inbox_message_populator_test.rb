require_relative './../../../../../../test_helper'

class InboxMessagePopulatorTest < ActiveSupport::TestCase
  def test_add_remove_inbox_messages
    org = programs(:org_primary)
    to_add_member_ids = org.members.pluck(:id).first(5)
    to_remove_member_ids = org.messages.pluck(:sender_id).uniq.first(5)
    populator_add_and_remove_objects("inbox_message", "member", to_add_member_ids, to_remove_member_ids, {organization: org, model: "message", member_ids: to_add_member_ids})
  end
end