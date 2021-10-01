require_relative './../../../../test_helper.rb'

class RoleExporterTest < ActiveSupport::TestCase

  def test_role_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_exporter = RoleExporter.new(program, program_exporter)
    role_exporter.export

    roles = program.roles
    exported_role_ids = []

    assert_equal_unordered role_exporter.objs, roles
    assert_equal role_exporter.file_name, 'role'
    assert_equal role_exporter.program, program
    assert_equal role_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'role.csv')
    CSV.foreach(solution_pack.base_path+'role.csv', headers: true) do |row|
      exported_role_ids << row["id"].to_i
    end
    assert_equal_unordered exported_role_ids, roles.collect(&:id)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_model_unchanged
    expected_attribute_names = ["id", "name", "program_id", "created_at", "updated_at", "default", "join_directly", "membership_request", "invitation", "join_directly_only_with_sso", "administrative", "for_mentoring", "description", "eligibility_rules", "eligibility_message", "can_be_added_by_owners", "slot_config", "max_connections_limit"]
    assert_equal_unordered expected_attribute_names, Role.attribute_names
  end
end