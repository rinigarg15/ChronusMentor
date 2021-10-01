require_relative './../../../../test_helper.rb'

class AdminViewColumnExporterTest < ActiveSupport::TestCase

  def test_admin_view_column_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    admin_view_exporter = AdminViewExporter.new(program, program_exporter)
    admin_view_column = admin_view_columns(:admin_view_columns_169)
    profile_question = ProfileQuestion.new(
                          id: 125,
                          organization_id: 1,
                          question_text: "Test Question",
                          question_type: 14,
                          position: 6,
                          section_id: 1,
                          allow_other_option: false,
                          profile_answers_count: 0,
                          text_only_option: false
                        )
    admin_view_column.update_attributes(profile_question_id: profile_question.id)
    admin_view_column_exporter = AdminViewColumnExporter.new(program, admin_view_exporter)
    admin_view_column_exporter.export

    admin_views = program.admin_views
    admin_view_columns = AdminViewColumn.where("admin_view_id IN (?)", admin_views.collect(&:id)).where.not(id: admin_view_column.id)
    exported_admin_view_column_ids = []
    assert_equal_unordered admin_view_column_exporter.objs, admin_view_columns
    assert_equal admin_view_column_exporter.file_name, 'admin_view_column'
    assert_equal admin_view_column_exporter.program, program
    assert_equal admin_view_column_exporter.parent_exporter, admin_view_exporter

    assert File.exist?(solution_pack.base_path+'admin_view_column.csv')
    CSV.foreach(solution_pack.base_path+'admin_view_column.csv', headers: true) do |row|
      exported_admin_view_column_ids << row["id"].to_i
    end
    assert_equal_unordered exported_admin_view_column_ids, admin_view_columns.collect(&:id)

    File.delete(solution_pack.base_path+'admin_view_column.csv') if File.exist?(solution_pack.base_path+'admin_view_column.csv')
  end

  def test_admin_view_column_model_unchanged
    expected_attribute_names = ["id", "admin_view_id", "profile_question_id", "column_key", "position", "created_at", "updated_at", "column_sub_key"]
    assert_equal_unordered expected_attribute_names, AdminViewColumn.attribute_names
  end
end