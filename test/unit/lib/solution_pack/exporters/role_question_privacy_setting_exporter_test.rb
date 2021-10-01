require_relative './../../../../test_helper.rb'

class RoleQuestionPrivacySettingExporterTest < ActiveSupport::TestCase

  def test_role_question_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    exported_privacy_setting_ids = []

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    role_question_exporter = RoleQuestionExporter.new(program, profile_question_exporter)
    role_question_privacy_setting_exporter = RoleQuestionPrivacySettingExporter.new(program, role_question_exporter)
    role_question_privacy_setting_exporter.export

    assert_equal_unordered role_question_privacy_setting_exporter.objs, program.role_questions.collect(&:privacy_settings).flatten
    assert_equal role_question_privacy_setting_exporter.file_name, 'role_question_privacy_setting'
    assert_equal role_question_privacy_setting_exporter.program, program
    assert_equal role_question_privacy_setting_exporter.parent_exporter, role_question_exporter

    assert File.exist?(solution_pack.base_path+'role_question_privacy_setting.csv')
    CSV.foreach(solution_pack.base_path+'role_question_privacy_setting.csv', headers: true) do |row|
      exported_privacy_setting_ids << row["id"].to_i
    end

    assert_equal_unordered exported_privacy_setting_ids, program.role_questions.collect(&:privacy_settings).flatten.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_question_privacy_setting_model_unchanged
    expected_attribute_names = ["id", "role_question_id", "role_id", "setting_type", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, RoleQuestionPrivacySetting.attribute_names
  end
end