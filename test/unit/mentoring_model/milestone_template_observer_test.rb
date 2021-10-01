require_relative './../../test_helper.rb'

class MentoringModel::MilestoneTemplateObserverTest < ActiveSupport::TestCase
  def test_increament_template_version_after_save
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @milestone_template = @mentoring_model.mentoring_model_milestone_templates.create!(title: "Hello1", description: "Hello1Desc")
    end
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @milestone_template.title = "Hello2"
      @milestone_template.save!
    end
  end

  def test_increament_template_version_after_destroy
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
    milestone_template = @mentoring_model.mentoring_model_milestone_templates.create!(title: "Hello1", description: "Hello1Desc")
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      milestone_template.destroy
    end
  end
end