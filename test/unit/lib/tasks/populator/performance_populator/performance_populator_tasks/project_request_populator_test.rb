require_relative './../../../../../../test_helper'

class ProjectRequestPopulatorTest < ActiveSupport::TestCase
  def test_add_project_requests
    program = programs(:albers)
    program.update_attributes(:engagement_type => Program::EngagementType::PROJECT_BASED)
    program.groups.update_all(:status => Group::Status::PENDING)
    to_add_sender_ids = program.users.select{|user| user.is_student?}.collect(&:id)
    to_remove_sender_ids = program.project_requests.pluck(:sender_id).uniq.last(5)
    populator_add_and_remove_objects("project_request", "student", to_add_sender_ids, to_remove_sender_ids, {program: program})
  end
end