require_relative './../../../../test_helper.rb'

class OverviewPagesImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_overview_pages_import_for_program_or_org
    organization = programs(:org_primary)
    overview_pages_import(organization)
    organization = Organization.new(name: "Some Organization")
    organization.save!
    pdomain = organization.program_domains.new()
    pdomain.subdomain = "subdomain"
    pdomain.domain = DEFAULT_DOMAIN_NAME
    pdomain.save!
    overview_pages_import(organization)
  end

  private


  def overview_pages_import(organization)
    org = organization
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :profile_question, :resource, :mailer_template, :group_closure_reason)

    exported_page_titles = []
    exported_page_contents = []
    exported_page_positions = []
    exported_page_visibility = []
    exported_page_use_in_sub_programs = []
    exported_page_published_status = []

    overview_page_file_path = File.join(IMPORT_CSV_BASE_PATH, "overview_pages.csv")
    csv_content = fixture_file_upload(overview_page_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_page_titles << row["title"]
      exported_page_contents << row["content"]
      exported_page_positions << row["position"].to_i
      exported_page_visibility << row["visibility"].to_i
      exported_page_use_in_sub_programs << str_to_bool(row["use_in_sub_programs"])
      exported_page_published_status << str_to_bool(row["published"])
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.imported_ck_assets = {}
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)

    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload
    org_or_program = new_program.standalone?? new_program.organization : new_program

    assert_equal_unordered exported_page_titles, (org_or_program.pages.collect(&:title) & exported_page_titles)
    assert_equal_unordered exported_page_contents, (org_or_program.pages.collect(&:content) & exported_page_contents)
    assert_equal_unordered exported_page_positions, (org_or_program.pages.collect(&:position) & exported_page_positions)
    assert_equal_unordered exported_page_visibility, (org_or_program.pages.collect(&:visibility) & exported_page_visibility)
    assert_equal_unordered exported_page_use_in_sub_programs, (org_or_program.pages.collect(&:use_in_sub_programs) & exported_page_use_in_sub_programs)
    assert_equal_unordered exported_page_published_status, (org_or_program.pages.collect(&:published) & exported_page_published_status)

    overview_pages_file_path = File.join(solution_pack.base_directory_path, "overview_pages-imported.csv")
    assert File.exists?(overview_pages_file_path)

    delete_base_dir_for_import
  end

  def str_to_bool(str)
    str == 'true'
  end
end
  