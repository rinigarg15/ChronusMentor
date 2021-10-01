require_relative './../../../../../../test_helper'

class MentorRequestPopulatorTest < ActiveSupport::TestCase
  def test_add_mentor_requests
    program = programs(:albers)
    to_add_student_ids = program.users.active.includes(:groups).select{|user| user.is_student?}.collect(&:id).first(5)
    to_add_student_ids = to_add_student_ids - program.mentor_requests.where(:status => (AbstractRequest::Status::NOT_ANSWERED || AbstractRequest::Status::ACCEPTED)).pluck(:sender_id)
    to_remove_student_ids = program.mentor_requests.pluck(:sender_id).uniq.last(5)
    populator_add_and_remove_objects("mentor_request", "mentor", to_add_student_ids, to_remove_student_ids, {program: program, mentor_ids: program.users.active.select{|user| user.is_mentor?}.collect(&:id)})
  end
end