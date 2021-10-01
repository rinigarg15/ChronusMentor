require_relative './../../../../../../test_helper'

class ConnectionAnswerPopulatorTest < ActiveSupport::TestCase
  def test_add_remove_connection_answers
    program = programs(:albers)
    to_add_group_ids = program.groups.pluck(:id).first(5)
    to_remove_group_ids = Connection::Answer.pluck(:group_id).uniq.last(5)
    populator_add_and_remove_objects("connection_answer", "group", to_add_group_ids, to_remove_group_ids, {program: program, model: "connection/answer"})
  end
end