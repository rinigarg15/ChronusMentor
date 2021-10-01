require_relative './../../../../test_helper.rb'

class AbstractCampaignImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_campaign_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    new_program.admin_views.destroy_all
    new_program.abstract_campaigns.destroy_all
    new_program.surveys.destroy_all

    include_importers(:settings, :forum, :mentoring_model, :resource, :group_closure_reason, :overview_pages)
    
    exported_campaign_titles = []
    campaign_file_path = File.join(IMPORT_CSV_BASE_PATH, "campaign.csv")
    csv_content = fixture_file_upload(campaign_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_campaign_titles << row["title"]
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_campaign_titles = new_program.abstract_campaigns.collect(&:title)
    assert_equal_unordered exported_campaign_titles, imported_campaign_titles
    sc = CampaignManagement::SurveyCampaign.last
    assert_equal new_program.id, sc.program_id
    s = sc.survey
    assert_equal new_program.id, s.program_id
    assert_equal "Partnership Effectiveness", s.name
    assert_equal 1, CampaignManagement::SurveyCampaign.where(ref_obj_id: s.id).count

    campaign_file_path = File.join(solution_pack.base_directory_path, "campaign-imported.csv")
    campaign_message_file_path = File.join(solution_pack.base_directory_path, "campaign_message-imported.csv")
    admin_view_file_path = File.join(solution_pack.base_directory_path, "admin_view-imported.csv")
    admin_view_column_file_path = File.join(solution_pack.base_directory_path, "admin_view_column-imported.csv")
    mailer_template_file_path = File.join(solution_pack.base_directory_path, "mailer_template_campaign_message-imported.csv")
    assert File.exists?(campaign_file_path)
    assert File.exists?(campaign_message_file_path)
    assert File.exists?(admin_view_file_path)
    assert File.exists?(admin_view_column_file_path)
    assert File.exists?(mailer_template_file_path)

    delete_base_dir_for_import
  end
end