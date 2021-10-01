require_relative './../../../../test_helper.rb'

class AdminViewExporterTest < ActiveSupport::TestCase

  def test_admin_view_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    AdminViewColumnExporter.any_instance.expects(:export)
    admin_view_exporter = AdminViewExporter.new(program, program_exporter)
    admin_view_exporter.export

    admin_views = program.admin_views
    admin_view_columns = AdminViewColumn.where("admin_view_id IN (?)", admin_views.collect(&:id))
    exported_admin_view_ids = []

    assert_equal admin_view_exporter.objs, admin_views
    assert_equal admin_view_exporter.file_name, 'admin_view'
    assert_equal admin_view_exporter.program, program
    assert_equal admin_view_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'admin_view.csv')
    CSV.foreach(solution_pack.base_path+'admin_view.csv', headers: true) do |row|
      exported_admin_view_ids << row["id"].to_i
    end
    assert_equal_unordered exported_admin_view_ids, admin_views.collect(&:id)

    File.delete(solution_pack.base_path+'admin_view.csv') if File.exist?(solution_pack.base_path+'admin_view.csv')
  end

  def test_admin_view_model_unchanged
    expected_attribute_names = ["id", "title", "program_id", "filter_params", "default_view", "created_at", "updated_at", "description", "type", "favourite", "favourited_at", "role_id"]
    assert_equal_unordered expected_attribute_names, AdminView.attribute_names
  end
end