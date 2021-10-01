require_relative './../../../../test_helper.rb'

class CustomizedTermExporterTest < ActiveSupport::TestCase

  def test_customized_term_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    customized_term_exporter = CustomizedTermExporter.new(program, program_exporter)
    customized_term_exporter.export

    customized_terms = program.customized_terms
    exported_customized_terms_ids = []

    assert_equal_unordered customized_term_exporter.objs, customized_terms
    assert_equal customized_term_exporter.file_name, 'customized_term_program'
    assert_equal customized_term_exporter.program, program
    assert_equal customized_term_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'customized_term_program.csv')
    CSV.foreach(solution_pack.base_path+'customized_term_program.csv', headers: true) do |row|
      exported_customized_terms_ids << row["id"].to_i
    end
    assert_equal_unordered exported_customized_terms_ids, customized_terms.collect(&:id)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_customized_term_export_with_role
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_exporter = RoleExporter.new(program, program_exporter)
    customized_term_exporter = CustomizedTermExporter.new(program, role_exporter)
    customized_term_exporter.export

    customized_terms = program.roles.collect(&:customized_term)
    exported_customized_terms_ids = []

    assert_equal_unordered customized_term_exporter.objs, customized_terms
    assert_equal customized_term_exporter.file_name, 'customized_term_role'
    assert_equal customized_term_exporter.program, program
    assert_equal customized_term_exporter.parent_exporter, role_exporter

    assert File.exist?(solution_pack.base_path+'customized_term_role.csv')
    CSV.foreach(solution_pack.base_path+'customized_term_role.csv', headers: true) do |row|
      exported_customized_terms_ids << row["id"].to_i
    end
    assert_equal_unordered exported_customized_terms_ids, customized_terms.collect(&:id)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_customized_term_model_unchanged
    expected_attribute_names = ["id", "ref_obj_id", "ref_obj_type", "term_type", "term", "term_downcase", "pluralized_term", "pluralized_term_downcase", "articleized_term", "articleized_term_downcase", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, CustomizedTerm.attribute_names
  end
end