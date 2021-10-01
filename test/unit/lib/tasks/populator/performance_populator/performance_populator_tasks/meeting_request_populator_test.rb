require_relative './../../../../../../test_helper'

class MeetingRequestPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_meeting_requests
    organization = programs(:org_primary)
    program = organization.programs.first
    to_add_ids = [program.id]
    to_del_ids = [program.id]
    populator_add_and_remove_objects("meeting_request", "program", to_add_ids, to_del_ids, {organization: organization, program: program, additional_populator_class_options: {percents_ary: [100], counts_ary: [1]}})
  end
end