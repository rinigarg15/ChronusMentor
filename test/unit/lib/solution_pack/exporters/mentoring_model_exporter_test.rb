require_relative './../../../../test_helper.rb'

require 'fileutils'

class MentoringModelExporterTest < ActiveSupport::TestCase

  def test_mentoring_model_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    MentoringModelLinkExporter.any_instance.expects(:export)
    mentoring_model_exporter = MentoringModelExporter.new(program, program_exporter)
    mentoring_model_exporter.export

    mentoring_models = program.mentoring_models
    block_identifier_counts = {"#Milestones" => 0, "#Goals" => 0, "#Tasks" => 0, "#Facilitation Messages" => 0}

    assert_equal mentoring_model_exporter.program, program
    assert_equal mentoring_model_exporter.file_name, 'mentoring_model'
    assert_equal mentoring_model_exporter.objs, mentoring_models
    assert_equal mentoring_model_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'mentoring_model/')
    mentoring_models.each do |mentoring_model|
      assert File.exist?(solution_pack.base_path+'mentoring_model/mentoring_model_'+mentoring_model.id.to_s)
    end

    FileUtils.rm_rf(solution_pack.base_path+'mentoring_model/') if File.exist?(solution_pack.base_path+'mentoring_model/')
    File.delete(solution_pack.base_path+'mentoring_model_.csv') if File.exist?(solution_pack.base_path+'mentoring_model_.csv')
  end

  def test_mentoring_model_columns_unchanged
    expected_attribute_names = ["id", "title", "description", "default", "program_id", "mentoring_period", "created_at", "updated_at", "version", "should_sync", "mentoring_model_type", "allow_due_date_edit", "goal_progress_type", "allow_messaging", "allow_forum", "forum_help_text"]
    assert_equal_unordered expected_attribute_names, MentoringModel.attribute_names
  end

  def test_mentoring_model_milestone_template_columns_unchanged
    expected_attribute_names = ["id", "title", "description", "mentoring_model_id", "created_at", "updated_at", "position"]
    assert_equal_unordered expected_attribute_names, MentoringModel::MilestoneTemplate.attribute_names
  end

  def test_mentoring_model_goal_template_columns_unchanged
    expected_attribute_names = ["id", "title", "description", "mentoring_model_id", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, MentoringModel::GoalTemplate.attribute_names
  end

  def test_mentoring_model_task_template_columns_unchanged
    expected_attribute_names = ["id", "mentoring_model_id", "milestone_template_id", "goal_template_id", "required", "title", "description", "duration", "associated_id", "action_item_type", "position", "role_id", "created_at", "updated_at", "specific_date", "action_item_id"]
    assert_equal_unordered expected_attribute_names, MentoringModel::TaskTemplate.attribute_names
  end

  def test_mentoring_model_facilitation_template_columns_unchanged
    expected_attribute_names = ["id", "subject", "message", "send_on", "mentoring_model_id", "milestone_template_id", "created_at", "updated_at", "specific_date"]
    assert_equal_unordered expected_attribute_names, MentoringModel::FacilitationTemplate.attribute_names
  end
end