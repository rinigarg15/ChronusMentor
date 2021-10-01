require_relative './../../../../test_helper'

class OverviewExporterTest < ActiveSupport::TestCase

  def test_overview_pages_export
    program = programs(:albers)
    program.pages.create(title: "Testing", content: "Testing Page export")
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    overview_pages_exporter = OverviewPagesExporter.new(program, program_exporter)
    overview_pages_exporter.export

    pages = program.pages
    exported_page_ids = []
    exported_page_titles = []
    exported_page_contents = []

    assert_equal overview_pages_exporter.parent_exporter, program_exporter
    assert_equal overview_pages_exporter.program, program
    assert_equal overview_pages_exporter.file_name, "overview_pages"

    overview_pages_file_path = solution_pack.base_path+"overview_pages.csv"
    assert File.exist?(overview_pages_file_path)
    CSV.foreach(overview_pages_file_path, headers: true) do |row|
      exported_page_ids << row["id"].to_i
      exported_page_titles << row["title"]
      exported_page_contents << row["content"]
    end

    assert_equal_unordered exported_page_ids, pages.collect(&:id)
    assert_equal_unordered exported_page_titles, pages.collect(&:title)
    assert_equal_unordered exported_page_contents, pages.collect(&:content)

    File.delete(overview_pages_file_path)
  end

  def test_overview_pages_export_for_standalone
    program = programs(:foster)

    assert_empty program.pages
    assert !program.organization.pages.empty?

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    overview_pages_exporter = OverviewPagesExporter.new(program, program_exporter)
    overview_pages_exporter.export

    pages = program.organization.pages
    exported_page_ids = []
    exported_page_titles = []
    exported_page_contents = []

    assert_equal overview_pages_exporter.parent_exporter, program_exporter
    assert_equal overview_pages_exporter.program, program
    assert_equal overview_pages_exporter.file_name, "overview_pages"

    overview_pages_file_path = solution_pack.base_path+"overview_pages.csv"
    assert File.exist?(overview_pages_file_path)
    CSV.foreach(overview_pages_file_path, headers: true) do |row|
      exported_page_ids << row["id"].to_i
      exported_page_titles << row["title"]
      exported_page_contents << row["content"]
    end

    assert_equal_unordered exported_page_ids, pages.collect(&:id)
    assert_equal_unordered exported_page_titles, pages.collect(&:title)
    assert_equal_unordered exported_page_contents, pages.collect(&:content)

    File.delete(overview_pages_file_path)
  end

  def test_page_model_unchanged
    expected_attribute_names = ["id", "program_id", "title", "content", "created_at", "updated_at", "position", "visibility", "use_in_sub_programs", "published"]
    assert_equal_unordered expected_attribute_names, Page.attribute_names

    page_column_hash = Page.columns_hash
    page_translation_column_hash = Page::Translation.columns_hash
    assert_equal page_column_hash["program_id"].type, :integer
    assert_equal :string, page_translation_column_hash["title"].type
    assert_equal :text, page_translation_column_hash["content"].type
    assert_equal page_column_hash["position"].type, :integer
    assert_equal page_column_hash["visibility"].type, :integer
    assert_equal page_column_hash["use_in_sub_programs"].type, :boolean
    assert_equal page_column_hash["published"].type, :boolean
  end
end