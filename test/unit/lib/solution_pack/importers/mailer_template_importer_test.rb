require_relative './../../../../test_helper.rb'

class MailerTemplateImporterTest < ActiveSupport::TestCase

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

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :resource, :group_closure_reason, :overview_pages)
    
    new_program.admin_views.destroy_all
    new_program.abstract_campaigns.destroy_all

    exported_mailer_template_sources = []
    exported_mailer_template_subjects = []
    campaign_mailer_template_file_path = File.join(IMPORT_CSV_BASE_PATH, "mailer_template_campaign_message.csv")
    csv_content = fixture_file_upload(campaign_mailer_template_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_mailer_template_sources << row["source"]
      exported_mailer_template_subjects << row["subject"]
    end

    mailer_template_file_path = File.join(IMPORT_CSV_BASE_PATH, "mailer_template.csv")
    csv_content = fixture_file_upload(mailer_template_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    mailer_templates_uids = []

    # ezkgp8mo is org level mailer template (ForgotPassword) and which shouldn't be imported
    org_level_mailer_template_uid = ForgotPassword.mailer_attributes[:uid]
    assert_equal EmailCustomization::Level::ORGANIZATION, ChronusActionMailer::Base.get_descendants.find{|klass| klass.mailer_attributes[:uid] == org_level_mailer_template_uid}.mailer_attributes[:level]

    csv.each do |row|
      if row["source"] != "Source with {{invalid_tag}}" && row["uid"] != org_level_mailer_template_uid
        exported_mailer_template_sources << row["source"]
        exported_mailer_template_subjects << row["subject"]
        mailer_templates_uids << row["uid"]
      end
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    assert_no_difference 'org.mailer_templates.count' do
      program_importer = ProgramImporter.new(solution_pack).import
      new_program.reload
    end

    imported_mailer_template_sources = new_program.mailer_templates.collect(&:source)
    imported_mailer_template_subjects = new_program.mailer_templates.collect(&:subject)

    imported_mailer_template_sources.delete(nil)
    imported_mailer_template_subjects.delete(nil)
    assert_equal_unordered imported_mailer_template_sources, exported_mailer_template_sources
    assert_equal_unordered imported_mailer_template_subjects, exported_mailer_template_subjects

    # only program level mailer template is imported
    level = ChronusActionMailer::Base.get_descendants.find{|klass| klass.mailer_attributes[:uid] == mailer_templates_uids.first}.mailer_attributes[:level]
    assert_equal DigestV2.mailer_attributes[:uid], mailer_templates_uids.first
    assert_equal EmailCustomization::Level::PROGRAM, level
    assert_equal mailer_templates_uids.first, new_program.mailer_templates.last(2).first.uid
    #This mailer template is disabled by default. But the imported mailer template from solution pack is enabled.
    assert new_program.mailer_templates.find_by(uid: "s9kiyrsk").enabled

    campaign_file_path = File.join(solution_pack.base_directory_path, "campaign-imported.csv")
    campaign_message_file_path = File.join(solution_pack.base_directory_path, "campaign_message-imported.csv")
    admin_view_file_path = File.join(solution_pack.base_directory_path, "admin_view-imported.csv")
    admin_view_column_file_path = File.join(solution_pack.base_directory_path, "admin_view_column-imported.csv")
    mailer_template_file_path = File.join(solution_pack.base_directory_path, "mailer_template_campaign_message-imported.csv")
    assert File.exists?(campaign_file_path)
    assert File.exists?(campaign_message_file_path)
    assert File.exists?(mailer_template_file_path)

    error_messages = ["Error in importing with UID qkak4psq. Full Error Message Subject contains invalid tags - {{invalid_tag}}, Body contains invalid tags - {{invalid_tag}}"]
    assert_equal error_messages, solution_pack.custom_errors_messages

    delete_base_dir_for_import
  end

  def test_get_program_id
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    mailer_template = Mailer::Template.new

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    mailer_template_importer = MailerTemplateImporter.new(program_importer)

    #org level template: AdminAddedNotification
    mailer_template.uid = AdminAddedNotification.mailer_attributes[:uid] 
    program_id = mailer_template_importer.send(:get_program_id, mailer_template)
    assert_nil program_id

    #program level template: AdminAddedDirectlyNotification
    mailer_template.uid = AdminAddedDirectlyNotification.mailer_attributes[:uid] 
    program_id = mailer_template_importer.send(:get_program_id, mailer_template)
    assert_equal program.id, program_id

    #program level template: ProgramInvitationCampaignEmailNotification
    mailer_template.uid = ProgramInvitationCampaignEmailNotification.mailer_attributes[:uid] 
    program_id = mailer_template_importer.send(:get_program_id, mailer_template)
    assert_equal program.id, program_id

    #program level template: UserCampaignEmailNotification and level is nil
    mailer_template.uid = UserCampaignEmailNotification.mailer_attributes[:uid] 
    program_id = mailer_template_importer.send(:get_program_id, mailer_template)
    assert_equal program.id, program_id

    #program level template: SurveyCampaignEmailNotification
    mailer_template.uid = SurveyCampaignEmailNotification.mailer_attributes[:uid] 
    program_id = mailer_template_importer.send(:get_program_id, mailer_template)
    assert_equal program.id, program_id

    delete_base_dir_for_import
  end

  def test_process_campaign_message_id
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    mailer_template = Mailer::Template.new

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    mailer_template_importer = MailerTemplateImporter.new(program_importer)
    mailer_template_importer.process_campaign_message_id(10, mailer_template)
    assert_nil mailer_template.campaign_message_id

    campaign_importer = AbstractCampaignImporter.new(program_importer)
    mailer_template_importer = MailerTemplateImporter.new(campaign_importer)
    mailer_template_importer.process_campaign_message_id(10, mailer_template)
    assert_equal 10, mailer_template.campaign_message_id
    delete_base_dir_for_import
  end

  def test_initialize
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    mailer_template = Mailer::Template.new

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    mailer_template_importer = MailerTemplateImporter.new(program_importer)
    assert_equal "mailer_template", mailer_template_importer.file_name

    campaign_importer = AbstractCampaignImporter.new(program_importer)
    mailer_template_importer = MailerTemplateImporter.new(campaign_importer)
    assert_equal "mailer_template_campaign_message", mailer_template_importer.file_name
    
    delete_base_dir_for_import
  end

  def test_email_tags_for_campaign_messages_valid

  end
end