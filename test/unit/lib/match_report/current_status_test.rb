require_relative './../../../test_helper'

class CurrentStatusTest < ActiveSupport::TestCase

  def test_initialize
    program = programs(:albers)
    current_time = Time.now
    graph_data = {first: 'current_stat'}
    Program.any_instance.expects(:set_current_status_graph_data).once.returns(graph_data)
    current_status_object = nil
    Timecop.freeze(current_time) do
      current_status_object = MatchReport::CurrentStatus.new(programs(:albers))
    end
    assert_equal program, current_status_object.program
    assert_equal program.created_at, current_status_object.startDate
    assert_equal graph_data, current_status_object.graphData
    assert_equal current_time.to_i, current_status_object.endDate.to_i
  end

end