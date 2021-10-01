require_relative './../../../../../test_helper'

class NestedEsQuery::BaseTest < ActiveSupport::TestCase

  def test_get_filtered_ids
    query = NestedEsQuery::Base.new(Program.first, Time.now, Time.now, ids: [100, 101, 102, 103, 104])
    assert_equal [100, 101, 102, 103, 104], query.filterable_ids

    query.expects(:get_hits).once.returns([100])
    query.expects(:get_inner_hits_map).with(true).once.returns( { 101 => 1, 102 => 2, 103 => 3 } )
    query.expects(:get_inner_hits_map).with(false).once.returns( { 101 => 3, 102 => 2, 103 => 1 } )
    assert_equal [100, 103], query.get_filtered_ids
    assert_equal [101, 102, 103], query.filterable_ids
  end
end