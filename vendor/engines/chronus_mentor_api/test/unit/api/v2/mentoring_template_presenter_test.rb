require_relative './../../../test_helper.rb'

class Api::V2::MentoringTemplatesPresenterTest < ActiveSupport::TestCase
  include AppConstantsHelper

  def setup
    super
    @program = programs(:albers)
    @program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    @mentoring_models = @program.mentoring_models
    @presenter = Api::V2::MentoringTemplatePresenter.new(@program.reload)
  end

  def test_should_success_with_mentor_role
    result = @presenter.list()

    assert_instance_of Hash, result
    assert result[:success]

    assert_instance_of Array, result[:data]
    assert_equal 1, result[:data].size

    @mentoring_models.each_with_index do |mentoring_model, index|
      assert_equal mentoring_model.id, result[:data][index][:id]
      assert_equal mentoring_model.title, result[:data][index][:name]
      assert_dynamic_expected_nil_or_equal mentoring_model.description, result[:data][index][:description]
      assert_equal mentoring_model.mentoring_period, result[:data][index][:duration]
    end
  end
end