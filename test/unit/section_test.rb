require_relative './../test_helper.rb'

class SectionTest < ActiveSupport::TestCase
  def test_check_default_section_position_and_number
    sections(:section_albers).position = 2
    sections(:section_albers).default_field = true
    assert_false sections(:section_albers).valid?
    assert_equal sections(:section_albers).errors[:position], ["cannot reposition default section"]
    sec = programs(:org_primary).sections.new(:title => "Gen", :organization => programs(:org_primary), :position => 1, :default_field => true)
    assert_false sec.valid?
    assert_equal sec.errors[:default_field], ["cannot be more than one"]
  end
end
