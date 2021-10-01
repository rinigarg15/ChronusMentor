require_relative './../../../../test_helper.rb'

class ExporterTest < ActiveSupport::TestCase
  def test_associated_exporters
    sp = SolutionPack.new
    sp.program = programs(:albers)

    exporter1 = ProgramExporter.new(programs(:albers), sp)
    assert_equal ProgramExporter::AssociatedExporters, exporter1.associated_exporters

    exporter2 = ProgramExporter.new(programs(:primary_portal), sp)
    assert_equal ProgramExporter::CareerDevAssociatedExporters, exporter2.associated_exporters

    role_exporter1 = RoleExporter.new(programs(:albers), exporter1)
    assert_equal RoleExporter::AssociatedExporters, role_exporter1.associated_exporters

    role_exporter2 = RoleExporter.new(programs(:primary_portal), exporter2)
    assert_equal RoleExporter::AssociatedExporters, role_exporter2.associated_exporters
  end

  def test_change_in_associated_exporters
    expected = {
      ProgramExporter =>
        {
          added: ["MentoringModelExporter", "GroupClosureReasonExporter", "OverviewPagesExporter", "ConnectionQuestionExporter"],
          removed: []
        },
      RoleQuestionExporter =>
        {
          added: ["MatchConfigExporter"],
          removed: []
        },
      SettingsExporter =>
        {
          added: ["CalendarSettingExporter"],
          removed: []
        }
    }

    expected.each do |exporter, values|
      assert_equal values[:added], exporter::AssociatedExporters - exporter::CareerDevAssociatedExporters, "Associated Exporters have been added to #{exporter.name}"
      assert_equal values[:removed], exporter::CareerDevAssociatedExporters - exporter::AssociatedExporters, "Associated Exporters have been removed from #{exporter.name}"
    end
  end

  def test_export_contents_with_additional_attributes
    survey = surveys(:two)
    file_path = "#{Rails.root}/tmp/survey-#{Time.now.to_i}.csv"
    SolutionPack::Exporter.export_contents(file_path, "SurveyQuestion", survey.survey_questions, {additional_attributes: { for_completed: :for_completed? } })
    rows = CSV.read(file_path)
    assert_equal_unordered (SurveyQuestion.attribute_names + ["for_completed"]), rows[0]
    first_survey_question = survey.survey_questions.first
    assert_equal_unordered first_survey_question.attributes.values.map!{|attr| attr.to_s} + [first_survey_question.for_completed?.to_s], rows[1].map!{|attr| attr.to_s}
  end
end