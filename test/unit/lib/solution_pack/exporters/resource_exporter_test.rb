require_relative './../../../../test_helper.rb'

class ResourceExporterTest < ActiveSupport::TestCase

  def test_resource_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    ResourcePublicationExporter.any_instance.expects(:export).once

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    resource_exporter = ResourceExporter.new(program, program_exporter)
    resource_exporter.export

    resources = program.resource_publications.collect(&:resource)
    exported_resource_ids = []

    assert_equal resource_exporter.objs, resources
    assert_equal resource_exporter.file_name, 'resource'
    assert_equal resource_exporter.program, program
    assert_equal resource_exporter.parent_exporter, program_exporter

    resource_file_path = solution_pack.base_path+'resource.csv'

    assert File.exist?(resource_file_path)
    CSV.foreach(resource_file_path, headers: true) do |row|
      exported_resource_ids << row["id"].to_i
    end
    assert_equal_unordered exported_resource_ids, resources.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_resource_model_unchanged
    expected_attribute_names = ["id", "program_id", "title", "content", "created_at", "updated_at", "default", "view_count"]
    assert_equal_unordered expected_attribute_names, Resource.attribute_names
  end
end