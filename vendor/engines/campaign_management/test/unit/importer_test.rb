require_relative './../test_helper'

class CampaignManagement::ImporterTest < ActiveSupport::TestCase
  IMPORT_CSV_FILE_NAME = "campaign_management/campaign_model_import.csv"
  IMPORT_INCORRECT_ADMINVIEW_CSV_FILE_NAME = "campaign_management/campaign_model_campaign_error_import.csv"
  IMPORT_CAMPAIGN_EMPTY_STATE_FILE_NAME ="campaign_management/campaign_model_campaign_empty_state.csv"
  IMPORT_INCORRECT_CAMPAIGN_ACTIVE_STATE_CSV_FILE_NAME = "campaign_management/campaign_model_campaign_creation_failure_import.csv"
  IMPORT_INCORRECT_CAMPAIGN_MESSAGE_CSV_FILE_NAME = "campaign_management/campaign_model_campaign_message_with_no_corresponding_campaign_error_import.csv"
  IMPORT_INCORRECT_CAMPAIGN_MESSAGE_WITH_EMPTY_SOURCE_SUBJECT__CSV_FILE_NAME = "campaign_management/campaign_model_campaign_messages_with_empty_source_or_duration_should_not_be_created.csv"
  IMPORT_INCORRECT_CAMPAIGN_MESSAGE_WITH_NO_CAMPAIGN_REFERENCE = "campaign_management/campaign_model_campaign_message_with_no_campaign_reference.csv"

  def setup
    super
    @program = programs(:albers)
    @campaigns = CampaignManagement::AbstractCampaign.where(:program_id => @program.id).where("type != ?", CampaignManagement::AbstractCampaign::TYPE::SURVEY)
  end

  def test_initialize
    csv_content = fixture_file_upload(File.join('files', IMPORT_CSV_FILE_NAME), 'text/csv')
    importer = CampaignManagement::Importer.new(csv_content, 13)
    assert_equal csv_content, importer.instance_variable_get("@csv_content")
    assert_false importer.instance_variable_get("@successful")
    assert_equal_hash importer.instance_variable_get("@campaign_referenced_by_title"), {}
    assert_equal importer.instance_variable_get("@error_importing_campaigns"), []
    assert_equal importer.instance_variable_get("@campaign_states"), {}
    assert_equal importer.instance_variable_get("@program_id"), 13
  end

  def test_successfull_import
    stream = fixture_file_upload(File.join('files', IMPORT_CSV_FILE_NAME), 'text/csv')
    Program.any_instance.expects(:active_admins_except_mentor_admins).twice
    Timecop.freeze(Time.now) do
      CampaignManagement::Importer.new(stream, @program.id).import
      campaigns = @campaigns.reload
      assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name","Campaign 1", "Campaign 2", "Campaign 3"], campaigns.collect(&:title)
      campaign_ids = campaigns.pluck(:id)
      campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
      assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0, 1, 2], campaign_messages.collect(&:duration)
      c1 = campaigns.find{|c| c.title == "Campaign 1"}
      assert_equal Time.now.utc.to_s(:db), c1.enabled_at.utc.to_s(:db)
      assert c1.stopped?
      assert_equal 1, c1.campaign_messages.count

      c2 = campaigns.find{|c| c.title == "Campaign 2"}
      assert_equal Time.now.utc.to_s(:db), c2.enabled_at.utc.to_s(:db)
      assert c2.active?
      assert_equal 1, c2.campaign_messages.count

      c3 = campaigns.find{|c| c.title == "Campaign 3"}
      assert_nil c3.enabled_at
      assert c3.drafted?
      assert_equal 0, c3.campaign_messages.count

      campaign_message_ids = campaign_messages.pluck(:id)
      assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 1", "Subject 2"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
    end
  end

  def test_incorrect_admin_view_error_import
    stream = fixture_file_upload(File.join('files', IMPORT_INCORRECT_ADMINVIEW_CSV_FILE_NAME), 'text/csv')
    CampaignManagement::Importer.new(stream, @program.id).import
    campaigns = @campaigns.reload
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name", "Campaign 2"], campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0, 2], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 2"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
  end

  def test_campaign_empty_state_should_take_default_inactive_state
    stream = fixture_file_upload(File.join('files', IMPORT_CAMPAIGN_EMPTY_STATE_FILE_NAME), 'text/csv')
    Program.any_instance.expects(:active_admins_except_mentor_admins).twice
    CampaignManagement::Importer.new(stream, @program.id).import
    campaigns = @campaigns.reload
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name","Campaign 1", "Campaign 2"], campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0, 1, 2], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 1", "Subject 2"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
  end

  def test_campaign_with_no_messages_NOT_in_active_state_error_import
    stream = fixture_file_upload(File.join('files', IMPORT_INCORRECT_CAMPAIGN_ACTIVE_STATE_CSV_FILE_NAME), 'text/csv')
    CampaignManagement::Importer.new(stream, @program.id).import
    campaigns = @campaigns.reload
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name", "Campaign 1", "Campaign 2"],campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0, 1, 2], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 1", "Subject 2"],  Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
  end

  def test_campaign_messages_with_no_corresponding_campaign_error_import
    stream = fixture_file_upload(File.join('files', IMPORT_INCORRECT_CAMPAIGN_MESSAGE_CSV_FILE_NAME), 'text/csv')
    CampaignManagement::Importer.new(stream, @program.id).import
    campaigns = @campaigns.reload
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name", "Campaign 1", "Campaign 2"], campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0, 1], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 1"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
  end

  def test_campaign_messages_with_empty_source_or_duration_should_not_be_created
    stream = fixture_file_upload(File.join('files', IMPORT_INCORRECT_CAMPAIGN_MESSAGE_WITH_EMPTY_SOURCE_SUBJECT__CSV_FILE_NAME), 'text/csv')
    CampaignManagement::Importer.new(stream, @program.id).import
    campaigns = @campaigns.reload
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name", "Campaign 1", "Campaign 2"], campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
  end

  def test_campaign_messages_with_no_campaign_reference_are_not_created
    stream = fixture_file_upload(File.join('files', IMPORT_INCORRECT_CAMPAIGN_MESSAGE_WITH_NO_CAMPAIGN_REFERENCE), 'text/csv')
    CampaignManagement::Importer.new(stream, @program.id).import
    campaigns = @campaigns.reload
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Program Invitations to sign up", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name", "Campaign 1", "Campaign 2"], campaigns.collect(&:title)
    campaign_ids = campaigns.pluck(:id)
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where(:campaign_id => campaign_ids)
    assert_equal [7, 30, 0, 15, 29, 0, 5, 10, 15, 4, 6, 0, 0, 1], campaign_messages.collect(&:duration)
    campaign_message_ids = campaign_messages.pluck(:id)
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Invitation to join {{subprogram_or_program_name}} {{as_role_name_articleized}}", "You have a pending invitation to join {{subprogram_or_program_name}}", "Your invitation expires tomorrow!","Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6", "Subject 1"], Mailer::Template.where(:campaign_message_id => campaign_message_ids).collect(&:subject)
  end

  def test_csv_parse_fail_should_raise_exception
    CSV.expects(:parse).raises
    stream = fixture_file_upload(File.join('files', IMPORT_CSV_FILE_NAME), 'text/csv')
    importer = CampaignManagement::Importer.new(stream, @program.id)
    assert_nil importer.program_id
  end
end
