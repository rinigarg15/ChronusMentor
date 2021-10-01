require_relative './../../../../test_helper.rb'

class SectionImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_section_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    section_texts = []
    section_file_path = File.join(IMPORT_CSV_BASE_PATH, "section.csv")
    csv_content = fixture_file_upload(section_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      section_texts << row["title"]
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_section_titles = new_program.organization.sections.collect(&:title)
    
    section_file_path = File.join(solution_pack.base_directory_path, "section-imported.csv")
    assert File.exists?(section_file_path)

    section_texts.each do |section_text|
      assert imported_section_titles.include?(section_text)
    end

    #test process_program_id
    section = new_program.organization.sections.find_by(title: "Unique Section 3")
    assert_equal new_program.organization.id, section.program_id

    delete_base_dir_for_import
  end

  def test_process_position
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    section_importer = SectionImporter.new(program_importer)

    last_position = program.organization.sections.collect(&:position).max

    new_section = Section.new
    section_importer.process_position(100, new_section)
    assert_equal (last_position+1), new_section.position

    delete_base_dir_for_import
  end

  def test_handle_object_creation
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    section_importer = SectionImporter.new(program_importer)

    last_position = program.organization.sections.collect(&:position).max

    new_section = program.organization.sections.new(title: "Unique Section 5 random")
    assert_difference "Section.count", 1 do
      section_importer.handle_object_creation(new_section, 100, [], "")
    end

    new_section = program.organization.sections.new(title: program.organization.sections.first.title)
    assert_no_difference "Section.count" do
      section_importer.handle_object_creation(new_section, 100, [], "")
    end

    delete_base_dir_for_import
  end

   def test_handle_object_creation_with_changed_default_field
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    section_importer = SectionImporter.new(program_importer)

    new_section = program.organization.sections.new(title: "Default Information", default_field: true)
    assert_difference "Section.count", 0 do
      section_importer.handle_object_creation(new_section, 100, [], "")
    end

    new_section = program.organization.sections.new(title: "Basic Information", default_field: true)
    assert_difference "Section.count", 0 do
      section_importer.handle_object_creation(new_section, 100, [], "")
    end

    delete_base_dir_for_import
   end
end