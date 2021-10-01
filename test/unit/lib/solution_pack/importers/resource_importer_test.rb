require_relative './../../../../test_helper.rb'

class ResourceImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_resource_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    Organization.any_instance.stubs(:standalone?).returns(true)
    resources = new_program.resource_publications.collect(&:resource)
    Resource.where(id: resources.map(&:id)).destroy_all
    Resource.any_instance.stubs(:default).returns(true)
    existing_default_resource_id = new_program.organization.resources.create!(default: true, title: "English resource", content: "Old description").id
    new_program.reload

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)

    exported_resource_titles = []
    resource_file_path = File.join(IMPORT_CSV_BASE_PATH, "resource.csv")
    csv_content = fixture_file_upload(resource_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_resource_titles << row["title"]
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_resource_titles = new_program.resource_publications.collect(&:resource).collect(&:title)
    assert_equal_unordered imported_resource_titles, exported_resource_titles

    resource_file_path = File.join(solution_pack.base_directory_path, "resource-imported.csv")
    resource_publication_file_path = File.join(solution_pack.base_directory_path, "resource_publication-imported.csv")
    role_resource_file_path = File.join(solution_pack.base_directory_path, "role_resource-imported.csv")
    assert File.exists?(resource_file_path)
    assert File.exists?(resource_publication_file_path)
    assert File.exists?(role_resource_file_path)
    assert_not_empty solution_pack.invalid_ck_assets_in["Resource"]
    resources = new_program.resource_publications.collect(&:resource).select{ |resource| resource.title == "English resource" }
    assert_equal 1, resources.count
    resource = resources.first
    assert_equal "Description in English -- adding some more description in english#", resource.content
    assert_nil Resource.find_by(id: existing_default_resource_id)
    assert_equal 0, resource.view_count

    delete_base_dir_for_import
  end

  def test_resource_import_sales_demo
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    resources = new_program.resource_publications.collect(&:resource)
    Resource.where(id: resources.map(&:id)).destroy_all
    new_program.reload
    SettingsImporter.any_instance.expects(:import).twice
    ForumImporter.any_instance.expects(:import).twice
    SurveyImporter.any_instance.expects(:import).twice
    MentoringModelImporter.any_instance.expects(:import).twice
    AbstractCampaignImporter.any_instance.expects(:import).twice
    AdminViewImporter.any_instance.expects(:import).twice
    MailerTemplateImporter.any_instance.expects(:import).twice
    GroupClosureReasonImporter.any_instance.expects(:import).twice
    OverviewPagesImporter.any_instance.expects(:import).twice

    exported_resource_titles = []
    resource_file_path = File.join(IMPORT_CSV_BASE_PATH, "resource.csv")
    csv_content = fixture_file_upload(resource_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_resource_titles << row["title"]
    end
    resource_mapping = {}
    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack", :sales_demo_mapper => {:organization => {org.id => org.id}, :resource => resource_mapping, :user => {}})
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    assert_difference "org.resources.count", 2 do
      program_importer = ProgramImporter.new(solution_pack).import
    end
    new_program.reload
    assert_equal 2, new_program.resources.count
    assert_equal 4, new_program.resource_publications.collect(&:resource).count
    imported_resource_titles = new_program.resource_publications.collect(&:resource).collect(&:title)
    assert_equal_unordered imported_resource_titles, exported_resource_titles

    resource_file_path = File.join(solution_pack.base_directory_path, "resource-imported.csv")
    resource_publication_file_path = File.join(solution_pack.base_directory_path, "resource_publication-imported.csv")
    role_resource_file_path = File.join(solution_pack.base_directory_path, "role_resource-imported.csv")
    assert File.exists?(resource_file_path)
    assert File.exists?(resource_publication_file_path)
    assert File.exists?(role_resource_file_path)

    delete_base_dir_for_import
    copy_base_dir_for_import

    resource_file_path = File.join(IMPORT_CSV_BASE_PATH, "resource.csv")
    csv_content = fixture_file_upload(resource_file_path, "text/csv")
    new_program2 = org.programs.new
    new_program2.name = "Test Program1"
    new_program2.root = "test-program1"
    new_program2.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program2.save!
    resources = new_program2.resource_publications.collect(&:resource)
    Resource.where(id: resources.map(&:id)).destroy_all
    new_program2.reload

    new_resource_mapping = { }
    resource_mapping.each do |key, value|
      new_resource_mapping[key] = value if org.resources.pluck(:id).include?(value)
    end
    solution_pack = SolutionPack.new(:program => new_program2, :created_by => "test admin", :description => "test solution pack", :sales_demo_mapper => {:organization => {org.id => org.id}, :resource => new_resource_mapping, :user => {}})
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    assert_no_difference "org.resources.count" do
      program_importer = ProgramImporter.new(solution_pack).import
    end
    new_program2.reload
    assert_equal 2, new_program2.resources.count
    assert_equal 4, new_program2.resource_publications.collect(&:resource).count

    delete_base_dir_for_import
  end
end