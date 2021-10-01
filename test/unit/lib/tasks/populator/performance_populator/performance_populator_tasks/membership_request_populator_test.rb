require_relative './../../../../../../test_helper'

class MembershipRequestPopulatorTest < ActiveSupport::TestCase
  def test_add_membership_requests
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = MembershipRequest.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("membership_request", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end

  def test_add_membership_requests_for_portal
    org = programs(:org_nch)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = MembershipRequest.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("membership_request", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end
end