require_relative './../../../../test_helper.rb'

class RolePermissionExporterTest < ActiveSupport::TestCase

  def test_role_permission_export_without_write_article
    program = programs(:albers)
    program.roles_applicable_for_auto_approval.map do |role|
      role.add_permission("become_#{RoleConstants::AUTO_APPROVAL_ROLE_MAPPING[role.name]}")
    end
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    PermissionExporter.any_instance.expects(:export)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_exporter = RoleExporter.new(program, program_exporter)
    role_permission_exporter = RolePermissionExporter.new(program, role_exporter)
    role_permission_exporter.export

    invite_permission_names = program.roles.map{|role| "invite_#{role.name.pluralize}"}
    add_role_permission_names = ["become_mentor", "become_student"]
    role_permissions = program.roles_without_admin_role.collect(&:role_permissions).flatten.select{|rp| invite_permission_names.include?(rp.permission.name) || add_role_permission_names.include?(rp.permission.name)}
    exported_role_permission_ids = []

    assert_equal role_permission_exporter.objs, role_permissions
    assert_equal role_permission_exporter.file_name, 'role_permission'
    assert_equal role_permission_exporter.program, program
    assert_equal role_permission_exporter.parent_exporter, role_exporter

    role_permission_file_path = solution_pack.base_path+'role_permission.csv'

    assert File.exist?(role_permission_file_path)
    CSV.foreach(role_permission_file_path, headers: true) do |row|
      exported_role_permission_ids << row["id"].to_i
    end
    assert_equal_unordered exported_role_permission_ids, role_permissions.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_permission_export_with_write_article
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    PermissionExporter.any_instance.expects(:export)
    program.add_role_permission(RoleConstants::STUDENT_NAME, "write_article")

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_exporter = RoleExporter.new(program, program_exporter)
    role_permission_exporter = RolePermissionExporter.new(program, role_exporter)
    role_permission_exporter.export

    invite_permission_names = program.roles.map{|role| "invite_#{role.name.pluralize}"}
    role_permissions = program.roles_without_admin_role.collect(&:role_permissions).flatten.select{|rp| invite_permission_names.include?(rp.permission.name)}
    role_permissions += program.get_role(RoleConstants::STUDENT_NAME).role_permissions.select{|rp| rp.permission.name == "write_article"}
    exported_role_permission_ids = []

    assert_equal role_permission_exporter.objs, role_permissions
    assert_equal role_permission_exporter.file_name, 'role_permission'
    assert_equal role_permission_exporter.program, program
    assert_equal role_permission_exporter.parent_exporter, role_exporter

    role_permission_file_path = solution_pack.base_path+'role_permission.csv'

    assert File.exist?(role_permission_file_path)
    CSV.foreach(role_permission_file_path, headers: true) do |row|
      exported_role_permission_ids << row["id"].to_i
    end
    assert_equal_unordered exported_role_permission_ids, role_permissions.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_permission_export_with_write_article_for_portal
    program = programs(:primary_portal)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    PermissionExporter.any_instance.expects(:export)
    program.add_role_permission(RoleConstants::EMPLOYEE_NAME, "write_article")

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    role_exporter = RoleExporter.new(program, program_exporter)
    role_permission_exporter = RolePermissionExporter.new(program, role_exporter)
    role_permission_exporter.export

    invite_permission_names = program.roles.map{|role| "invite_#{role.name.pluralize}"}
    role_permissions = program.roles_without_admin_role.collect(&:role_permissions).flatten.select{|rp| invite_permission_names.include?(rp.permission.name)}
    role_permissions += program.get_role(RoleConstants::EMPLOYEE_NAME).role_permissions.select{|rp| rp.permission.name == "write_article"}
    exported_role_permission_ids = []

    assert_equal role_permission_exporter.objs, role_permissions
    assert_equal role_permission_exporter.file_name, 'role_permission'
    assert_equal role_permission_exporter.program, program
    assert_equal role_permission_exporter.parent_exporter, role_exporter

    role_permission_file_path = solution_pack.base_path+'role_permission.csv'

    assert File.exist?(role_permission_file_path)
    CSV.foreach(role_permission_file_path, headers: true) do |row|
      exported_role_permission_ids << row["id"].to_i
    end
    assert_equal_unordered exported_role_permission_ids, role_permissions.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_permission_model_unchanged
    expected_attribute_names = ["id", "role_id", "permission_id", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, RolePermission.attribute_names
  end
end