require_relative './../../../../test_helper.rb'

class GroupClosureReasonExporterTest < ActiveSupport::TestCase

  def test_group_closure_reason_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    group_closure_reason_exporter = GroupClosureReasonExporter.new(program, program_exporter)
    group_closure_reason_exporter.export

    columns_for_export = GroupClosureReasonExporter::AssociatedModel.constantize.attribute_names
    data_rows_for_export = []
    program.group_closure_reasons.each_with_index do |group_closure_reason, index|
      data_rows_for_export << []
      group_closure_reason_attributes = group_closure_reason.attributes
      columns_for_export.each do |column_name|
        column_value = group_closure_reason_attributes[column_name]
        data_rows_for_export[index] << (column_value.nil? ? nil : column_value.to_s)
      end
    end

    exported_attribute_names = []
    exported_attribute_values = []

    assert_equal group_closure_reason_exporter.objs, program.group_closure_reasons
    assert_equal group_closure_reason_exporter.file_name, 'group_closure_reason'
    assert_equal group_closure_reason_exporter.program, program
    assert_equal group_closure_reason_exporter.parent_exporter, program_exporter

    group_closure_reason_file_path = solution_pack.base_path+'group_closure_reason.csv'
    assert File.exist?(group_closure_reason_file_path)
    group_closure_reason_rows = CSV.read(group_closure_reason_file_path)
    exported_attribute_names = group_closure_reason_rows[0]
    exported_attribute_values = group_closure_reason_rows[1..-1]

    assert_equal exported_attribute_names, columns_for_export
    assert_equal exported_attribute_values, data_rows_for_export
  end

  def test_group_closure_reason_model_unchanged
    expected_attribute_names = ["id", "is_deleted", "is_completed", "is_default", "program_id", "created_at", "updated_at", "reason"]
    assert_equal_unordered expected_attribute_names, GroupClosureReason.attribute_names
  end
end