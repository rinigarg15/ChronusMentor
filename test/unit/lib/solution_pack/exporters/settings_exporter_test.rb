require_relative './../../../../test_helper.rb'

class SettingsExporterTest < ActiveSupport::TestCase

  def test_associated_exporters_for_program
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    program_exporter = ProgramExporter.new(program, solution_pack)
    settings_exporter = SettingsExporter.new(program, program_exporter)
    assert_equal SettingsExporter::AssociatedExporters, settings_exporter.associated_exporters
  end

  def test_associated_exporters_for_portal
    program = programs(:primary_portal)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    program_exporter = ProgramExporter.new(program, solution_pack)
    settings_exporter = SettingsExporter.new(program, program_exporter)
    assert_equal SettingsExporter::CareerDevAssociatedExporters, settings_exporter.associated_exporters
  end
end