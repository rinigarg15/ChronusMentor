require_relative './../../test_helper.rb'

class LocalizationHelperTest < ActionView::TestCase
  def test_calculate_program_score
    score_hash = {Organization.first.id => [5, 10], Organization.first(2).last.id => [0, 0]}
    assert_equal 50, calculate_program_score(score_hash, Organization.first)
    assert_equal 0, calculate_program_score(score_hash, Organization.first(2).last)
  end
end