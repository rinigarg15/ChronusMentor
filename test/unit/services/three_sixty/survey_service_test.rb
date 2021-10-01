require_relative './../../../test_helper.rb'

class ThreeSixty::SurveyServiceTest < ActiveSupport::TestCase

  def test_survey_dashboard_without_params
    params = {}
    options = ThreeSixty::SurveyService.new.survey_dashboard(params, "published", programs(:org_primary), nil)
    assert_equal "title", options[:sort_param]
    assert_equal "asc", options[:sort_order]
    assert_equal 1, options[:page]
    assert_equal ThreeSixty::SurveysController::DEFAULT_PER_PAGE, options[:per_page]
    assert_equal 1, options[:filter][:organization_id]
    assert_equal "published", options[:filter][:state]
    assert_equal [{:survey=>[:program]}, :assessee, {:reviewers => :answers} ], options[:includes_list]
    options = ThreeSixty::SurveyService.new.survey_dashboard(params, "drafted", programs(:org_primary), nil)
    assert_equal "drafted", options[:filter][:state]
    assert_equal [:program, :survey_questions, :survey_reviewer_groups,{:survey_assessees => :assessee}], options[:includes_list]
  end

  def test_survey_dashboard_with_params
    params = {}
    params[:sort_order] = "desc"
    params[:sort_param] = "created_at"
    params[:page] = 4
    options = ThreeSixty::SurveyService.new.survey_dashboard(params, "published", programs(:org_primary), nil)
    assert_equal "desc", options[:sort_order]
    assert_equal "created_at", options[:sort_param]
    assert_equal 4, options[:page]
    assert_nil options[:filter][:program_id]
  end

  def test_survey_dashboard_with_program_id
    program = programs(:albers)
    params = {}
    options = ThreeSixty::SurveyService.new.survey_dashboard(params, "published", program.organization, program)
    assert_equal program.id, options[:filter][:program_id]
  end
end