require_relative './../../../../test_helper.rb'

class CampaignMessageImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_campaign_message_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.creation_way = Program::CreationWay::SOLUTION_PACK
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    new_program.admin_views.destroy_all
    new_program.abstract_campaigns.destroy_all

    include_importers(:settings, :forum, :mentoring_model, :resource, :group_closure_reason, :overview_pages)

    exported_campaign_message_count = 0
    campaign_message_file_path = File.join(IMPORT_CSV_BASE_PATH, "campaign_message.csv")
    csv_content = fixture_file_upload(campaign_message_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_campaign_message_count += 1
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload
 
    imported_campaign_message_count = new_program.abstract_campaigns.map{|c| c.campaign_messages}.flatten.count
    assert_equal exported_campaign_message_count, imported_campaign_message_count 
    
    assert_equal [true], new_program.program_invitation_campaign.campaign_messages.pluck(:user_jobs_created)
    assert_equal [false], new_program.user_campaigns.first.campaign_messages.pluck(:user_jobs_created)


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