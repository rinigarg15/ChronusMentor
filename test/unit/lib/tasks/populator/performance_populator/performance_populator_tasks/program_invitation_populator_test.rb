require_relative './../../../../../../test_helper'

class ProgramInvitationPopulatorTest < ActiveSupport::TestCase
  def test_add_resources
    org = programs(:org_primary)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = ProgramInvitation.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("program_invitation", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end

  def test_add_program_invitations_for_portal
    org = programs(:org_nch)
    to_add_program_ids = org.programs.pluck(:id).first(5)
    to_remove_program_ids = ProgramInvitation.pluck(:program_id).uniq.last(5)
    populator_add_and_remove_objects("program_invitation", "program", to_add_program_ids, to_remove_program_ids, {organization: org})
  end
end