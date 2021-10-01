require_relative './../../../../test_helper.rb'

class SectionExporterTest < ActiveSupport::TestCase

  def test_section_export
    section = Section.create!(:organization => programs(:org_primary), :title => "Section name", :position => 100)
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    ProfileQuestionExporter.any_instance.expects(:export).once
    section_ids = []

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    section_exporter = SectionExporter.new(program, program_exporter)
    section_exporter.export

    sections = program.role_questions.includes([:profile_question => [:section]]).collect(&:profile_question).collect(&:section).uniq.flatten
    assert_equal_unordered section_exporter.objs, sections
    assert_equal section_exporter.file_name, 'section'
    assert_equal section_exporter.program, program
    assert_equal section_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'section.csv')
    CSV.foreach(solution_pack.base_path+'section.csv', headers: true) do |row|
      section_ids << row["id"].to_i
    end

    assert_equal_unordered section_ids, sections.collect(&:id)
    assert_false section_ids.include?(section.id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_section_model_unchanged
    expected_attribute_names = ["id", "program_id", "position", "default_field", "created_at", "updated_at", "title", "description"]
    assert_equal_unordered expected_attribute_names, Section.attribute_names
  end
end