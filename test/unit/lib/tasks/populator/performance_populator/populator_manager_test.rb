require_relative './../../../../../test_helper'

class PopulatorManagerTest < ActiveSupport::TestCase
  POPULATOR_SPEC = 'lib/populator_v3/config/spec_config.yml'
  TEST_SPEC_FILE = 'test/populator_fixtures/files/perf_populator_spec_config.yml'
  def test_initialize
    perf_populator = load_populator_manager_test(POPULATOR_SPEC, TEST_SPEC_FILE)
    assert_not_nil perf_populator.nodes
    assert_equal 85, perf_populator.nodes.keys.size
  end

  def test_build_graph_and_traverse
    perf_populator = load_populator_manager_test(POPULATOR_SPEC, TEST_SPEC_FILE)
    perf_populator.build_graph
    assert_not_nil perf_populator.graph
    perf_populator.build_traverse_order
    assert_equal perf_populator.nodes.keys.size - 3, perf_populator.traverse_order.size
    assert_equal perf_populator.graph["organization"], ["member", "program", "section", "profile_question", "three_sixty_question", "three_sixty_reviewer_group", "three_sixty_competency"]
  end

  def test_fill_organizations_and_programs
    PopulatorManager.any_instance.stubs(:fill_programs).returns(true)
    org3 = mock() 
    org4 = mock()
    org3.stubs(:subdomain).returns("small3")
    org4.stubs(:subdomain).returns("small4")
    PopulatorManager.any_instance.stubs(:populator_for_each_organization).returns(true)
    perf_populator = load_populator_manager_test(POPULATOR_SPEC, TEST_SPEC_FILE)
    perf_populator.build_graph
    perf_populator.build_traverse_order
    assert_nothing_raised do
      @categorized_organizations = {"huge"=>[], "medium"=>[], "small"=>[]}
      perf_populator.fill_organizations_and_programs()
    end
  end

  def test_parent_visited
    perf_populator = load_populator_manager_test(POPULATOR_SPEC, TEST_SPEC_FILE)
    perf_populator.build_graph
    perf_populator.build_traverse_order
    visited_list = {}
    visited_list["group"] = true
    node = "scrap"
    assert perf_populator.parent_visited(node, visited_list)
    visited_list["group"] = false
    assert_false perf_populator.parent_visited(node, visited_list)
  end
end