require_relative './../../test_helper.rb'

class MentoringModelCommonHelperTest < ActiveSupport::TestCase
  include MentoringModelCommonHelper

  def test_get_all_mentoring_models
    program = programs(:albers)
    mentoring_models = get_all_mentoring_models(program)
    assert_equal program.mentoring_models.count, mentoring_models.size
    assert mentoring_models.first.has_attribute?(:id)
    assert mentoring_models.first.has_attribute?(:title)
    assert mentoring_models.first.has_attribute?(:default)
  end
end