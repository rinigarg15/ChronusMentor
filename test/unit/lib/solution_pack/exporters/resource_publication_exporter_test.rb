require_relative './../../../../test_helper.rb'

class ResourcePublicationExporterTest < ActiveSupport::TestCase

  def test_resource_publication_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    RoleResourceExporter.any_instance.expects(:export).once

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    resource_publication_exporter = ResourcePublicationExporter.new(program, program_exporter)
    resource_publication_exporter.export

    resource_publications = program.resource_publications
    exported_resource_publication_ids = []

    assert_equal resource_publication_exporter.objs, resource_publications
    assert_equal resource_publication_exporter.file_name, 'resource_publication'
    assert_equal resource_publication_exporter.program, program
    assert_equal resource_publication_exporter.parent_exporter, program_exporter

    resource_publication_file_path = solution_pack.base_path+'resource_publication.csv'

    assert File.exist?(resource_publication_file_path)
    CSV.foreach(resource_publication_file_path, headers: true) do |row|
      exported_resource_publication_ids << row["id"].to_i
    end
    assert_equal_unordered exported_resource_publication_ids, resource_publications.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_resource_publication_model_unchanged
    expected_attribute_names = ["id", "program_id", "resource_id", "position", "created_at", "updated_at", "show_in_quick_links", "admin_view_id"]
    assert_equal_unordered expected_attribute_names, ResourcePublication.attribute_names
  end
end