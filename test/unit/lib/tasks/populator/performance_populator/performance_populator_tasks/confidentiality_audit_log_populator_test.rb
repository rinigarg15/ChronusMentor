require_relative './../../../../../../test_helper'

class ConfidentialityAuditLogPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_confidentiality_audit_logs
    program = programs(:albers)
    to_add_group_ids = program.groups.pluck(:id).first(5)
    to_remove_group_ids = program.confidentiality_audit_logs.pluck(:group_id).uniq.last(5)
    populator_add_and_remove_objects("confidentiality_audit_log", "group", to_add_group_ids, to_remove_group_ids, {program: program})
  end
end