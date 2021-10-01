require_relative './../../test_helper'

class ImportExportUtilsTest < ActiveSupport::TestCase
  include ImportExportUtils

  attr_accessor :campaign_template_rows, :campaign_message_template_rows

  ITEM_TO_DATA_MODULE_MAPPER = {
    campaign_template: CampaignManagement::ImportExportUtils::CampaignTemplate,
    campaign_message_template: CampaignManagement::ImportExportUtils::CampaignMessageTemplate
  }

  def test_extract_data_rows_from_csv_data

    data = [["#Campaign"], ["Name", "AdminView", "Enable", "Type"], ["Campaign1 Name", "All Users", "yes"], ["Campaign2 Name", "", "yes", "ProgramInvitation"], [],["#Emails"], ["From", "Subject", "Message", "Schedule", "Campaign"], ["Freakin Admin (Admin)", "Campaign Message - Subject1", "Campaign Message - Content 1", "0", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject2", "Campaign Message - Content 2", "5", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject3", "Campaign Message - Content 3", "10", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject4", "Campaign Message - Content 4", "15", "Campaign1 Name"]]
    campaigns = [["Campaign1 Name", "All Users", "yes"], ["Campaign2 Name", "", "yes", "ProgramInvitation"]]
    emails = [["Freakin Admin (Admin)", "Campaign Message - Subject1", "Campaign Message - Content 1", "0", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject2", "Campaign Message - Content 2", "5", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject3", "Campaign Message - Content 3", "10", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject4", "Campaign Message - Content 4", "15", "Campaign1 Name"]]

    items_header = [:campaign_template, :campaign_message_template]
    ImportExportUtils.extract_data_rows_from_csv_data(self, data, ITEM_TO_DATA_MODULE_MAPPER, items_header)

    assert_equal campaigns, self.campaign_template_rows
    assert_equal emails, self.campaign_message_template_rows
  end

  def test_extract_item_rows

    data = [["#Campaign"], ["Name", "AdminView", "Enable"], ["Campaign1 Name", "All Users", "yes"], [],["#Emails"], ["From", "Subject", "Message", "Schedule", "Campaign"], ["Freakin Admin (Admin)", "Campaign Message - Subject1", "Campaign Message - Content 1", "0", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject2", "Campaign Message - Content 2", "5", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject3", "Campaign Message - Content 3", "10", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject4", "Campaign Message - Content 4", "15", "Campaign1 Name"]]
    campaigns = [["Campaign1 Name", "All Users", "yes"]]
    emails = [["Freakin Admin (Admin)", "Campaign Message - Subject1", "Campaign Message - Content 1", "0", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject2", "Campaign Message - Content 2", "5", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject3", "Campaign Message - Content 3", "10", "Campaign1 Name"], ["Freakin Admin (Admin)", "Campaign Message - Subject4", "Campaign Message - Content 4", "15", "Campaign1 Name"]]

    assert_equal campaigns, ImportExportUtils.extract_item_rows(data, "#Campaign")
    assert_equal emails, ImportExportUtils.extract_item_rows(data, "#Emails")
  end


  def test_file_url
    assert_equal "https://chronus.com", ImportExportUtils.file_url("https://chronus.com")

    assert_equal "#{Rails.root}/app/assets/images/v3/image.png", ImportExportUtils.file_url("/assets/v3/image.png")

    assert_equal "#{Rails.root}/public/system/logo/1/original.png", ImportExportUtils.file_url("/system/logo/1/original.png?1235")
  end

  def test_get_temp_file_for_remote_url
    temp_file = Tempfile.new("open-uri")
    OpenURI.stubs(:open_uri).returns(temp_file)
    response = ImportExportUtils.get_temp_file("https://dummy_chronus_url")
    assert_equal response, temp_file
  end

  def test_get_temp_file_for_remote_url_with_size_less_than_10KB
    #Files less than 10KB returns a stringIO object
    OpenURI.stubs(:open_uri).returns(StringIO.new('{"name":"Foo"}'))
    response = ImportExportUtils.get_temp_file("https://dummy_chronus_url")
    assert_equal response.class, Tempfile
  end

  def test_get_temp_file_for_local_file
    local_file = File.join(self.class.fixture_path, 'files', 'test_pic.png')
    response = ImportExportUtils.get_temp_file(local_file)
    assert_equal response.class, File
  end
end