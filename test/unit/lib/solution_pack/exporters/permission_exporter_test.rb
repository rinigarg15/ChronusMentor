require_relative './../../../../test_helper.rb'

class PermissionExporterTest < ActiveSupport::TestCase

  def test_permission_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_exporter = RoleExporter.new(program, program_exporter)
    role_permission_exporter = RolePermissionExporter.new(program, role_exporter)
    permission_exporter = PermissionExporter.new(program, role_permission_exporter)
    permission_exporter.export

    invite_permission_names = program.roles.map{|role| "invite_#{role.name.pluralize}"}
    role_permissions = program.roles_without_admin_role.collect(&:role_permissions).flatten.select{|rp| invite_permission_names.include?(rp.permission.name)}
    role_permissions += program.get_role(RoleConstants::STUDENT_NAME).role_permissions.select{|rp| rp.permission.name == "write_article"}
    permissions_for_export = role_permissions.collect(&:permission).uniq
    exported_permission_names = []

    assert_equal permission_exporter.objs, permissions_for_export
    assert_equal permission_exporter.file_name, 'permission'
    assert_equal permission_exporter.program, program
    assert_equal permission_exporter.parent_exporter, role_permission_exporter

    permission_file_path = solution_pack.base_path+'permission.csv'

    assert File.exist?(permission_file_path)
    CSV.foreach(permission_file_path, headers: true) do |row|
      exported_permission_names << row["name"]
    end
    assert_equal_unordered exported_permission_names, permissions_for_export.collect(&:name)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end
end