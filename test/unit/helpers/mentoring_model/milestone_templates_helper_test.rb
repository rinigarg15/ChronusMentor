require_relative './../../../test_helper.rb'

class MentoringModel::MilestoneTemplatesHelperTest < ActionView::TestCase
  def test_control_class
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    milestone_template = mentoring_model.mentoring_model_milestone_templates.new
    assert_equal "form-control", control_class(milestone_template)

    milestone_template = create_mentoring_model_milestone_template
    assert_equal "form-control", control_class(milestone_template)
  end
end