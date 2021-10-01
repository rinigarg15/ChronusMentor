require_relative './../../../../test_helper.rb'

class ProgramSettingsExporterTest < ActiveSupport::TestCase

  def test_program_settings_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    settings_exporter = SettingsExporter.new(program, program_exporter)
    settings_folder_path = solution_pack.base_path+SettingsExporter::FolderName
    Dir.mkdir(settings_folder_path) unless File.exist?(settings_folder_path)
    program_settings_exporter = ProgramSettingsExporter.new(program, settings_exporter)
    program_settings_exporter.export

    program_attributes = program.attributes
    columns_for_export = ProgramSettingsExporter::SettingAttributes
    attr_accessors_for_export = ProgramSettingsExporter::AttrAccessors
    data_for_export = []
    columns_for_export.each do |column_name|
      column_value = program_attributes[column_name]
      data_for_export << (column_value.nil? ? nil : column_value.to_s)
    end
    attr_accessors_for_export.each do |attr_accessor_name|
      data_for_export << program.send(attr_accessor_name)
    end

    exported_attribute_names = []
    exported_attribute_values = []

    assert_equal program_settings_exporter.objs, [program]
    assert_equal program_settings_exporter.file_name, 'program_settings'
    assert_equal program_settings_exporter.program, program
    assert_equal program_settings_exporter.parent_exporter, settings_exporter

    program_settings_file_path = solution_pack.base_path+'settings/program_settings.csv'
    assert File.exist?(program_settings_file_path)
    program_settings_rows = CSV.read(program_settings_file_path)
    exported_attribute_names = program_settings_rows[0]
    exported_attribute_values = program_settings_rows[1]

    assert_equal exported_attribute_names, columns_for_export + attr_accessors_for_export
    assert_equal exported_attribute_values, data_for_export

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end
end