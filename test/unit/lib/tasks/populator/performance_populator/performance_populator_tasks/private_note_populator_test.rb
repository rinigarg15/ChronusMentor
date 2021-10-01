require_relative './../../../../../../test_helper'

class PrivateNotePopulatorTest < ActiveSupport::TestCase
  def test_add_private_notes
    program = programs(:albers)
    to_add_connection_membership_ids = program.connection_memberships.pluck(:id).first(5)
    to_remove_connection_membership_ids = Connection::PrivateNote.pluck(:ref_obj_id).uniq.last(5)
    populator_add_and_remove_objects("private_note", "connection_membership", to_add_connection_membership_ids, to_remove_connection_membership_ids, {program: program, model: "connection/private_note"})
  end
end