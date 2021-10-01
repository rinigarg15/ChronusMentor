require_relative './../../../../test_helper'

class SummaryExporterTest < ActiveSupport::TestCase

  def test_summary_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    cqe = ConnectionQuestionExporter.new(program, program_exporter)
    csqe = SummaryExporter.new(program, cqe)
    csqe.export

    summaries = program.summaries

    exported_summary_ids = []

    assert_equal csqe.file_name, 'summary_connection_question'
    assert_equal csqe.parent_exporter, cqe
    assert_equal csqe.program, program

    summarysFilePath = solution_pack.base_path + 'summary_connection_question.csv'
    assert File.exist?(summarysFilePath)
    CSV.foreach(summarysFilePath, headers: true) do |row|
      exported_summary_ids << row["id"].to_i
    end

    assert_equal_unordered exported_summary_ids, summaries.collect(&:id)

    File.delete(summarysFilePath)
  end

  def test_ensure_summary_model_unchanged
    expected_attribute_names = ["id", "connection_question_id", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, Summary.attribute_names

    summary_column_hash = Summary.columns_hash
    assert_equal summary_column_hash["connection_question_id"].type, :integer
    assert_equal summary_column_hash["created_at"].type, :datetime
    assert_equal summary_column_hash["updated_at"].type, :datetime
  end
end