require_relative './../../../../test_helper.rb'

class CalendarSettingExporterTest < ActiveSupport::TestCase

  def test_calendar_setting_export
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
    calendar_setting_exporter = CalendarSettingExporter.new(program, settings_exporter)
    calendar_setting_exporter.export

    calendar_setting_attributes = program.calendar_setting.attributes
    columns_for_export = CalendarSettingExporter::SettingAttributes
    data_for_export = []
    columns_for_export.each do |column_name|
      column_value = calendar_setting_attributes[column_name]
      data_for_export << (column_value.nil? ? nil : column_value.to_s)
    end

    exported_attribute_names = []
    exported_attribute_values = []

    assert_equal calendar_setting_exporter.objs, [program.calendar_setting]
    assert_equal calendar_setting_exporter.file_name, 'calendar_setting'
    assert_equal calendar_setting_exporter.program, program
    assert_equal calendar_setting_exporter.parent_exporter, settings_exporter

    calendar_setting_file_path = solution_pack.base_path+'settings/calendar_setting.csv'
    assert File.exist?(calendar_setting_file_path)
    calendar_setting_rows = CSV.read(calendar_setting_file_path)
    exported_attribute_names = calendar_setting_rows[0]
    exported_attribute_values = calendar_setting_rows[1]

    assert_equal exported_attribute_names, columns_for_export
    assert_equal exported_attribute_values, data_for_export

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end
end