require_relative './../../test_helper'

class LinkedinImporterTest < ActiveSupport::TestCase

  def setup
    @linkedin_importer = LinkedinImporter.new("access-token")
    super
  end

  def test_import_data_empty_data
    @linkedin_importer.expects(:get_data).once.returns({})
    @linkedin_importer.expects(:format_educations).never
    @linkedin_importer.expects(:format_experiences).never
    @linkedin_importer.expects(:format_publications).never
    @linkedin_importer.import_data
    assert_equal({}, @linkedin_importer.raw_data)
    assert_equal({}, @linkedin_importer.formatted_data)
  end

  def test_import_data
    response = JSON.parse(File.read(File.join(Rails.root, "test/fixtures/files/linkedin_response_basic_profile.json")))
    @linkedin_importer.expects(:get_data).once.returns(response)
    @linkedin_importer.import_data
    assert_equal response, @linkedin_importer.raw_data
    assert_equal 2, @linkedin_importer.formatted_data.size
    assert_equal "12345", @linkedin_importer.formatted_data[:id]
    assert_equal @linkedin_importer.raw_data["positions"]["_total"], @linkedin_importer.formatted_data[:experiences].size

    # experiences
    assert_equal [
      { job_title: "SSDE II", company: "Chronus LLC", start_year: 2017, start_month: 7, end_year: nil, end_month: nil, current_job: true },
      { job_title: "SSDE", company: "Chronus LLC", start_year: 2016, start_month: 7, end_year: 2017, end_month: 6, current_job: false },
      { job_title: "SDE II", company: "Chronus Corporation", start_year: 2014, start_month: 7, end_year: 2016, end_month: 6, current_job: false }
    ], @linkedin_importer.formatted_data[:experiences]

    assert_nil @linkedin_importer.formatted_data[:educations]
    assert_nil @linkedin_importer.formatted_data[:publications]
  end

  def test_is_access_token_valid
    linkedin_importer = LinkedinImporter.new("")
    linkedin_importer.expects(:send_request).never
    linkedin_importer.expects(:is_response_valid?).never
    assert_false linkedin_importer.is_access_token_valid?

    @linkedin_importer.expects(:send_request).with(LinkedinImporter::VERIFY_ACCESS_TOKEN_URI).twice
    @linkedin_importer.expects(:is_response_valid?).once.returns(false)
    assert_false @linkedin_importer.is_access_token_valid?

    @linkedin_importer.expects(:is_response_valid?).once.returns(true)
    assert @linkedin_importer.is_access_token_valid?
  end

  def test_get_data
    response = "response"
    @linkedin_importer.expects(:send_request).with(LinkedinImporter::IMPORT_URI).twice.returns(response)
    @linkedin_importer.expects(:is_response_valid?).once.returns(false)
    JSON.expects(:parse).never
    assert_false @linkedin_importer.send(:get_data)

    @linkedin_importer.expects(:is_response_valid?).once.returns(true)
    response.expects(:body).once
    JSON.expects(:parse).once.returns("parsed-data")
    assert_equal "parsed-data", @linkedin_importer.send(:get_data)
  end
end