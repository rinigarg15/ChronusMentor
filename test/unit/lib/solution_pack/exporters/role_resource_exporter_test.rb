require_relative './../../../../test_helper.rb'

class RoleResourceExporterTest < ActiveSupport::TestCase

  def test_role_resource_export
    program = programs(:albers)
    resource_publications = program.resource_publications
    admin_role = program.roles.find_by(name: "admin")
    role_resource = admin_role.role_resources.new(:resource_publication_id => resource_publications.first.id)
    role_resource.save!

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_resource_exporter = RoleResourceExporter.new(program, program_exporter)
    role_resource_exporter.export

    role_resources = program.roles.collect(&:role_resources).flatten
    exported_role_resource_ids = []

    assert_equal role_resource_exporter.objs, role_resources
    assert_equal role_resource_exporter.file_name, 'role_resource'
    assert_equal role_resource_exporter.program, program
    assert_equal role_resource_exporter.parent_exporter, program_exporter

    role_resource_file_path = solution_pack.base_path+'role_resource.csv'
    assert File.exist?(role_resource_file_path)
    CSV.foreach(role_resource_file_path, headers: true) do |row|
      exported_role_resource_ids << row["id"].to_i
    end
    assert_equal_unordered exported_role_resource_ids, role_resources.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_resource_model_unchanged
    expected_attribute_names = ["id", "role_id", "created_at", "updated_at", "resource_publication_id"]
    assert_equal_unordered expected_attribute_names, RoleResource.attribute_names
  end
end